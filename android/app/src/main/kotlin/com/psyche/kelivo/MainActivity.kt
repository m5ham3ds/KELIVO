package com.psyche.kelivo

import android.app.Activity
import android.app.ActivityManager
import android.content.ActivityNotFoundException
import android.net.Uri
import android.content.Intent
import android.os.Bundle
import android.os.BatteryManager
import android.os.Build
import android.os.Debug
import android.os.PowerManager
import android.os.Process
import android.os.SystemClock
import android.os.ParcelFileDescriptor
import android.os.StatFs
import android.provider.DocumentsContract
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterSurfaceView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import com.psyche.kelivo.workspace.WorkspacePlugin
import io.flutter.plugin.common.MethodChannel
import com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin
import java.io.File
import java.io.FileInputStream
import java.io.OutputStream
import java.util.concurrent.Executors
import java.util.Locale
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val kelivo get() = application as KelivoApplication
    private var reusedEngine = false
    private val highRefreshRate by lazy { HighRefreshRateController(window) }
    private var selectionMenu: AndroidSelectionMenu? = null

    override fun provideFlutterEngine(context: android.content.Context): FlutterEngine {
        reusedEngine = kelivo.hasEngine
        return kelivo.engine
    }
    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onStart() {
        super.onStart()
        kelivo.backgroundRuntime.setForeground(true)
    }

    override fun onPostResume() {
        super.onPostResume()
        // A headless engine may have sent SystemChrome settings before its
        // Activity/PlatformPlugin existed. Apply the window policy on attach.
        applyEdgeToEdgeSystemBars(window)
        highRefreshRate.resume()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) highRefreshRate.request(force = true)
    }

    override fun onStop() {
        selectionMenu?.dismiss()
        highRefreshRate.stop()
        kelivo.backgroundRuntime.setForeground(false)
        super.onStop()
    }

    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        if (selectionMenu?.handleBack() == true) return
        super.onBackPressed()
    }

    private companion object {
        const val CREATE_DOCUMENT_REQUEST_CODE = 4107
        const val SELECT_KELIVO_FOLDER_REQUEST_CODE = 4124
    }

    private enum class WritableFileState {
        IDLE,
        OPEN,
        COMMITTED,
        DISCARDED,
    }

    private val processTextChannelName = "app.process_text"
    private val fileSaveChannelName = "app.file_save"
    private val deviceStorageChannelName = "app.device_storage"
    private val deviceResourcesChannelName = "app.device_resources"
    private val publicStorageChannelName = "app.kelivo/public_storage"
    private var processTextChannel: MethodChannel? = null
    private var fileSaveChannel: MethodChannel? = null
    private var deviceStorageChannel: MethodChannel? = null
    private var deviceResourcesChannel: MethodChannel? = null
    private var publicStorageChannel: MethodChannel? = null
    @Volatile private var lastProcessCpuTimeMs: Long? = null
    @Volatile private var lastProcessCpuWallTimeMs: Long? = null
    private var pendingProcessText: String? = null
     private var pendingSaveResult: MethodChannel.Result? = null
     private var pendingPublicFolderResult: MethodChannel.Result? = null
     private var pendingSaveSourcePath: String? = null
     private var pendingDirectWrite = false
     private var pendingWritableStream: OutputStream? = null
     private var pendingWritableUri: Uri? = null
     @Volatile private var writableFileState = WritableFileState.IDLE
     private val writableFileExecutor = Executors.newSingleThreadExecutor()
     private val publicStorageExecutor = Executors.newSingleThreadExecutor()
     private var deviceLocalToolsHandler: DeviceLocalToolsHandler? = null
     private var workspacePlugin: WorkspacePlugin? = null
    private var incomingShareHandler: IncomingShareHandler? = null
    private var receivedShare = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        forwardCachedProcessTextLaunch(reusedEngine, savedInstanceState, intent, processTextChannel)
        (kelivo.engine.plugins.get(FlutterLocalNotificationsPlugin::class.java) as? FlutterLocalNotificationsPlugin)?.let {
            forwardCachedNotificationLaunch(reusedEngine, savedInstanceState, intent, it)
        }
        kelivo.backgroundRuntime.receiveConversation(intent)
        receivedShare = savedInstanceState?.getBoolean("kelivo.receivedShare") == true
        if (!receivedShare) receivedShare = incomingShareHandler?.receive(intent) == true
    }

    override fun onSaveInstanceState(outState: Bundle) {
        outState.putBoolean("kelivo.receivedShare", receivedShare)
        super.onSaveInstanceState(outState)
    }

    override fun onFlutterSurfaceViewCreated(flutterSurfaceView: FlutterSurfaceView) {
        super.onFlutterSurfaceViewCreated(flutterSurfaceView)
        highRefreshRate.attach(flutterSurfaceView)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
         super.configureFlutterEngine(flutterEngine)
        kelivo.messageInput.attachActivity(this)
        selectionMenu = AndroidSelectionMenu(flutterEngine.dartExecutor.binaryMessenger) {
            findViewById<FlutterView>(FlutterActivity.FLUTTER_VIEW_ID)
        }
        incomingShareHandler = IncomingShareHandler(this, flutterEngine.dartExecutor.binaryMessenger)
         OAuthHandler.configure(this, flutterEngine.dartExecutor.binaryMessenger)
         kelivo.backgroundRuntime.attachActivity(this)
         deviceLocalToolsHandler = kelivo.deviceTools.also { it.attachActivity(this) }
         workspacePlugin = kelivo.workspace.also { it.attachActivity(this) }
        processTextChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, processTextChannelName)
        processTextChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialText" -> {
                    val text = pendingProcessText ?: takeProcessText(intent)
                    pendingProcessText = null
                    result.success(text)
                }
                else -> result.notImplemented()
            }
        }
        fileSaveChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, fileSaveChannelName)
        fileSaveChannel?.setMethodCallHandler { call, result ->
            // DartMessenger may have queued this handler before it was removed.
            if (fileSaveChannel == null) {
                result.error("cancelled", "The file picker was closed.", null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "saveFileFromPath" -> handleSaveFileFromPath(call.arguments, result)
                "createWritableFile" -> handleCreateWritableFile(call.arguments, result)
                "writeWritableFileChunk" -> handleWriteWritableFileChunk(call.arguments, result)
                "completeWritableFile" -> handleCompleteWritableFile(result)
                "abortWritableFile" -> handleAbortWritableFile(result)
                else -> result.notImplemented()
            }
        }
        deviceStorageChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceStorageChannelName)
        deviceStorageChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "freeBytes" -> result.success(usableBytesForAppData())
                else -> result.notImplemented()
            }
        }
        deviceResourcesChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceResourcesChannelName)
        deviceResourcesChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "snapshot" -> result.success(deviceResourceSnapshot())
                else -> result.notImplemented()
            }
        }
        publicStorageChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            publicStorageChannelName,
        )
        publicStorageChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "selectFolder" -> selectKelivoPublicFolder(result)
                "getFolderInfo" -> {
                    val uri = readTreeUri(call.argument<String>("uri"))
                    if (uri == null) {
                        result.success(mapOf("accessible" to false, "reason" to "invalid_uri"))
                    } else {
                        result.success(publicFolderInfo(uri))
                    }
                }
                "ensureStructure" -> {
                    val uri = requirePublicTreeUri(call.argument<String>("uri"), result) ?: return@setMethodCallHandler
                    try {
                        result.success(ensurePublicFolderStructure(uri))
                    } catch (error: Exception) {
                        result.error("storage_structure_failed", error.message ?: "Could not create KELIVO folders.", null)
                    }
                }
                "exportFile" -> handlePublicStorageExport(call.arguments, result)
                "releaseFolder" -> {
                    val uri = readTreeUri(call.argument<String>("uri"))
                    if (uri != null) releasePublicFolder(uri)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Space the app may still use on the volume holding its data, or null when
     * it cannot be determined. Callers treat null as "unknown" and carry on.
     */
    private fun usableBytesForAppData(): Long? = try {
        val target = filesDir ?: dataDir
        StatFs(target.absolutePath).availableBytes.takeIf { it > 0 }
    } catch (_: Exception) {
        null
    }

    /** Read-only telemetry used to preflight long-running local video renders. */
    private fun deviceResourceSnapshot(): Map<String, Any?> {
        val activityManager = getSystemService(ACTIVITY_SERVICE) as? ActivityManager
        val memory = ActivityManager.MemoryInfo()
        val memoryInfoRead = try {
            if (activityManager != null) {
                activityManager.getMemoryInfo(memory)
                true
            } else {
                false
            }
        } catch (_: Exception) {
            false
        }
        val memoryAvailable = if (memoryInfoRead) memory.availMem.takeIf { it > 0L } else null
        val memoryTotal = if (memoryInfoRead) memory.totalMem.takeIf { it > 0L } else null
        val memoryThreshold = if (memoryInfoRead) memory.threshold.takeIf { it > 0L } else null
        val storage = try {
            StatFs((filesDir ?: dataDir).absolutePath)
        } catch (_: Exception) { null }
        val powerManager = getSystemService(POWER_SERVICE) as? PowerManager
        val thermalStatus = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && powerManager != null) {
                powerManager.currentThermalStatus
            } else null
        } catch (_: Exception) { null }
        val thermalHeadroom = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && powerManager != null) {
                powerManager.getThermalHeadroom(10).takeIf { it.isFinite() && it >= 0f }
            } else null
        } catch (_: Exception) { null }
        val batteryTemperature = try {
            registerReceiver(null, android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                ?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE)
                ?.takeIf { it != Int.MIN_VALUE }
                ?.let { it / 10.0 }
        } catch (_: Exception) { null }
        val cpuPercent = processCpuPercent()
        val pssBytes = try { Debug.getPss().takeIf { it > 0 }?.toLong()?.times(1024L) }
            catch (_: Exception) { null }
        return mapOf(
            "availableMemoryBytes" to memoryAvailable,
            "totalMemoryBytes" to memoryTotal,
            "memoryThresholdBytes" to memoryThreshold,
            "lowMemory" to if (memoryInfoRead) memory.lowMemory else null,
            "processPssBytes" to pssBytes,
            "processCpuPercentOfOneCore" to cpuPercent,
            "availableStorageBytes" to try { storage?.availableBytes?.takeIf { it > 0L } } catch (_: Exception) { null },
            "totalStorageBytes" to try { storage?.totalBytes?.takeIf { it > 0L } } catch (_: Exception) { null },
            "thermalStatus" to thermalStatus,
            "thermalHeadroom" to thermalHeadroom,
            "batteryTemperatureCelsius" to batteryTemperature,
            "measuredAtEpochMs" to System.currentTimeMillis(),
        )
    }

    /** Process CPU utilization since the previous snapshot, normalized to one core. */
    @Synchronized
    private fun processCpuPercent(): Double? {
        return try {
            val wallNow = SystemClock.elapsedRealtime()
            val cpuNow = Process.getElapsedCpuTime()
            val previousWall = lastProcessCpuWallTimeMs
            val previousCpu = lastProcessCpuTimeMs
            lastProcessCpuWallTimeMs = wallNow
            lastProcessCpuTimeMs = cpuNow
            if (previousWall == null || previousCpu == null) {
                null
            } else {
                val wallDelta = wallNow - previousWall
                val cpuDelta = cpuNow - previousCpu
                if (wallDelta <= 0L || cpuDelta < 0L) {
                    null
                } else {
                    (cpuDelta.toDouble() * 100.0 / wallDelta.toDouble())
                        .coerceIn(
                            0.0,
                            Runtime.getRuntime().availableProcessors().coerceAtLeast(1) * 100.0,
                        )
                }
            }
        } catch (_: Exception) {
            null
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        kelivo.backgroundRuntime.receiveConversation(intent)
        setIntent(intent)
        receivedShare = incomingShareHandler?.receive(intent) == true
        val text = takeProcessText(intent) ?: return
        val ch = processTextChannel
        if (ch != null) {
            ch.invokeMethod("onProcessText", text)
        } else {
            pendingProcessText = text
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // The shared engine can move to another Activity before this one is
        // destroyed. Remove these handlers during detach, before its new host
        // registers replacements on the same messenger.
        kelivo.messageInput.detachActivity(this)
        selectionMenu?.dispose()
        selectionMenu = null
        deviceLocalToolsHandler?.detachActivity(this)
        kelivo.backgroundRuntime.detachActivity(this)
        OAuthHandler.detachActivity(this)
        processTextChannel?.setMethodCallHandler(null)
        processTextChannel = null
        fileSaveChannel?.setMethodCallHandler(null)
        fileSaveChannel = null
        deviceStorageChannel?.setMethodCallHandler(null)
        deviceStorageChannel = null
        deviceResourcesChannel?.setMethodCallHandler(null)
        deviceResourcesChannel = null
        publicStorageChannel?.setMethodCallHandler(null)
        publicStorageChannel = null
        finishPendingSave(pendingSaveResult) {
            it.error("cancelled", "The file picker was closed.", null)
        }
        pendingPublicFolderResult?.let { pending ->
            pendingPublicFolderResult = null
            pending.error("cancelled", "The folder picker was closed.", null)
        }
        val stream = pendingWritableStream
        val uri = pendingWritableUri
        if (stream != null && uri != null) {
            writableFileExecutor.execute {
                // Serialized after all queued writes/completion. A successful
                // completion marks COMMITTED before posting its UI callback,
                // so an intact backup is never deleted in this race window.
                if (writableFileState == WritableFileState.OPEN) {
                    discardWritableDestination(stream, uri)
                }
            }
        }
        // Submitted writes and cleanup finish, but this detached host is done.
        writableFileExecutor.shutdown()
        incomingShareHandler?.dispose()
        incomingShareHandler = null
        workspacePlugin?.detachActivity(this)
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        highRefreshRate.dispose()
        publicStorageExecutor.shutdown()
        super.onDestroy()
    }

     override fun onRequestPermissionsResult(
         requestCode: Int,
         permissions: Array<out String>,
         grantResults: IntArray,
     ) {
         if (workspacePlugin?.onRequestPermissionsResult(requestCode) == true) return
        if (kelivo.backgroundRuntime.permissionResult(requestCode)) return
         if (deviceLocalToolsHandler?.onRequestPermissionsResult(requestCode, grantResults) == true) {
             return
         }
         super.onRequestPermissionsResult(requestCode, permissions, grantResults)
     }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == SELECT_KELIVO_FOLDER_REQUEST_CODE) {
            completeKelivoPublicFolderSelection(resultCode, data)
            return
        }
        if (workspacePlugin?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != CREATE_DOCUMENT_REQUEST_CODE) {
            return
        }

        val destUri = if (resultCode == Activity.RESULT_OK) data?.data else null
        handleSaveDestination(destUri)
    }

    private fun selectKelivoPublicFolder(result: MethodChannel.Result) {
        if (pendingPublicFolderResult != null) {
            result.error("busy", "A KELIVO folder selection is already active.", null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION,
            )
        }
        try {
            pendingPublicFolderResult = result
            startActivityForResult(intent, SELECT_KELIVO_FOLDER_REQUEST_CODE)
        } catch (error: ActivityNotFoundException) {
            pendingPublicFolderResult = null
            result.error("folder_picker_unavailable", "No system folder picker is available.", null)
        } catch (error: Exception) {
            pendingPublicFolderResult = null
            result.error("folder_picker_failed", error.message, null)
        }
    }

    private fun completeKelivoPublicFolderSelection(resultCode: Int, data: Intent?) {
        val pending = pendingPublicFolderResult ?: return
        pendingPublicFolderResult = null
        if (resultCode != Activity.RESULT_OK) {
            pending.success(null)
            return
        }
        val uri = data?.data
        if (uri == null) {
            pending.error("folder_uri_missing", "The selected folder did not return a URI.", null)
            return
        }
        val grantFlags = data.flags and (
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        )
        val requiredGrantFlags =
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        if ((grantFlags and requiredGrantFlags) != requiredGrantFlags) {
            pending.error("folder_read_write_not_granted", "Android did not grant both read and write access to the selected folder.", null)
            return
        }
        try {
            contentResolver.takePersistableUriPermission(uri, grantFlags)
            val info = publicFolderInfo(uri)
            if (info["accessible"] != true) {
                pending.error("folder_access_not_persisted", "Android did not grant persistent read/write access to this folder.", null)
            } else {
                pending.success(mapOf(
                    "uri" to uri.toString(),
                    "name" to (info["name"] as? String ?: "KELIVO"),
                    "accessible" to true,
                ))
            }
        } catch (error: Exception) {
            pending.error("folder_access_failed", error.message ?: "Could not retain folder access.", null)
        }
    }

    private fun readTreeUri(raw: String?): Uri? = try {
        raw?.takeIf { it.startsWith("content://") }?.let(Uri::parse)
    } catch (_: Exception) {
        null
    }

    private fun requirePublicTreeUri(
        raw: String?,
        result: MethodChannel.Result,
    ): Uri? {
        val uri = readTreeUri(raw)
        if (uri == null) {
            result.error("invalid_folder_uri", "A previously selected KELIVO folder is required.", null)
            return null
        }
        val accessible = contentResolver.persistedUriPermissions.any {
            it.uri == uri && it.isReadPermission && it.isWritePermission
        }
        if (!accessible) {
            result.error("folder_access_revoked", "The saved folder permission is no longer available. Select the folder again.", null)
            return null
        }
        return uri
    }

    private fun publicFolderInfo(treeUri: Uri): Map<String, Any?> {
        val grant = contentResolver.persistedUriPermissions.firstOrNull {
            it.uri == treeUri && it.isReadPermission && it.isWritePermission
        }
        return mapOf(
            "accessible" to (grant != null),
            "readGranted" to (grant?.isReadPermission == true),
            "writeGranted" to (grant?.isWritePermission == true),
            "name" to "KELIVO",
        )
    }

    private fun releasePublicFolder(treeUri: Uri) {
        try {
            val flags = contentResolver.persistedUriPermissions
                .firstOrNull { it.uri == treeUri }
                ?.let {
                    (if (it.isReadPermission) Intent.FLAG_GRANT_READ_URI_PERMISSION else 0) or
                        (if (it.isWritePermission) Intent.FLAG_GRANT_WRITE_URI_PERMISSION else 0)
                } ?: 0
            if (flags != 0) contentResolver.releasePersistableUriPermission(treeUri, flags)
        } catch (_: Exception) {
            // A revoked or already-released grant needs no further action.
        }
    }

    private fun ensurePublicFolderStructure(treeUri: Uri): List<String> {
        val kelivoRoot = resolveKelivoRootDocument(treeUri)
        val folders = listOf("Projects", "Results", "Downloads", "Skills-Exports", "Reports", "Backups")
        folders.forEach { ensureChildDirectory(treeUri, kelivoRoot, it) }
        return folders
    }

    /**
     * The user may choose an existing KELIVO folder or a parent location such
     * as Documents. In the latter case, keep all app-owned files in a KELIVO
     * child folder rather than scattering folders at the selected location.
     */
    private fun resolveKelivoRootDocument(treeUri: Uri): Uri {
        val rootDocumentId = DocumentsContract.getTreeDocumentId(treeUri)
        val selectedRoot = DocumentsContract.buildDocumentUriUsingTree(treeUri, rootDocumentId)
        val selectedName = queryDocumentDisplayName(selectedRoot)
        return if (selectedName.equals("KELIVO", ignoreCase = true)) {
            selectedRoot
        } else {
            ensureChildDirectory(treeUri, selectedRoot, "KELIVO")
        }
    }

    private fun queryDocumentDisplayName(uri: Uri): String? {
        contentResolver.query(
            uri,
            arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                if (index >= 0) return cursor.getString(index)
            }
        }
        return null
    }

    private fun childDocument(
        treeUri: Uri,
        parentDocument: Uri,
        name: String,
    ): Uri? {
        val parentId = DocumentsContract.getDocumentId(parentDocument)
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, parentId)
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
        )
        contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            val idIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            while (cursor.moveToNext()) {
                if (nameIndex >= 0 && cursor.getString(nameIndex) == name && idIndex >= 0) {
                    return DocumentsContract.buildDocumentUriUsingTree(
                        treeUri,
                        cursor.getString(idIndex),
                    )
                }
            }
        }
        return null
    }

    private fun ensureChildDirectory(
        treeUri: Uri,
        parentDocument: Uri,
        name: String,
    ): Uri {
        val existing = childDocument(treeUri, parentDocument, name)
        if (existing != null) {
            val mime = queryDocumentMime(existing)
            if (mime == DocumentsContract.Document.MIME_TYPE_DIR) return existing
            throw IllegalStateException("A non-folder item already uses the name '$name'.")
        }
        return DocumentsContract.createDocument(
            contentResolver,
            parentDocument,
            DocumentsContract.Document.MIME_TYPE_DIR,
            name,
        ) ?: throw IllegalStateException("Could not create folder '$name'.")
    }

    private fun queryDocumentMime(uri: Uri): String? {
        contentResolver.query(
            uri,
            arrayOf(DocumentsContract.Document.COLUMN_MIME_TYPE),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_MIME_TYPE)
                if (index >= 0) return cursor.getString(index)
            }
        }
        return null
    }

    private fun safePublicRelativePath(raw: String): List<String> {
        if (raw.isBlank() || raw.length > 1024 || raw.contains('\\') || raw.contains('\u0000')) {
            throw IllegalArgumentException("Invalid relative output path.")
        }
        val segments = raw.split('/')
        if (segments.size !in 2..16 || segments.any { segment ->
                segment.isBlank() || segment == "." || segment == ".." ||
                    segment.length > 128 || segment.any { it.code < 0x20 || it.code == 0x7f }
            }) {
            throw IllegalArgumentException("Invalid relative output path.")
        }
        return segments
    }

    private fun findExistingFile(parent: Uri, treeUri: Uri, name: String): Uri? =
        childDocument(treeUri, parent, name)?.takeIf {
            queryDocumentMime(it) != DocumentsContract.Document.MIME_TYPE_DIR
        }

    private fun copyPrivateFileToDocument(source: File, destination: Uri) {
        val outputStream = contentResolver.openOutputStream(destination, "wt")
            ?: throw IllegalStateException("Could not open the selected folder for writing.")
        outputStream.use { output ->
            FileInputStream(source).use { input -> input.copyTo(output, 64 * 1024) }
        }
    }

    private fun copyDocumentToDocument(source: Uri, destination: Uri) {
        contentResolver.openInputStream(source)?.use { input ->
            contentResolver.openOutputStream(destination, "wt")?.use { output ->
                input.copyTo(output, 64 * 1024)
            } ?: throw IllegalStateException("Could not open output document.")
        } ?: throw IllegalStateException("Could not read temporary document.")
    }

    private fun handlePublicStorageExport(arguments: Any?, result: MethodChannel.Result) {
        val args = arguments as? Map<*, *>
        val treeUri = requirePublicTreeUri(args?.get("uri") as? String, result) ?: return
        val sourcePath = (args?.get("sourcePath") as? String).orEmpty()
        val relativePath = (args?.get("relativePath") as? String).orEmpty()
        val overwrite = args?.get("overwrite") != false
        val source = try {
            File(sourcePath).canonicalFile
        } catch (_: Exception) {
            result.error("invalid_source_path", "The private source file path is invalid.", null)
            return
        }
        val privateRoot = try { dataDir.canonicalFile.path } catch (_: Exception) { dataDir.path }
        if (!source.isFile || !source.path.startsWith(privateRoot + File.separator)) {
            result.error("source_outside_private_storage", "Only files inside Kelivo's private app storage can be exported through this channel.", null)
            return
        }
        val segments = try {
            safePublicRelativePath(relativePath)
        } catch (error: Exception) {
            result.error("invalid_relative_path", error.message, null)
            return
        }
        publicStorageExecutor.execute {
            try {
                var parent = resolveKelivoRootDocument(treeUri)
                for (folder in segments.dropLast(1)) {
                    parent = ensureChildDirectory(treeUri, parent, folder)
                }
                val fileName = segments.last()
                val existing = findExistingFile(parent, treeUri, fileName)
                if (existing != null && !overwrite) {
                    throw IllegalStateException("The destination file already exists.")
                }
                val mime = MimeTypeMap.getSingleton()
                    .getMimeTypeFromExtension(fileName.substringAfterLast('.', "").lowercase(Locale.ROOT))
                    ?: "application/octet-stream"
                val tempName = ".$fileName.kelivo-${UUID.randomUUID()}.tmp"
                val temp = DocumentsContract.createDocument(
                    contentResolver,
                    parent,
                    mime,
                    tempName,
                ) ?: throw IllegalStateException("Could not create a temporary destination document.")
                var backup: Uri? = null
                var finalDocument: Uri? = null
                try {
                    copyPrivateFileToDocument(source, temp)
                    if (existing != null) {
                        backup = try {
                            DocumentsContract.renameDocument(contentResolver, existing, ".$fileName.kelivo-backup-${UUID.randomUUID()}")
                        } catch (_: Exception) { null }
                        if (backup == null) {
                            // Keep the old file intact until a complete replacement exists.
                            val replacement = DocumentsContract.createDocument(contentResolver, parent, mime, fileName)
                                ?: throw IllegalStateException("Could not create replacement file.")
                            try {
                                copyDocumentToDocument(temp, replacement)
                                DocumentsContract.deleteDocument(contentResolver, existing)
                                finalDocument = replacement
                            } catch (error: Exception) {
                                try { DocumentsContract.deleteDocument(contentResolver, replacement) } catch (_: Exception) {}
                                throw error
                            }
                        }
                    }
                    if (finalDocument == null) {
                        val renamed = try {
                            DocumentsContract.renameDocument(contentResolver, temp, fileName)
                        } catch (_: Exception) { null }
                        finalDocument = renamed
                        if (renamed == null) {
                            val replacement = DocumentsContract.createDocument(contentResolver, parent, mime, fileName)
                                ?: throw IllegalStateException("The folder provider does not support atomic rename or replacement creation.")
                            try {
                                copyDocumentToDocument(temp, replacement)
                                finalDocument = replacement
                            } catch (error: Exception) {
                                try { DocumentsContract.deleteDocument(contentResolver, replacement) } catch (_: Exception) {}
                                throw error
                            }
                        }
                    }
                    if (backup != null) {
                        try { DocumentsContract.deleteDocument(contentResolver, backup) } catch (_: Exception) {}
                    }
                    if (temp != finalDocument) {
                        try { DocumentsContract.deleteDocument(contentResolver, temp) } catch (_: Exception) {}
                    }
                    val payload = mapOf(
                        "relativePath" to relativePath,
                        "fileName" to fileName,
                        "sizeBytes" to source.length(),
                        "mimeType" to mime,
                    )
                    runOnUiThread { result.success(payload) }
                } catch (error: Exception) {
                    if (finalDocument == null && backup != null) {
                        try { DocumentsContract.renameDocument(contentResolver, backup, fileName) } catch (_: Exception) {}
                    }
                    try { DocumentsContract.deleteDocument(contentResolver, temp) } catch (_: Exception) {}
                    runOnUiThread { result.error("storage_export_failed", error.message ?: "File export failed.", null) }
                }
            } catch (error: Exception) {
                runOnUiThread { result.error("storage_export_failed", error.message ?: "File export failed.", null) }
            }
        }
    }

    private fun handleSaveFileFromPath(arguments: Any?, result: MethodChannel.Result) {
        if (pendingSaveResult != null || pendingWritableStream != null) {
            result.error("busy", "Another save operation is already in progress.", null)
            return
        }

        val args = arguments as? Map<*, *>
        val rawSourcePath = (args?.get("sourcePath") as? String).orEmpty()
        if (rawSourcePath.isEmpty()) {
            result.error("invalid_args", "Missing sourcePath.", null)
            return
        }

        val sourceFile = File(rawSourcePath)
        if (!sourceFile.exists() || !sourceFile.isFile) {
            result.error("not_found", "Source file does not exist.", null)
            return
        }

        val suggestedFileName = (args?.get("fileName") as? String).takeUnless { it.isNullOrEmpty() }
            ?: sourceFile.name

        pendingSaveResult = result
        pendingSaveSourcePath = sourceFile.absolutePath

        try {
            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = fileSaveMimeType(suggestedFileName)
                putExtra(Intent.EXTRA_TITLE, suggestedFileName)
            }
            startActivityForResult(intent, CREATE_DOCUMENT_REQUEST_CODE)
        } catch (e: ActivityNotFoundException) {
            finishPendingSave(result) { it.error("launch_failed", e.message, null) }
        }
    }

    private fun handleCreateWritableFile(arguments: Any?, result: MethodChannel.Result) {
        if (pendingSaveResult != null || pendingWritableStream != null) {
            result.error("busy", "Another save operation is already in progress.", null)
            return
        }

        val args = arguments as? Map<*, *>
        val fileName = args?.get("fileName")?.toString()?.trim().orEmpty()
        if (fileName.isEmpty()) {
            result.error("invalid_args", "Missing fileName.", null)
            return
        }

        pendingSaveResult = result
        pendingDirectWrite = true
        try {
            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "application/zip"
                putExtra(Intent.EXTRA_TITLE, fileName)
            }
            startActivityForResult(intent, CREATE_DOCUMENT_REQUEST_CODE)
        } catch (e: ActivityNotFoundException) {
            finishPendingSave(result) { it.error("launch_failed", e.message, null) }
        }
    }

    private fun handleCompleteWritableFile(result: MethodChannel.Result) {
        val stream = pendingWritableStream
        if (stream == null) {
            result.error("not_open", "No writable file destination is open.", null)
            return
        }

        writableFileExecutor.execute {
            try {
                stream.flush()
                stream.close()
                writableFileState = WritableFileState.COMMITTED
                runOnUiThread {
                    if (pendingWritableStream === stream) {
                        pendingWritableStream = null
                        pendingWritableUri = null
                    }
                    result.success(true)
                }
            } catch (e: Exception) {
                runOnUiThread {
                    result.error("close_failed", e.message, null)
                }
            }
        }
    }

    private fun handleWriteWritableFileChunk(arguments: Any?, result: MethodChannel.Result) {
        val stream = pendingWritableStream
        if (stream == null) {
            result.error("not_open", "No writable file destination is open.", null)
            return
        }
        val bytes = arguments as? ByteArray
        if (bytes == null) {
            result.error("invalid_args", "Missing writable file bytes.", null)
            return
        }
        if (bytes.isEmpty()) {
            result.success(true)
            return
        }

        writableFileExecutor.execute {
            try {
                stream.write(bytes)
                runOnUiThread { result.success(true) }
            } catch (e: Exception) {
                runOnUiThread {
                    result.error("write_failed", e.message, null)
                }
            }
        }
    }

    private fun handleAbortWritableFile(result: MethodChannel.Result) {
        val stream = pendingWritableStream
        val uri = pendingWritableUri
        if (stream == null || uri == null) {
            result.error("not_open", "No writable file destination is open.", null)
            return
        }

        writableFileExecutor.execute {
            val cleanupError = discardWritableDestination(stream, uri)

            runOnUiThread {
                if (pendingWritableStream === stream) {
                    pendingWritableStream = null
                    pendingWritableUri = null
                }
                if (cleanupError == null) {
                    result.success(true)
                } else {
                    result.error("discard_failed", cleanupError.message, null)
                }
            }
        }
    }

    private fun discardWritableDestination(stream: OutputStream, uri: Uri): Exception? {
        var cleanupError: Exception? = null
        try {
            stream.close()
        } catch (e: Exception) {
            cleanupError = e
        }

        var deleted = false
        try {
            deleted = DocumentsContract.deleteDocument(contentResolver, uri)
            if (!deleted) {
                cleanupError = cleanupError
                    ?: IllegalStateException("Unable to delete incomplete destination file.")
            }
        } catch (e: Exception) {
            cleanupError = cleanupError ?: e
        }
        if (deleted) {
            writableFileState = WritableFileState.DISCARDED
        }
        return cleanupError
    }

    // All callers run on the main thread. Clear the matching request before
    // replying so cancellation, completion and a late worker cannot reply twice.
    private fun finishPendingSave(
        expected: MethodChannel.Result?,
        reply: (MethodChannel.Result) -> Unit,
    ) {
        if (expected == null || pendingSaveResult !== expected) return
        pendingSaveResult = null
        pendingSaveSourcePath = null
        pendingDirectWrite = false
        reply(expected)
    }

    private fun handleSaveDestination(destUri: Uri?) {
        val result = pendingSaveResult ?: return
        if (pendingDirectWrite) {
            if (destUri == null) {
                finishPendingSave(result) { it.success(null) }
                return
            }
            try {
                pendingWritableUri = destUri
                val descriptor = contentResolver.openFileDescriptor(destUri, "rwt")
                    ?: throw IllegalStateException("Unable to open destination file.")
                pendingWritableStream = ParcelFileDescriptor.AutoCloseOutputStream(descriptor)
                writableFileState = WritableFileState.OPEN
                finishPendingSave(result) { it.success(true) }
            } catch (e: Exception) {
                try {
                    DocumentsContract.deleteDocument(contentResolver, destUri)
                } catch (_: Exception) {
                    // Preserve the error that prevented the destination from opening.
                }
                pendingWritableUri = null
                finishPendingSave(result) { it.error("open_failed", e.message, null) }
            }
            return
        }
        val sourcePath = pendingSaveSourcePath

        if (destUri == null || sourcePath.isNullOrEmpty()) {
            finishPendingSave(result) { it.success(false) }
            return
        }

        Thread {
            try {
                contentResolver.openOutputStream(destUri)?.use { outputStream ->
                    FileInputStream(File(sourcePath)).use { inputStream ->
                        inputStream.copyTo(outputStream, DEFAULT_BUFFER_SIZE)
                    }
                } ?: throw IllegalStateException("Unable to open destination stream.")

                runOnUiThread {
                    finishPendingSave(result) { it.success(true) }
                }
            } catch (e: Exception) {
                runOnUiThread {
                    finishPendingSave(result) { it.error("save_failed", e.message, null) }
                }
            }
        }.start()
    }
}

internal fun fileSaveMimeType(fileName: String): String =
    MimeTypeMap.getSingleton()
        .getMimeTypeFromExtension(File(fileName).extension.lowercase(Locale.ROOT))
        ?: "application/octet-stream"

/** Cold launches are read by HomePage; a retained HomePage instead needs an
 * event when Android creates its replacement Activity. Consume the extra so
 * restoring that Activity or querying initial text cannot deliver it twice. */
internal fun forwardCachedProcessTextLaunch(
    reusedEngine: Boolean,
    savedState: Bundle?,
    intent: Intent,
    channel: MethodChannel?,
) {
    if (reusedEngine && savedState == null && channel != null &&
        intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY == 0) {
        takeProcessText(intent)?.let { channel.invokeMethod("onProcessText", it) }
    }
}

internal fun takeProcessText(intent: Intent?): String? {
    if (intent?.action != Intent.ACTION_PROCESS_TEXT) return null
    val text = intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()
    intent.removeExtra(Intent.EXTRA_PROCESS_TEXT)
    return text?.trim()?.takeIf { it.isNotEmpty() }
}

/** The notifications plugin queries cold launches once from Dart. A new
 * Activity on an existing engine needs its new notification Intent forwarded,
 * because onAttachedToActivity does not deliver a normal notification tap. */
internal fun forwardCachedNotificationLaunch(
    reusedEngine: Boolean,
    savedState: Bundle?,
    intent: Intent,
    plugin: FlutterLocalNotificationsPlugin,
) {
    if (reusedEngine && savedState == null &&
        intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY == 0) {
        plugin.onNewIntent(intent)
    }
}

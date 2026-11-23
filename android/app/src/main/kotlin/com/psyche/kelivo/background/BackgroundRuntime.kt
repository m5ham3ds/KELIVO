package com.psyche.kelivo.background

import android.Manifest
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.psyche.kelivo.MainActivity
import com.psyche.kelivo.KelivoApplication
import com.psyche.kelivo.R
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

data class BackgroundTask(
    val id: String,
    val conversationId: String,
    val title: String,
    val detail: String,
    val startedAt: Long,
    val tokens: Int,
    val progressPercent: Int? = null,
    val progressLabel: String = "",
    val cancellable: Boolean = true,
    val outcome: String = "",
    val finishedAt: Long = 0,
) {
    companion object {
        fun fromMap(map: Map<*, *>): BackgroundTask = BackgroundTask(
            map["id"] as? String ?: "",
            map["conversationId"] as? String ?: "",
            map["title"] as? String ?: "Kelivo",
            map["detail"] as? String ?: "",
            (map["startedAt"] as? Number)?.toLong() ?: System.currentTimeMillis(),
            (map["tokens"] as? Number)?.toInt() ?: 0,
            (map["progressPercent"] as? Number)?.toInt()?.coerceIn(0, 100),
            map["progressLabel"] as? String ?: "",
            map["cancellable"] as? Boolean ?: true,
            map["outcome"] as? String ?: "",
            (map["finishedAt"] as? Number)?.toLong() ?: 0,
        )
    }
}

class BackgroundRuntime(private val context: Context) {
    companion object {
        const val CHANNEL_ID = "kelivo_generation_status"
        const val NOTIFICATION_ID = 7
        const val NOTIFICATION_PERMISSION_REQUEST = 4301
        const val CONVERSATION_EXTRA = "kelivo.background.conversation"
        const val APPROVAL_CHANNEL_ID = "kelivo_tool_approval"
        private const val PENDING_CONVERSATION = "pending_conversation"
        const val APPROVAL_ID_EXTRA = "kelivo.approval.id"
        const val APPROVAL_CONVERSATION_EXTRA = "kelivo.approval.conversation"
        const val APPROVAL_ALLOWED_EXTRA = "kelivo.approval.allowed"
        const val APPROVAL_ACTION = "kelivo.approval.action"
    }

    private val prefs = context.getSharedPreferences("kelivo_background", Context.MODE_PRIVATE)
    private val main = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private var approvalChannel: MethodChannel? = null
    private var activity = WeakReference<Activity>(null)
    private var dartReady = false
    private var revision = -1L
    private var serviceStarting = false
    private var blocked = false
    private var settings: Map<*, *> = emptyMap<String, Any>()
    private var labels: Map<*, *> = emptyMap<String, Any>()
    var tasks: List<BackgroundTask> = emptyList()
        private set
    var foreground = true
        private set
    var service: GenerationForegroundService? = null
        private set
    /** Phone control gestures are real touches: a capsule above the target app
     * would receive them and reopen Kelivo. Cleared when the tasks end. */
    var phoneControlActive = false
        private set
    private val overlay by lazy { BackgroundOverlay(context, this, prefs) }

    fun enabled(key: String) = settings[key] == true
    fun label(key: String, default: String) = labels[key] as? String ?: default
    fun setting(key: String) = settings[key]
    private val scheduledRuns = mutableSetOf<String>()
    val hasScheduledRuns get() = scheduledRuns.isNotEmpty()
    fun shouldRunService() = ((enabled("androidEnabled") && tasks.isNotEmpty()) || hasScheduledRuns) && !blocked

    fun beginScheduledRun(id: String) {
        scheduledRuns.add(id)
        blocked = false
        reconcileService()
        if (blocked) (context as KelivoApplication).scheduledTasks.stopAll("foreground_service_start_failed")
    }

    fun endScheduledRun(id: String) {
        scheduledRuns.remove(id)
        reconcileService()
    }

    fun configure(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "app.mobile_background").also { channel ->
            channel.setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "sync" -> {
                            sync(call.arguments as? Map<*, *> ?: emptyMap<String, Any>())
                            result.success(status())
                        }
                        "getStatus" -> result.success(status())
                        "takePendingConversation" -> {
                            dartReady = true
                            val id = prefs.getString(PENDING_CONVERSATION, null)
                            prefs.edit().remove(PENDING_CONVERSATION).apply()
                            result.success(id)
                        }
                        "requestPermission" -> {
                            requestPermission(call.arguments as? String ?: "")
                            result.success(null)
                        }
                        "openSettings" -> {
                            openSettings(call.arguments as? String ?: "app")
                            result.success(null)
                        }
                        "audioOwner" -> result.success(null) // iOS audio-session arbitration
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    recordError(error.message ?: error.javaClass.simpleName)
                    result.error("background", error.message, null)
                }
            }
        }
        approvalChannel = MethodChannel(messenger, "app.tool_approval_notifications").also { approval ->
            approval.setMethodCallHandler { call, result ->
                try {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                    when (call.method) {
                        "show" -> result.success(showApprovalNotification(args))
                        "dismiss" -> {
                            dismissApprovalNotification(args)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    recordError("approval_notification_failed: ${error.message}")
                    result.error("approval_notification", error.message, null)
                }
            }
        }
        // A new process cannot resume an old HTTP stream. Never restore an
        // ongoing notification or overlay from persisted task metadata.
        if (service == null && !serviceStarting) context.getSystemService(NotificationManager::class.java)?.cancel(NOTIFICATION_ID)
        if (service == null && prefs.getBoolean("service_was_active", false)) {
            recordError("previous_process_terminated")
            prefs.edit().putBoolean("service_was_active", false).apply()
        }
    }

    fun attachActivity(value: Activity) { activity = WeakReference(value) }

    fun detachActivity(value: Activity) {
        if (activity.get() === value) activity.clear()
    }

    fun phoneControlStarted() {
        phoneControlActive = true
        overlay.refresh()
    }

    fun setForeground(value: Boolean) {
        foreground = value
        if (value) blocked = false
        overlay.onForegroundChanged(value)
        reconcileService()
        channel?.invokeMethod("statusChanged", null)
    }

    private fun sync(args: Map<*, *>) {
        val nextRevision = (args["revision"] as? Number)?.toLong() ?: return
        if (nextRevision <= revision) return
        revision = nextRevision
        val previousIds = tasks.map { it.id }.toSet()
        val wasEnabled = enabled("androidEnabled")
        val wasPrivate = enabled("privacyMode")
        settings = args["settings"] as? Map<*, *> ?: emptyMap<String, Any>()
        labels = args["labels"] as? Map<*, *> ?: emptyMap<String, Any>()
        tasks = (args["tasks"] as? List<*>)?.mapNotNull {
            (it as? Map<*, *>)?.let(BackgroundTask::fromMap)?.takeIf { task -> task.id.isNotEmpty() }
        } ?: emptyList()
        if (tasks.isEmpty()) phoneControlActive = false
        if ((!wasEnabled && enabled("androidEnabled")) ||
            (foreground && tasks.any { it.id !in previousIds })) blocked = false
        if (!wasPrivate && enabled("privacyMode")) {
            clearCompletionNotifications()
            overlay.clearCompleted()
        }
        val terminal = (args["terminal"] as? Map<*, *>)?.let(BackgroundTask::fromMap)
        overlay.sync(tasks, terminal)
        reconcileService()
    }

    private fun reconcileService() {
        if (shouldRunService()) {
            val running = service
            if (running != null) {
                running.refresh()
            } else if (!serviceStarting) {
                try {
                    serviceStarting = true
                    ContextCompat.startForegroundService(context,
                        Intent(context, GenerationForegroundService::class.java))
                } catch (error: RuntimeException) {
                    serviceStarting = false
                    blocked = true
                    recordError("foreground_service_start_failed: ${error.message}")
                }
            }
        } else {
            service?.stopGenerationService()
        }
        overlay.refresh()
    }

    fun serviceStarted(value: GenerationForegroundService) {
        serviceStarting = false
        service = value
        prefs.edit().putBoolean("service_was_active", true)
            .remove("service_restart_pending").apply()
        channel?.invokeMethod("statusChanged", null)
        // The system sets FLAG_PROMOTED_ONGOING after notify/startForeground.
        main.postDelayed({ overlay.refresh() }, 300)
    }

    fun serviceStopped(value: GenerationForegroundService) {
        if (service === value) service = null
        serviceStarting = false
        prefs.edit().putBoolean("service_was_active", false).apply()
        channel?.invokeMethod("statusChanged", null)
    }

    /**
     * Android may recreate a started foreground service after an unexpected
     * service teardown. Do not cancel the Dart generation merely because the
     * Service object was destroyed: the Application-owned FlutterEngine and its
     * active streams can still be alive in this process. START_STICKY asks the
     * system to recreate the service; keeping this marker true also makes the
     * transition observable until serviceStarted() confirms the replacement.
     */
    fun serviceDestroyedUnexpectedly(value: GenerationForegroundService) {
        if (service === value) service = null
        serviceStarting = false
        if (shouldRunService()) {
            prefs.edit().putBoolean("service_was_active", true)
                .putBoolean("service_restart_pending", true).apply()
            android.util.Log.w("KelivoBackground", "foreground_service_restarting_with_active_tasks")
        } else {
            prefs.edit().putBoolean("service_was_active", false)
                .remove("service_restart_pending").apply()
        }
        channel?.invokeMethod("statusChanged", null)
    }

    fun stopTasks(reason: String? = null): Boolean {
        if (reason != null) {
            val ids = tasks.map { it.id }
            blocked = true
            recordError(reason)
            (context as? KelivoApplication)?.scheduledTasks?.stopAll(reason)
            channel?.invokeMethod(
                "interrupted",
                mapOf("ids" to ids, "reason" to reason),
            )
            overlay.dismissAll()
            service?.stopGenerationService()
            return false
        }

        val ids = tasks.filter { it.cancellable }.map { it.id }
        (context as? KelivoApplication)?.scheduledTasks?.stopAll("cancelled")
        if (ids.isNotEmpty()) {
            channel?.invokeMethod("cancelTasks", mapOf("ids" to ids))
        } else {
            // A stale Stop action cannot tear down a task past its commit point.
            reconcileService()
        }
        // Dart owns completion and removes the foreground service only after
        // sending a snapshot that confirms all remaining work has ended.
        // Keep the foreground service until Dart sends the terminal snapshot,
        // whether the user stopped a cancellable process or a committed install.
        return shouldRunService()
    }

    fun onTaskRemoved() {
        // Removing the Activity from Recents is not a cancellation request.
        // The foreground service and shared FlutterEngine own active work.
        // Android Force stop/process death remains a separate OS-level limit.
        if (!shouldRunService()) stopTasks("background_execution_disabled")
    }

    fun receiveConversation(intent: Intent?) {
        val id = intent?.getStringExtra(CONVERSATION_EXTRA)?.takeIf { it.isNotBlank() } ?: return
        intent.removeExtra(CONVERSATION_EXTRA)
        if (!dartReady) prefs.edit().putString(PENDING_CONVERSATION, id).apply()
        else channel?.invokeMethod("openConversation", id)
    }

    fun openConversation(id: String) {
        context.startActivity(openIntent(id))
    }

    fun openIntent(id: String) = Intent(context, MainActivity::class.java)
        .putExtra(CONVERSATION_EXTRA, id)
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)

    fun buildNotification(): Notification {
        ensureChannel()
        val task = tasks.firstOrNull()
        val title = if (tasks.size > 1) "${tasks.size} ${label("tasks", "Tasks")}" else task?.title ?: "Kelivo"
        val baseContent = task?.detail ?: label("working", "Working")
        val detailWithProgress = buildString {
            append(baseContent)
            task?.progressLabel?.takeIf { it.isNotBlank() }?.let {
                append(" · ")
                append(it)
            }
            task?.progressPercent?.let {
                append(" · ")
                append(it)
                append('%')
            }
        }
        val content = detailWithProgress
        val open = PendingIntent.getActivity(context, 7, openIntent(task?.conversationId ?: ""),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val stop = PendingIntent.getService(context, 8,
            Intent(context, GenerationForegroundService::class.java).setAction(GenerationForegroundService.STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val canCancelTasks = tasks.any { it.cancellable } || hasScheduledRuns
        if (Build.VERSION.SDK_INT >= 36 && enabled("liveUpdatesEnabled") && canPromote()) {
            val style = Notification.ProgressStyle()
                .addProgressSegment(Notification.ProgressStyle.Segment(100))
                .setStyledByProgress(false)
                .setProgress(task?.progressPercent ?: 0)
                .setProgressIndeterminate(task?.progressPercent == null)
            val builder = Notification.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_background_generation)
                .setContentTitle(title).setContentText(content)
                .setStyle(style).setOngoing(true).setOnlyAlertOnce(true)
                .setProgress(100, task?.progressPercent ?: 0, task?.progressPercent == null)
                .setWhen(task?.startedAt ?: System.currentTimeMillis()).setUsesChronometer(true)
                .setContentIntent(open).setColorized(false)
                .addExtras(Bundle().apply { putBoolean("android.requestPromotedOngoing", true) })
            if (canCancelTasks) {
                builder.addAction(Notification.Action.Builder(
                    Icon.createWithResource(context, R.drawable.ic_background_stop),
                    label("stop", "Stop tasks"), stop).build())
            }
            return builder.build()
        }
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_background_generation)
            .setContentTitle(title).setContentText(content)
            .setStyle(NotificationCompat.BigTextStyle().bigText(content))
            .setOngoing(true).setOnlyAlertOnce(true).setSilent(true)
            .setProgress(100, task?.progressPercent ?: 0, task?.progressPercent == null)
            .setWhen(task?.startedAt ?: System.currentTimeMillis()).setUsesChronometer(true)
            .setContentIntent(open).setCategory(NotificationCompat.CATEGORY_SERVICE)
        if (canCancelTasks) {
            builder.addAction(R.drawable.ic_background_stop, label("stop", "Stop tasks"), stop)
        }
        return builder.build()
    }

    private fun approvalNotificationId(conversationId: String, toolCallId: String): Int {
        val key = "$conversationId\u001f$toolCallId"
        var hash = 0x811c9dc5.toInt()
        key.toByteArray(Charsets.UTF_8).forEach { byte ->
            hash = (hash xor (byte.toInt() and 0xff)) * 0x01000193
        }
        return 200000 + (hash and 0x3fffffff)
    }

    private fun localized(ar: String, en: String): String =
        if (context.resources.configuration.locales[0].language == "ar") ar else en

    private fun showApprovalNotification(args: Map<*, *>): Boolean {
        val toolCallId = (args["toolCallId"] as? String)?.trim().orEmpty()
        val conversationId = (args["conversationId"] as? String)?.trim().orEmpty()
        val toolName = (args["toolName"] as? String)?.trim().orEmpty()
        if (toolCallId.isEmpty() || toolName.isEmpty()) return false
        val manager = context.getSystemService(NotificationManager::class.java) ?: return false
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel(
                    APPROVAL_CHANNEL_ID,
                    localized("موافقات الأدوات", "Tool approvals"),
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = localized(
                        "طلبات الموافقة على عمليات KELIVO قبل تنفيذها",
                        "Approve or deny KELIVO tool operations before they run",
                    )
                    setShowBadge(true)
                },
            )
        }
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) return false
        val notificationId = approvalNotificationId(conversationId, toolCallId)
        fun actionIntent(approved: Boolean, requestCodeOffset: Int): PendingIntent {
            val intent = Intent(context, ToolApprovalActionReceiver::class.java)
                .setAction(APPROVAL_ACTION)
                .putExtra(APPROVAL_ID_EXTRA, toolCallId)
                .putExtra(APPROVAL_CONVERSATION_EXTRA, conversationId)
                .putExtra(APPROVAL_ALLOWED_EXTRA, approved)
            return PendingIntent.getBroadcast(
                context,
                notificationId + requestCodeOffset,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val title = localized("يتطلب KELIVO موافقتك", "KELIVO needs your approval")
        val safeToolName = toolName
            .replace(Regex("[\\r\\n\\t]+"), " ")
            .replace(Regex("\\s+"), " ")
            .take(80)
        val body = localized(
            "العملية: $safeToolName — وافق للمتابعة أو ارفض لإيقافها",
            "Operation: $safeToolName — approve to continue or deny to stop",
        )
        val approveLabel = localized("موافقة", "Approve")
        val denyLabel = localized("رفض", "Deny")
        val open = PendingIntent.getActivity(
            context,
            notificationId + 3,
            openIntent(conversationId),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, APPROVAL_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_background_generation)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(open)
            .addAction(R.drawable.ic_background_generation, denyLabel, actionIntent(false, 1))
            .addAction(R.drawable.ic_background_generation, approveLabel, actionIntent(true, 2))
            .build()
        manager.notify(notificationId, notification)
        return true
    }

    private fun dismissApprovalNotification(args: Map<*, *>) {
        val toolCallId = (args["toolCallId"] as? String)?.trim().orEmpty()
        val conversationId = (args["conversationId"] as? String)?.trim().orEmpty()
        if (toolCallId.isEmpty()) return
        context.getSystemService(NotificationManager::class.java)?.cancel(
            approvalNotificationId(conversationId, toolCallId),
        )
    }

    fun receiveApprovalAction(intent: Intent) {
        if (intent.action != APPROVAL_ACTION) return
        val toolCallId = intent.getStringExtra(APPROVAL_ID_EXTRA)?.trim().orEmpty()
        val conversationId = intent.getStringExtra(APPROVAL_CONVERSATION_EXTRA)?.trim().orEmpty()
        if (toolCallId.isEmpty()) return
        dismissApprovalNotification(mapOf("toolCallId" to toolCallId, "conversationId" to conversationId))
        approvalChannel?.invokeMethod(
            "approvalAction",
            mapOf(
                "toolCallId" to toolCallId,
                "conversationId" to conversationId,
                "approved" to intent.getBooleanExtra(APPROVAL_ALLOWED_EXTRA, false),
            ),
        )
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            context.getSystemService(NotificationManager::class.java)?.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, label("tasks", "Tasks"), NotificationManager.IMPORTANCE_LOW).apply {
                    setShowBadge(false)
                    setSound(null, null)
                })
        }
    }

    fun isPromoted(): Boolean {
        if (Build.VERSION.SDK_INT < 36 || service == null) return false
        return context.getSystemService(NotificationManager::class.java)?.activeNotifications?.any {
            it.id == NOTIFICATION_ID && it.notification.flags and Notification.FLAG_PROMOTED_ONGOING != 0
        } == true
    }

    private fun canPromote() = Build.VERSION.SDK_INT >= 36 &&
        context.getSystemService(NotificationManager::class.java)?.canPostPromotedNotifications() == true

    fun status(): Map<String, Any> {
        val manager = context.getSystemService(NotificationManager::class.java)
        fun channelEnabled(id: String) = Build.VERSION.SDK_INT < 26 ||
            manager?.getNotificationChannel(id)?.importance != NotificationManager.IMPORTANCE_NONE
        return mapOf(
            "foregroundServiceActive" to (service != null && shouldRunService()),
            "serviceRestartPending" to prefs.getBoolean("service_restart_pending", false),
            "activeTasks" to tasks.size,
            "notificationsAuthorized" to NotificationManagerCompat.from(context).areNotificationsEnabled(),
            "ongoingChannelEnabled" to channelEnabled(CHANNEL_ID),
            "completionChannelEnabled" to channelEnabled("kelivo_bg_chat_v2"),
            "approvalChannelEnabled" to channelEnabled(APPROVAL_CHANNEL_ID),
            "batteryExempt" to context.getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(context.packageName),
            "overlayAuthorized" to Settings.canDrawOverlays(context),
            "overlayVisible" to overlay.isVisible,
            "liveUpdatesSupported" to (Build.VERSION.SDK_INT >= 36),
            "liveUpdatesAuthorized" to canPromote(),
            "liveUpdatePromoted" to isPromoted(),
            "manufacturer" to Build.MANUFACTURER,
            "lastError" to (prefs.getString("last_error", "") ?: ""),
        )
    }

    fun serviceFailed(message: String) {
        blocked = true
        serviceStarting = false
        recordError(message)
        (context as? KelivoApplication)?.scheduledTasks?.stopAll(message)
        channel?.invokeMethod("statusChanged", null)
    }

    fun recordError(message: String) {
        prefs.edit().putString("last_error", message).apply()
        android.util.Log.w("KelivoBackground", message)
    }

    fun requestPermission(permission: String) {
        val host = activity.get() ?: throw IllegalStateException("foreground_activity_required")
        when (permission) {
            "notifications" -> if (Build.VERSION.SDK_INT >= 33 &&
                ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(host, arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_PERMISSION_REQUEST)
            } else openSettings("notifications")
            "battery" -> openSettings("battery")
            "overlay" -> openSettings("overlay")
        }
    }

    fun permissionResult(requestCode: Int): Boolean {
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST) return false
        channel?.invokeMethod("statusChanged", null)
        return true
    }

    fun openSettings(destination: String) {
        val host = activity.get() ?: throw IllegalStateException("foreground_activity_required")
        val packageUri = Uri.parse("package:${context.packageName}")
        val intents = mutableListOf<Intent>()
        when (destination) {
            "notifications" -> if (Build.VERSION.SDK_INT >= 26) intents +=
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            "channels", "ongoingChannel" -> if (Build.VERSION.SDK_INT >= 26) {
                ensureChannel()
                intents += Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                    .putExtra(Settings.EXTRA_CHANNEL_ID,
                        if (destination == "ongoingChannel") CHANNEL_ID else "kelivo_bg_chat_v2")
            }
            "battery" -> {
                intents += Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, packageUri)
                intents += Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            }
            "overlay" -> intents += Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, packageUri)
            "liveUpdates" -> if (Build.VERSION.SDK_INT >= 36) intents +=
                Intent("android.settings.MANAGE_APP_PROMOTED_NOTIFICATIONS").putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            "autostart" -> intents += vendorSettings().map { (pkg, name) -> Intent().setComponent(ComponentName(pkg, name)) }
        }
        intents += Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri)
        for (intent in intents) {
            try { host.startActivity(intent); return }
            catch (_: android.content.ActivityNotFoundException) { /* try next device setting */ }
            catch (_: SecurityException) { /* some OEM activities are not exported */ }
        }
        throw IllegalStateException("settings_unavailable")
    }

    private fun vendorSettings(): List<Pair<String, String>> {
        val vendor = "${Build.MANUFACTURER} ${Build.BRAND}".lowercase()
        return when {
            "xiaomi" in vendor || "redmi" in vendor -> listOf("com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity")
            "huawei" in vendor || "honor" in vendor -> listOf("com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")
            "oppo" in vendor || "oneplus" in vendor || "realme" in vendor -> listOf(
                "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
                "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity")
            "vivo" in vendor || "iqoo" in vendor -> listOf("com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")
            "samsung" in vendor -> listOf("com.samsung.android.lool" to "com.samsung.android.sm.battery.ui.BatteryActivity")
            else -> emptyList()
        }
    }

    private fun clearCompletionNotifications() {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        for (entry in manager.activeNotifications) {
            if (Build.VERSION.SDK_INT >= 26 && entry.notification.channelId == "kelivo_bg_chat_v2") {
                manager.cancel(entry.tag, entry.id)
            }
        }
    }
}

package com.psyche.kelivo.workspace

import java.io.File

/** Best-effort wrappers for common PRoot write commands. Not a sandbox. */
internal object MountWriteGuards {
    private const val MARKER = "# kelivo-mount-readonly-guard"
    private const val CONFIG = "/run/kelivo/mount-readonly-prefixes"
    private const val RUN_CONFIGS = "/run/kelivo/mount-readonly-prefixes-per-run"
    private val commands = listOf("touch", "tee", "cp", "mv", "mkdir", "rm", "rmdir", "ln", "dd")

    data class RunGuardConfig(val file: File, val guestPath: String)

    /**
     * Prepare an immutable-per-run path list so concurrent commands do not
     * overwrite one another's read-only prefixes. The wrappers are still
     * best-effort and are not a kernel access-control mechanism.
     */
    @Synchronized
    fun prepareForRun(rootfs: File, runId: String, mounts: List<BindMount>): RunGuardConfig? {
        val prefixes = mounts.filter { it.readOnly }.map { it.guest }
        if (prefixes.isEmpty()) return null
        require(runId.matches(Regex("[A-Za-z0-9._-]{1,100}"))) { "invalid run id" }
        require(prefixes.all { it.startsWith("/") && !it.contains('\n') && !it.contains('\r') && !it.contains('\u0000') }) {
            "invalid read-only guest path"
        }
        val canonicalRoot = rootfs.canonicalFile
        val base = File(canonicalRoot, RUN_CONFIGS.removePrefix("/"))
        val canonicalBase = base.canonicalFile
        require(canonicalBase.path.startsWith(canonicalRoot.path + File.separator)) {
            "read-only guard directory escapes RootFS"
        }
        base.mkdirs()
        val config = File(base, "run-$runId")
        require(config.canonicalFile.parentFile == canonicalBase) { "invalid read-only guard path" }
        require(!config.exists()) { "duplicate read-only guard run id" }
        try {
            config.writeText(prefixes.distinct().joinToString("\n", postfix = "\n"))
            ensureWrappers(rootfs)
        } catch (error: Exception) {
            releaseForRun(rootfs, config)
            throw error
        }
        return RunGuardConfig(config, "$RUN_CONFIGS/run-$runId")
    }

    @Synchronized
    fun install(rootfs: File, mounts: List<BindMount>) {
        val prefixes = mounts.filter { it.readOnly }.map { it.guest }
        val config = File(rootfs, CONFIG.removePrefix("/"))
        val bin = File(rootfs, "usr/local/bin").canonicalFile
        if (prefixes.isEmpty()) {
            val activeRunConfigs = File(rootfs, RUN_CONFIGS.removePrefix("/"))
                .listFiles()
                .orEmpty()
                .any { it.isFile && it.name.startsWith("run-") }
            // Do not remove shared wrappers while an execution is still using
            // its private guard file.
            if (activeRunConfigs) return
            removeOwnedWrappers(bin)
            config.delete()
            return
        }
        config.parentFile!!.mkdirs()
        config.writeText(prefixes.joinToString("\n", postfix = "\n"))
        ensureWrappers(rootfs)
    }

    /** Remove one run's config and retire shared wrappers when the last run ends. */
    @Synchronized
    fun releaseForRun(rootfs: File, configFile: File?) {
        if (configFile == null) return
        val canonicalRoot = rootfs.canonicalFile
        val base = File(canonicalRoot, RUN_CONFIGS.removePrefix("/"))
        val canonicalBase = base.canonicalFile
        // Guest code runs with the app UID and can tamper with the shared
        // RootFS. Never follow a replaced symlink while cleaning up a guard.
        if (canonicalBase != base.absoluteFile ||
            !canonicalBase.path.startsWith(canonicalRoot.path + File.separator)) return
        if (!configFile.name.matches(Regex("run-[A-Za-z0-9._-]{1,100}"))) return
        if (configFile.absoluteFile.parentFile != base.absoluteFile ||
            configFile.parentFile?.canonicalFile != canonicalBase) return
        // File.delete() removes a guest-replaced symlink itself; do not resolve
        // the final path and risk following it outside the per-run directory.
        configFile.delete()
        val activeRunConfigs = base.listFiles()
            .orEmpty()
            .any { it.isFile && it.name.startsWith("run-") }
        val legacyConfig = File(canonicalRoot, CONFIG.removePrefix("/"))
        if (!activeRunConfigs && !legacyConfig.isFile) {
            removeOwnedWrappers(File(canonicalRoot, "usr/local/bin"))
            if (base.isDirectory && base.listFiles().isNullOrEmpty()) base.delete()
        }
    }

    private fun removeOwnedWrappers(bin: File) {
        for (name in commands) {
            val wrapper = File(bin, name)
            if (isOurWrapper(wrapper)) wrapper.delete()
        }
    }

    private fun ensureWrappers(rootfs: File) {
        val bin = File(rootfs, "usr/local/bin").canonicalFile
        require(bin.path.startsWith(rootfs.canonicalPath + File.separator)) {
            "write-guard command directory escapes RootFS"
        }
        bin.mkdirs()
        for (name in commands) {
            val wrapper = File(bin, name)
            // Do not replace user-installed commands or symlinks.
            if (wrapper.canonicalFile != wrapper.absoluteFile) continue
            if (wrapper.exists() && !isOurWrapper(wrapper)) continue
            val script = commandScript(name)
            if (!wrapper.exists() || wrapper.readText() != script) wrapper.writeText(script)
            check(wrapper.setExecutable(true, false)) { "Cannot install mount write guard" }
        }
    }

    private fun isOurWrapper(file: File): Boolean {
        if (!file.isFile || file.canonicalFile != file.absoluteFile) return false
        return file.inputStream().use { input ->
            val prefix = ByteArray(80)
            val size = input.read(prefix)
            size > 0 && String(prefix, 0, size, Charsets.UTF_8).startsWith("#!/bin/sh\n$MARKER\n")
        }
    }

    internal fun commandScript(name: String, config: String = CONFIG): String {
        require(name in commands)
        val quotedConfig = "'" + config.replace("'", "'\"'\"'") + "'"
        return """#!/bin/sh
            |$MARKER
            |cfg=${'$'}{KELIVO_READONLY_MOUNTS_FILE:-$quotedConfig}
            |check_target() {
            |    [ -f "${'$'}cfg" ] || return 0
            |    # GNU realpath supports missing parents; BusyBox readlink handles
            |    # existing symlink parents without requiring coreutils on Alpine.
            |    resolved=${'$'}(PATH=/usr/bin:/bin realpath -m -- "${'$'}1" 2>/dev/null) ||
            |        resolved=${'$'}(PATH=/usr/bin:/bin readlink -f -- "${'$'}1" 2>/dev/null) || resolved="${'$'}1"
            |    case "${'$'}resolved" in /*) ;; *) resolved="${'$'}PWD/${'$'}resolved";; esac
            |    while IFS= read -r prefix; do
            |        [ -n "${'$'}prefix" ] || continue
            |        case "${'$'}resolved" in
            |            "${'$'}prefix"|"${'$'}prefix"/*)
            |                printf '%s\n' "$name: ${'$'}1: read-only mounted folder; enable writes in Environment settings" >&2
            |                exit 1;;
            |        esac
            |    done < "${'$'}cfg"
            |}
            |# Match Minis' common-command coverage. Redirection, interpreters,
            |# absolute executable paths and other programs can bypass wrappers.
            |for arg do
            |    case "${'$'}arg" in
            |        -*) continue;;
            |    esac
            |    if [ "$name" = dd ]; then
            |        case "${'$'}arg" in of=*) check_target "${'$'}{arg#of=}";; esac
            |    else
            |        check_target "${'$'}arg"
            |    fi
            |done
            |PATH=/usr/bin:/bin exec $name "${'$'}@"
            |""".trimMargin()
    }
}

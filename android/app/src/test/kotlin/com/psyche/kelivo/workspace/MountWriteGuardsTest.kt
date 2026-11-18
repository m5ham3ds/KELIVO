package com.psyche.kelivo.workspace

import java.io.File
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class MountWriteGuardsTest {
    @get:Rule val temporary = TemporaryFolder()

    private fun run(script: File, vararg args: String): Pair<Int, String> {
        val process = ProcessBuilder(listOf("/bin/sh", script.path) + args)
            .redirectErrorStream(true).start()
        process.outputStream.close()
        assertTrue(process.waitFor(10, TimeUnit.SECONDS))
        return process.exitValue() to process.inputStream.bufferedReader().readText()
    }

    @Test fun commonCommandsRejectReadonlyPathsAndWritableCommandsStillRun() {
        val locked = temporary.newFolder("My Notes").canonicalFile
        val writable = temporary.newFolder("writable").canonicalFile
        val original = File(locked, "original").apply { writeText("hello") }
        val config = temporary.newFile("prefixes").apply { writeText(locked.path + "\n") }
        val cases = mapOf(
            "touch" to listOf(original.path),
            "tee" to listOf(original.path),
            "cp" to listOf(original.path, File(writable, "copy").path),
            "mv" to listOf(original.path, File(writable, "moved").path),
            "mkdir" to listOf(File(locked, "new").path),
            "rm" to listOf(original.path),
            "rmdir" to listOf(locked.path),
            "ln" to listOf(original.path, File(writable, "link").path),
            "dd" to listOf("if=/dev/null", "of=${original.path}"),
        )
        for ((name, args) in cases) {
            val script = temporary.newFile(name).apply {
                writeText(MountWriteGuards.commandScript(name, config.path))
            }
            val (code, output) = run(script, *args.toTypedArray())
            assertEquals("$name: $output", 1, code)
            assertTrue(output, output.contains("read-only mounted folder"))
        }
        assertEquals("hello", original.readText())
        val outputFile = File(writable, "new")
        assertEquals(0, run(File(temporary.root, "touch"), outputFile.path).first)
        assertTrue(outputFile.exists())
        // dd's input may be readonly; only of= is a write target.
        val copy = File(writable, "dd-copy")
        assertEquals(0, run(File(temporary.root, "dd"), "if=${original.path}", "of=${copy.path}").first)
        assertEquals("hello", copy.readText())
    }

    @Test fun multipleRequestScopedReadonlyBindsAreGuardedTogether() {
        val rootfs = temporary.newFolder("multi-rootfs")
        val source = temporary.newFolder("skill-source")
        val input = temporary.newFolder("skill-input")
        MountWriteGuards.install(
            rootfs,
            listOf(
                BindMount(source.path, "/run/kelivo-skill/source", true),
                BindMount(input.path, "/run/kelivo-skill/io/input", true),
                BindMount("/tmp/out", "/run/kelivo-skill/io/output", false),
            ),
        )
        assertEquals(
            "/run/kelivo-skill/source\n/run/kelivo-skill/io/input\n",
            File(rootfs, "run/kelivo/mount-readonly-prefixes").readText(),
        )
        assertTrue(File(rootfs, "usr/local/bin/touch").canExecute())
        MountWriteGuards.install(rootfs, emptyList())
    }

    @Test fun runScopedConfigsDoNotOverwriteConcurrentSkillGuards() {
        val rootfs = temporary.newFolder("run-scoped-rootfs")
        val source = temporary.newFolder("run-source")
        val input = temporary.newFolder("run-input")
        val first = MountWriteGuards.prepareForRun(
            rootfs,
            "skill-run-0001",
            listOf(BindMount(source.path, "/run/kelivo-skill/source", true)),
        )!!
        val second = MountWriteGuards.prepareForRun(
            rootfs,
            "skill-run-0002",
            listOf(BindMount(input.path, "/run/kelivo-skill/io/input", true)),
        )!!

        assertNotEquals(first.file, second.file)
        assertEquals("/run/kelivo-skill/source\n", first.file.readText())
        assertEquals("/run/kelivo-skill/io/input\n", second.file.readText())
        assertEquals(
            "/run/kelivo/mount-readonly-prefixes-per-run/run-skill-run-0001",
            first.guestPath,
        )
        val touchGuard = File(rootfs, "usr/local/bin/touch")
        assertTrue(touchGuard.canExecute())
        MountWriteGuards.install(rootfs, emptyList())
        assertTrue("guard wrappers remain while runs are active", touchGuard.exists())
        assertTrue(first.file.exists())
        assertTrue(second.file.exists())
        MountWriteGuards.releaseForRun(rootfs, first.file)
        assertTrue("shared wrappers remain for the second run", touchGuard.exists())
        MountWriteGuards.releaseForRun(rootfs, second.file)
        MountWriteGuards.install(rootfs, emptyList())
        assertFalse("guard wrappers are removed after the final run", touchGuard.exists())
    }

    @Test fun removalKeepsUserCommandsAndOnlyDeletesOwnedWrappers() {
        val rootfs = temporary.newFolder("rootfs")
        val bin = File(rootfs, "usr/local/bin").apply { mkdirs() }
        val userCommand = File(bin, "cp").apply { writeText("user command") }
        MountWriteGuards.install(rootfs, listOf(BindMount("/host/notes", "/mounts/Notes", true)))
        assertEquals("user command", userCommand.readText())
        assertTrue(File(bin, "touch").canExecute())
        assertEquals("/mounts/Notes\n", File(rootfs, "run/kelivo/mount-readonly-prefixes").readText())
        MountWriteGuards.install(rootfs, emptyList())
        assertEquals("user command", userCommand.readText())
        assertFalse(File(bin, "touch").exists())
        assertFalse(File(rootfs, "run/kelivo/mount-readonly-prefixes").exists())
    }
}

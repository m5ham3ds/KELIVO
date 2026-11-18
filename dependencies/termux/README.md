# Pinned Android ARM64 sandbox runtime

`proot-5.1.107.92.tar.xz` contains only the four ARM64 (`arm64-v8a`) runtime libraries required by this Android build, extracted from these Termux packages:

- PRoot 5.1.107.92
- libtalloc 2.4.3
- libandroid-shmem 0.7

The archive is kept in the repository because Termux's rolling package pool removes old versions. Android builds restore it with `tool/fetch_proot.sh`, which verifies every included file against `tool/proot_checksums.txt` before installing any library. ARMv7 and x86_64 binaries are intentionally excluded because the project builds ARM64 APKs only.

Source references and license notices are in [`android/app/src/main/jniLibs/NOTICE`](../../android/app/src/main/jniLibs/NOTICE).

When updating the runtime, extract the ARM64 package files, replace this archive, and update the checksums and NOTICE together. The archive contains regular files named `arm64-v8a/<library>.so`.

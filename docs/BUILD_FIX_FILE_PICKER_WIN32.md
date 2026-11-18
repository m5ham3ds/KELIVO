# Android build fix: file_picker / win32 dependency conflict

The Android ARM64 build previously stopped at `flutter pub get`, before Dart tests
or Gradle compilation. Pub reported incompatible Windows-only transitive constraints:

- `file_picker 10.3.10` required `win32 ^5.9.0`.
- `share_plus 13.3.1` requires the Win32 6.x line.
- `flutter_secure_storage_windows 4.2.2` also requires Win32 6.x.

The application now pins the compatible major line with `file_picker: ^12.3.0`.
The v12 migration changed `pickFiles()` to return a list, replaced eager byte
properties with `readAsBytes()`, removed `PlatformFile.size`, and made `saveFile`
require a filename and bytes. The local `file_picker_compat.dart` facade keeps
KELIVO's existing injectable `FilePicker.platform` call sites and test doubles
stable while adapting those upstream APIs. Picked content is read lazily to avoid
buffering large files unnecessarily.

The focused CI continues to run only the Arabic RTL widget test and the Arabic
locale persistence test before the ARM64 Release build. It does not run the old
broad Phase regression suites, full-repository analyzer, or format sweep.

`pubspec.lock` is refreshed by `flutter pub get` in CI. This workspace does not
contain Flutter/Dart SDK, so the dependency solver, Dart compiler, Flutter tests,
and APK build must be confirmed by the next GitHub Actions run.

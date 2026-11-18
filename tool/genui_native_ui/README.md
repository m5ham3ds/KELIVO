# Android WebView acceptance

These are manual integration checks for the Android WebView path. They are separate from ordinary unit tests and do not require the production app's database or credentials.

Run on an unlocked Android test device with the same pinned Flutter SDK:

```sh
flutter drive --no-pub --driver=test_driver/integration_test.dart \
  --target=integration_test/genui_web_sandbox_test.dart -d DEVICE
```

The test exercises the real Android WebView path and verifies that a controlled local-file canary, HTTP/TLS listeners and native navigation decisions behave as expected. Gesture cases may require an actual Android tap through `adb shell input tap` when Flutter pointer injection cannot reach the embedded native view. Keep the device awake during the run and restore its previous state afterwards.

The checks are scoped to Android. They do not claim validation of iOS, Windows, Linux desktop or macOS.

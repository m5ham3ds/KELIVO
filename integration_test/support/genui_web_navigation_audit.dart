import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// Records the real Android WebView navigation callback decision in integration tests.
/// It does not alter, allow, or block any request itself.
class GenUiAuditedAndroid extends AndroidWebViewPlatform {
  GenUiAuditedAndroid(this.events);

  final List<Map<String, Object?>> events;

  @override
  AndroidNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _AndroidDelegate(params, events);
}

class _AndroidDelegate extends AndroidNavigationDelegate {
  _AndroidDelegate(super.params, this.events);

  final List<Map<String, Object?>> events;

  @override
  Future<void> setOnNavigationRequest(NavigationRequestCallback callback) =>
      super.setOnNavigationRequest((request) async {
        final decision = await callback(request);
        events.add({
          'url': request.url,
          'main': request.isMainFrame,
          'decision': decision.name,
        });
        return decision;
      });
}

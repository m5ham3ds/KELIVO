import 'package:flutter_test/flutter_test.dart';
import 'package:super_clipboard/super_clipboard.dart' show ClipboardWriter;

void main() {
  test('super_clipboard Linux host native-assets dependency compiles', () {
    // Merely resolving this public type forces the test target to compile
    // against super_clipboard/super_native_extensions. The Flutter test build
    // therefore exercises the package's Linux native-asset hook before any
    // Phase 13 suite starts, without accessing the system clipboard or opening
    // a GUI/display connection.
    expect(ClipboardWriter, isA<Type>());
  });
}

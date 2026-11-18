/// Android-only HTTP transport selection.
library;

export 'http_client_stub.dart'
    if (dart.library.io) 'http_client_io.dart';

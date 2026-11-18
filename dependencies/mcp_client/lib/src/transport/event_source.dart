library;

export 'sse_parser.dart';

/// Android-only transport selection.
export 'event_source_stub.dart'
    if (dart.library.io) 'event_source_io.dart';

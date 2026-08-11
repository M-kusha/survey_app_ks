/// Hands a generated calendar file to the platform.
///
/// Only the web implementation exists. The `printing` package cannot be reused
/// here because it hardcodes `application/pdf` on its download Blob, and a
/// calendar file served with that type is offered to the wrong applications.
/// A correct Android path needs a share/file-write dependency the project does
/// not carry, so `calendarDownloadSupported` gates the control instead of
/// shipping a button that fails.
library;

export 'calendar_download_stub.dart'
    if (dart.library.js_interop) 'calendar_download_web.dart';

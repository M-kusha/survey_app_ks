/// Hands a generated calendar file to the platform.
///
/// Web writes a `text/calendar` Blob and clicks an anchor; everywhere else the
/// file goes to the system share sheet. The `printing` package cannot carry
/// either path because it hardcodes `application/pdf` on its payload, and a
/// calendar file declared as a PDF is offered to the wrong applications.
library;

export 'calendar_download_io.dart'
    if (dart.library.js_interop) 'calendar_download_web.dart';

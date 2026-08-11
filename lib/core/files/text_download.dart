/// Hands a generated text file to the platform.
///
/// Web writes a Blob and clicks an anchor; everywhere else the file goes to the
/// system share sheet. The `printing` package cannot carry either path because
/// it hardcodes `application/pdf` on its payload, and a calendar or data file
/// declared as a PDF is offered to the wrong applications.
///
/// The MIME type is a parameter rather than a constant because it is the part
/// the operating system acts on: `text/calendar` gets a calendar app,
/// `application/json` gets a text editor, and a wrong one gets neither.
library;

export 'text_download_io.dart'
    if (dart.library.js_interop) 'text_download_web.dart';

/// Platforms without a calendar handoff. See [calendarDownloadSupported].
const calendarDownloadSupported = false;

Future<void> downloadCalendarFile({
  required String contents,
  required String fileName,
}) async {
  throw UnsupportedError('Calendar export is unavailable on this platform.');
}

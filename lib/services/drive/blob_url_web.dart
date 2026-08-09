import 'dart:html' as html;
import 'dart:typed_data';

/// Creates a browser object URL (`blob:...`) for [bytes] — used as the
/// "local reference" for downloaded Drive media on web, since there's no
/// real filesystem to cache to. `Image.network`/audioplayers' `UrlSource`
/// both resolve blob: URLs directly.
String createBlobUrl(Uint8List bytes, String mimeType) {
  final blob = html.Blob([bytes], mimeType);
  return html.Url.createObjectUrlFromBlob(blob);
}

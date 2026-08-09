import 'dart:typed_data';

/// Never actually called — guarded by `kIsWeb` at call sites. Exists so the
/// conditional export in blob_url.dart always has a native-platform target.
String createBlobUrl(Uint8List bytes, String mimeType) {
  throw UnsupportedError('createBlobUrl is only available on web.');
}

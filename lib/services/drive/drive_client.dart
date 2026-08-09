import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';

/// Thrown when the user's Google Drive doesn't have enough free space left
/// to safely store new media.
class DriveStorageFullException implements Exception {
  final String message;
  const DriveStorageFullException([
    this.message =
        'Your Google Drive is full. Free up space to keep saving photos and voice notes.',
  ]);

  @override
  String toString() => message;
}

const _folderMimeType = 'application/vnd.google-apps.folder';
const _appFolderName = 'IdeaVault';
const _ideaMimeType = 'application/json';
const _minFreeBytes = 5 * 1024 * 1024; // 5MB safety margin

/// Thin wrapper around the Drive v3 API scoped to a single per-app folder
/// ("IdeaVault") in the signed-in user's own Drive. Every idea (title/notes/
/// cached AI results) is a JSON file in that folder; photos and voice notes
/// are separate binary files in the same folder.
class DriveClient {
  final GoogleSignIn _googleSignIn;
  drive.DriveApi? _api;
  String? _folderId;

  DriveClient(this._googleSignIn);

  Future<drive.DriveApi> _driveApi() async {
    final cached = _api;
    if (cached != null) return cached;
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) {
      throw StateError('Not signed in to Google.');
    }
    final api = drive.DriveApi(client);
    _api = api;
    return api;
  }

  Future<String> _folder() async {
    final cached = _folderId;
    if (cached != null) return cached;
    final api = await _driveApi();
    final existing = await api.files.list(
      q: "mimeType='$_folderMimeType' and name='$_appFolderName' and "
          "trashed=false and 'root' in parents",
      spaces: 'drive',
      $fields: 'files(id,name)',
    );
    final found = existing.files;
    if (found != null && found.isNotEmpty && found.first.id != null) {
      final id = found.first.id!;
      _folderId = id;
      return id;
    }
    final created = await api.files.create(
      drive.File()
        ..name = _appFolderName
        ..mimeType = _folderMimeType,
    );
    final id = created.id!;
    _folderId = id;
    return id;
  }

  /// Throws [DriveStorageFullException] if free space is below the safety
  /// margin. No-ops for accounts with unlimited storage (no `limit` field).
  Future<void> ensureQuota() async {
    final api = await _driveApi();
    final about = await api.about.get($fields: 'storageQuota');
    final limit = int.tryParse(about.storageQuota?.limit ?? '');
    final usage = int.tryParse(about.storageQuota?.usage ?? '');
    if (limit == null || usage == null) return;
    if (limit - usage < _minFreeBytes) {
      throw const DriveStorageFullException();
    }
  }

  Future<String> createJsonFile(
    String name,
    Map<String, dynamic> content,
  ) async {
    final api = await _driveApi();
    final folderId = await _folder();
    final bytes = utf8.encode(jsonEncode(content));
    final file = await api.files.create(
      drive.File()
        ..name = name
        ..mimeType = _ideaMimeType
        ..parents = [folderId],
      uploadMedia:
          drive.Media(Stream.value(bytes), bytes.length, contentType: _ideaMimeType),
    );
    return file.id!;
  }

  Future<void> updateJsonFile(String fileId, Map<String, dynamic> content) async {
    final api = await _driveApi();
    final bytes = utf8.encode(jsonEncode(content));
    await api.files.update(
      drive.File(),
      fileId,
      uploadMedia:
          drive.Media(Stream.value(bytes), bytes.length, contentType: _ideaMimeType),
    );
  }

  Future<Map<String, dynamic>> readJsonFile(String fileId) async {
    final bytes = await _downloadBytes(fileId);
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }

  /// All idea JSON files in the app folder, newest first.
  Future<List<drive.File>> listIdeaFiles() async {
    final api = await _driveApi();
    final folderId = await _folder();
    final res = await api.files.list(
      q: "'$folderId' in parents and mimeType='$_ideaMimeType' and trashed=false",
      spaces: 'drive',
      $fields: 'files(id,name,createdTime)',
      orderBy: 'createdTime desc',
      pageSize: 1000,
    );
    return res.files ?? const [];
  }

  Future<String> uploadBytes(
    String name,
    List<int> bytes,
    String contentType,
  ) async {
    await ensureQuota();
    final api = await _driveApi();
    final folderId = await _folder();
    final file = await api.files.create(
      drive.File()
        ..name = name
        ..mimeType = contentType
        ..parents = [folderId],
      uploadMedia: drive.Media(Stream.value(bytes), bytes.length, contentType: contentType),
    );
    return file.id!;
  }

  /// Downloads [fileId] to a local cache file (skipping the download if it's
  /// already cached) and returns that local [File].
  Future<File> downloadToCache(String fileId, String cacheFileName) async {
    final dir = await getApplicationCacheDirectory();
    final cacheDir = Directory('${dir.path}/drive_media');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    final localFile = File('${cacheDir.path}/$cacheFileName');
    if (await localFile.exists()) return localFile;
    final bytes = await _downloadBytes(fileId);
    await localFile.writeAsBytes(bytes);
    return localFile;
  }

  Future<Uint8List> _downloadBytes(String fileId) async {
    final api = await _driveApi();
    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    final builder = BytesBuilder(copy: false);
    await for (final chunk in media.stream) {
      builder.add(chunk);
    }
    return builder.toBytes();
  }

  Future<void> deleteFile(String fileId) async {
    final api = await _driveApi();
    try {
      await api.files.delete(fileId);
    } catch (_) {
      // Already gone / no permission — nothing more we can do.
    }
  }

  /// Deletes every file in the IdeaVault folder, then the folder itself.
  /// Used by account deletion.
  Future<void> deleteAppFolder() async {
    final api = await _driveApi();
    final folderId = await _folder();
    final res = await api.files.list(
      q: "'$folderId' in parents and trashed=false",
      spaces: 'drive',
      $fields: 'files(id)',
      pageSize: 1000,
    );
    for (final f in res.files ?? const <drive.File>[]) {
      final id = f.id;
      if (id != null) await deleteFile(id);
    }
    await deleteFile(folderId);
    _folderId = null;
  }

  void reset() {
    _api = null;
    _folderId = null;
  }
}

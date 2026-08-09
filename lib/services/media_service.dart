import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/idea.dart';
import 'drive/drive_client.dart';

class IdeaMediaPaths {
  final String? imagePath;
  final String? audioPath;
  const IdeaMediaPaths({this.imagePath, this.audioPath});
}

abstract class MediaService {
  Future<String> tempAudioPath(String ideaId);
  Future<IdeaMediaPaths> uploadIdeaMedia({
    required String ideaId,
    String? localImagePath,
    String? localAudioPath,
  });
  Future<void> resolveMediaUrls(Idea idea);
  Future<void> deleteIdeaMedia(Idea idea);
}

class SupabaseMediaService implements MediaService {
  final SupabaseClient _client;
  static const _bucket = 'idea-media';

  SupabaseMediaService(this._client);

  String get _userId => _client.auth.currentUser?.id ?? '';

  String _imagePath(String ideaId) => '$_userId/images/$ideaId.jpg';
  String _audioPath(String ideaId) => '$_userId/audio/$ideaId.m4a';

  @override
  Future<String> tempAudioPath(String ideaId) async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/idea_vault/$ideaId.m4a';
  }

  @override
  Future<IdeaMediaPaths> uploadIdeaMedia({
    required String ideaId,
    String? localImagePath,
    String? localAudioPath,
  }) async {
    if (localImagePath != null) {
      final bytes = await File(localImagePath).readAsBytes();
      await _client.storage.from(_bucket).uploadBinary(
            _imagePath(ideaId),
            bytes,
            fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
    }
    if (localAudioPath != null) {
      final bytes = await File(localAudioPath).readAsBytes();
      await _client.storage.from(_bucket).uploadBinary(
            _audioPath(ideaId),
            bytes,
            fileOptions: const FileOptions(upsert: true, contentType: 'audio/mp4'),
          );
    }
    return IdeaMediaPaths(
      imagePath: localImagePath != null ? _imagePath(ideaId) : null,
      audioPath: localAudioPath != null ? _audioPath(ideaId) : null,
    );
  }

  @override
  Future<void> resolveMediaUrls(Idea idea) async {
    if (idea.imagePath != null) {
      idea.imageUrl = await _client.storage
          .from(_bucket)
          .createSignedUrl(idea.imagePath!, 3600);
    }
    if (idea.audioPath != null) {
      idea.audioUrl = await _client.storage
          .from(_bucket)
          .createSignedUrl(idea.audioPath!, 3600);
    }
  }

  @override
  Future<void> deleteIdeaMedia(Idea idea) async {
    final paths = [
      if (idea.imagePath != null) idea.imagePath!,
      if (idea.audioPath != null) idea.audioPath!,
    ];
    if (paths.isNotEmpty) {
      await _client.storage.from(_bucket).remove(paths);
    }
  }
}

/// Photos/voice notes stored as files in the user's own Google Drive
/// (`Idea.imagePath`/`audioPath` hold Drive file IDs, not storage paths).
/// Display goes through a local cache — Drive has no equivalent of a
/// short-lived signed URL for private files, so [resolveMediaUrls] downloads
/// once and points `imageUrl`/`audioUrl` at the local cached file path
/// instead of a network URL.
class DriveMediaService implements MediaService {
  final DriveClient _drive;

  DriveMediaService(this._drive);

  @override
  Future<String> tempAudioPath(String ideaId) async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/idea_vault/$ideaId.m4a';
  }

  @override
  Future<IdeaMediaPaths> uploadIdeaMedia({
    required String ideaId,
    String? localImagePath,
    String? localAudioPath,
  }) async {
    String? imageFileId;
    String? audioFileId;
    if (localImagePath != null) {
      final bytes = await File(localImagePath).readAsBytes();
      imageFileId =
          await _drive.uploadBytes('idea-$ideaId-image.jpg', bytes, 'image/jpeg');
    }
    if (localAudioPath != null) {
      final bytes = await File(localAudioPath).readAsBytes();
      audioFileId =
          await _drive.uploadBytes('idea-$ideaId-audio.m4a', bytes, 'audio/mp4');
    }
    return IdeaMediaPaths(imagePath: imageFileId, audioPath: audioFileId);
  }

  @override
  Future<void> resolveMediaUrls(Idea idea) async {
    final imageId = idea.imagePath;
    if (imageId != null) {
      final file = await _drive.downloadToCache(imageId, '$imageId.jpg');
      idea.imageUrl = file.path;
    }
    final audioId = idea.audioPath;
    if (audioId != null) {
      final file = await _drive.downloadToCache(audioId, '$audioId.m4a');
      idea.audioUrl = file.path;
    }
  }

  @override
  Future<void> deleteIdeaMedia(Idea idea) async {
    if (idea.imagePath != null) await _drive.deleteFile(idea.imagePath!);
    if (idea.audioPath != null) await _drive.deleteFile(idea.audioPath!);
  }
}

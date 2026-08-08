import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/idea.dart';

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
  Future<void> deleteIdeaMedia(String ideaId);
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
  Future<void> deleteIdeaMedia(String ideaId) async {
    final paths = [
      if (await _exists(_imagePath(ideaId))) _imagePath(ideaId),
      if (await _exists(_audioPath(ideaId))) _audioPath(ideaId),
    ];
    if (paths.isNotEmpty) {
      await _client.storage.from(_bucket).remove(paths);
    }
  }

  Future<bool> _exists(String path) async {
    try {
      final res = await _client.storage
          .from(_bucket)
          .list(path: path.substring(0, path.lastIndexOf('/')));
      return res.any((f) => f.name == path.substring(path.lastIndexOf('/') + 1));
    } catch (_) {
      return false;
    }
  }
}

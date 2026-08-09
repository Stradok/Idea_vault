import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/idea.dart';
import 'drive/drive_client.dart';

abstract class IdeaStore {
  Future<List<Idea>> loadIdeas(String userId);
  Future<Idea> insertIdea(Idea idea);
  Future<void> updateIdea(Idea idea);
  Future<void> deleteIdea(String ideaId);
}

/// Lets services (research, affiliate matching) cache AI results inside the
/// idea's own Drive file instead of a separate database table.
abstract class IdeaCache {
  Future<Object?> readCache(String ideaId, String key);
  Future<void> writeCache(String ideaId, String key, Object? value);
}

class SupabaseIdeaStore implements IdeaStore {
  final SupabaseClient _client;

  SupabaseIdeaStore(this._client);

  @override
  Future<List<Idea>> loadIdeas(String userId) async {
    final res = await _client
        .from('ideas')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return res.map(Idea.fromMap).toList();
  }

  @override
  Future<Idea> insertIdea(Idea idea) async {
    final row = idea.toMap()
      ..['user_id'] = _currentUserId();
    final res = await _client
        .from('ideas')
        .insert(row)
        .select()
        .single();
    return Idea.fromMap(res);
  }

  @override
  Future<void> updateIdea(Idea idea) async {
    final row = idea.toMap()
      ..remove('user_id')
      ..remove('id')
      ..remove('created_at');
    await _client.from('ideas').update(row).eq('id', idea.id);
  }

  @override
  Future<void> deleteIdea(String ideaId) async {
    await _client.from('ideas').delete().eq('id', ideaId);
    await _client.from('research_reports').delete().eq('idea_id', ideaId);
  }

  String _currentUserId() {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Not authenticated');
    return user.id;
  }
}

/// Idea storage backed by JSON files in the user's own Google Drive (one
/// file per idea, named `idea-<id>.json`), instead of a shared database.
/// Extra JSON keys not modeled by [Idea] (e.g. `research`, `affiliates`) are
/// preserved across updates so [IdeaCache] reads/writes survive idea edits.
class DriveIdeaStore implements IdeaStore, IdeaCache {
  final DriveClient _drive;
  final Map<String, String> _fileIdByIdeaId = {};

  DriveIdeaStore(this._drive);

  String _fileName(String ideaId) => 'idea-$ideaId.json';

  @override
  Future<List<Idea>> loadIdeas(String userId) async {
    final files = await _drive.listIdeaFiles();
    final ideas = <Idea>[];
    for (final file in files) {
      final fileId = file.id;
      if (fileId == null) continue;
      try {
        final content = await _drive.readJsonFile(fileId);
        final idea = Idea.fromMap(content);
        _fileIdByIdeaId[idea.id] = fileId;
        ideas.add(idea);
      } catch (_) {
        // Skip an unreadable/corrupt file rather than failing the whole list.
      }
    }
    ideas.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return ideas;
  }

  @override
  Future<Idea> insertIdea(Idea idea) async {
    final fileId = await _drive.createJsonFile(_fileName(idea.id), idea.toMap());
    _fileIdByIdeaId[idea.id] = fileId;
    return idea;
  }

  @override
  Future<void> updateIdea(Idea idea) async {
    final fileId = await _fileIdFor(idea.id);
    final existing = await _drive.readJsonFile(fileId);
    final merged = {...existing, ...idea.toMap()};
    await _drive.updateJsonFile(fileId, merged);
  }

  @override
  Future<void> deleteIdea(String ideaId) async {
    final fileId = await _fileIdFor(ideaId);
    await _drive.deleteFile(fileId);
    _fileIdByIdeaId.remove(ideaId);
  }

  @override
  Future<Object?> readCache(String ideaId, String key) async {
    final fileId = await _fileIdFor(ideaId);
    final content = await _drive.readJsonFile(fileId);
    return content[key];
  }

  @override
  Future<void> writeCache(String ideaId, String key, Object? value) async {
    final fileId = await _fileIdFor(ideaId);
    final content = await _drive.readJsonFile(fileId);
    content[key] = value;
    await _drive.updateJsonFile(fileId, content);
  }

  Future<String> _fileIdFor(String ideaId) async {
    final cached = _fileIdByIdeaId[ideaId];
    if (cached != null) return cached;
    // Cold cache (e.g. a cache read before loadIdeas() ever ran) — rebuild it.
    await loadIdeas('');
    final found = _fileIdByIdeaId[ideaId];
    if (found == null) {
      throw StateError('Idea $ideaId not found in Drive.');
    }
    return found;
  }
}

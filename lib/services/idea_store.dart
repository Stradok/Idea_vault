import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/idea.dart';

abstract class IdeaStore {
  Future<List<Idea>> loadIdeas(String userId);
  Future<Idea> insertIdea(Idea idea);
  Future<void> updateIdea(Idea idea);
  Future<void> deleteIdea(String ideaId);
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

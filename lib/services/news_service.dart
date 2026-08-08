import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/news_item.dart';
import 'idea_category.dart';

abstract class NewsService {
  Future<List<NewsItem>> fetchFor(
    IdeaCategory category, {
    required String title,
    String? notes,
  });
}

class SupabaseNewsService implements NewsService {
  final SupabaseClient _client;

  SupabaseNewsService(this._client);

  @override
  Future<List<NewsItem>> fetchFor(
    IdeaCategory category, {
    required String title,
    String? notes,
  }) async {
    final res = await _client.functions.invoke(
      'news',
      body: {'title': title, 'notes': notes, 'limit': 8},
    );
    final data = (res.data as Map<String, dynamic>?) ?? {};
    final list = data['news'] as List<dynamic>? ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(NewsItem.fromJson)
        .where((n) => n.url.isNotEmpty)
        .toList();
  }
}

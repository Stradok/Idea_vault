import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/news_item.dart';
import 'ai_queue_service.dart';
import 'idea_category.dart';
import 'idea_store.dart';

abstract class NewsService {
  Future<List<NewsItem>> fetchFor(
    IdeaCategory category, {
    required String ideaId,
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
    required String ideaId,
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

/// Same multi-source News pipeline as [SupabaseNewsService], but caches the
/// result inside the idea's own Drive file (via [IdeaCache]) and goes
/// through [AiQueueService] so the shared Google Search free-tier quota is
/// spent one request at a time instead of however many users open the News
/// tab at once.
class DriveNewsService implements NewsService {
  final IdeaCache _cache;
  final AiQueueService _queue;
  static const _cacheKey = 'news';

  DriveNewsService(this._queue, this._cache);

  @override
  Future<List<NewsItem>> fetchFor(
    IdeaCategory category, {
    required String ideaId,
    required String title,
    String? notes,
  }) async {
    final cached = await _cachedNews(ideaId);
    if (cached != null) return cached;

    final result = await _queue.enqueueAndWait(
      kind: 'news',
      title: title,
      ideaId: ideaId,
      notes: notes,
    );
    // process-ai-queue stores runNews()'s return value (a raw array)
    // directly in the queue row's `result` column.
    final list = (result as List?) ?? const [];
    final items = list
        .whereType<Map<String, dynamic>>()
        .map(NewsItem.fromJson)
        .where((n) => n.url.isNotEmpty)
        .toList();
    await _cache.writeCache(
      ideaId,
      _cacheKey,
      items.map((n) => n.toJson()).toList(),
    );
    return items;
  }

  Future<List<NewsItem>?> _cachedNews(String ideaId) async {
    try {
      final payload = await _cache.readCache(ideaId, _cacheKey);
      if (payload is! List) return null;
      return payload
          .whereType<Map>()
          .map((n) => NewsItem.fromJson(n.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return null;
    }
  }
}

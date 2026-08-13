import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/research.dart';
import 'ai_queue_service.dart';
import 'idea_store.dart';

abstract class AiResearchService {
  Future<ResearchReport> research({
    required String ideaId,
    required String title,
    String? notes,
  });
}

class SupabaseResearchService implements AiResearchService {
  final SupabaseClient _client;

  SupabaseResearchService(this._client);

  @override
  Future<ResearchReport> research({
    required String ideaId,
    required String title,
    String? notes,
  }) async {
    final cached = await _cached(ideaId);
    if (cached != null) return cached;

    final res = await _client.functions.invoke(
      'research',
      body: {'ideaId': ideaId, 'title': title, 'notes': notes},
    );
    final data = (res.data as Map<String, dynamic>?) ?? {};
    final report = data['report'] as Map<String, dynamic>? ?? {};
    return ResearchReport.fromJson(report);
  }

  Future<ResearchReport?> _cached(String ideaId) async {
    try {
      final res = await _client
          .from('research_reports')
          .select('payload')
          .eq('idea_id', ideaId)
          .maybeSingle();
      final payload = res?['payload'] as Map<String, dynamic>?;
      if (payload == null) return null;
      final report = ResearchReport.fromJson(payload);
      if (report.summary.isEmpty) return null;
      return report;
    } catch (_) {
      return null;
    }
  }
}

/// Same Google Search->Gemini pipeline as [SupabaseResearchService], but
/// caches the result inside the idea's own Drive file (via [IdeaCache])
/// instead of a `research_reports` table, and goes through [AiQueueService]
/// so the shared Google Search free-tier quota is spent one request at a
/// time instead of however many users tap "Research" at once.
class DriveResearchService implements AiResearchService {
  final IdeaCache _cache;
  final AiQueueService _queue;
  static const _cacheKey = 'research';

  DriveResearchService(this._queue, this._cache);

  @override
  Future<ResearchReport> research({
    required String ideaId,
    required String title,
    String? notes,
  }) async {
    final cached = await _cachedReport(ideaId);
    if (cached != null) return cached;

    final result = await _queue.enqueueAndWait(
      kind: 'research',
      title: title,
      ideaId: ideaId,
      notes: notes,
    );
    // process-ai-queue stores runResearch()'s return value (the report
    // object itself) directly in the queue row's `result` column.
    final reportJson = (result as Map?)?.cast<String, dynamic>() ?? {};
    final report = ResearchReport.fromJson(reportJson);
    await _cache.writeCache(ideaId, _cacheKey, reportJson);
    return report;
  }

  Future<ResearchReport?> _cachedReport(String ideaId) async {
    try {
      final payload = await _cache.readCache(ideaId, _cacheKey);
      if (payload is! Map) return null;
      final report = ResearchReport.fromJson(payload.cast<String, dynamic>());
      if (report.summary.isEmpty) return null;
      return report;
    } catch (_) {
      return null;
    }
  }
}

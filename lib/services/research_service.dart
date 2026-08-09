import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/research.dart';
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

/// Same Perplexity->Gemini edge function as [SupabaseResearchService], but
/// caches the result inside the idea's own Drive file (via [IdeaCache])
/// instead of a `research_reports` table.
class DriveResearchService implements AiResearchService {
  final SupabaseClient _client;
  final IdeaCache _cache;
  static const _cacheKey = 'research';

  DriveResearchService(this._client, this._cache);

  @override
  Future<ResearchReport> research({
    required String ideaId,
    required String title,
    String? notes,
  }) async {
    final cached = await _cachedReport(ideaId);
    if (cached != null) return cached;

    final res = await _client.functions.invoke(
      'research',
      body: {'title': title, 'notes': notes},
    );
    final data = (res.data as Map<String, dynamic>?) ?? {};
    final reportJson = data['report'] as Map<String, dynamic>? ?? {};
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

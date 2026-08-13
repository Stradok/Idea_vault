import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AiQueueService {
  /// [kind] is 'research', 'news', or 'affiliate'. [ideaId] links this
  /// request back to the idea it's for, so [cancelForIdea] can find and
  /// remove it if the idea gets deleted before the request is processed.
  Future<Object?> enqueueAndWait({
    required String kind,
    required String title,
    required String ideaId,
    String? notes,
    String? category,
  });

  /// Deletes any not-yet-processed queue rows for [ideaId] — call when the
  /// idea itself is deleted, so a Research/News/For-you request doesn't sit
  /// in the queue for an idea that no longer exists.
  Future<void> cancelForIdea(String ideaId);
}

/// Enqueues a Research/News/For-you request and waits (via Supabase
/// Realtime, not polling) for process-ai-queue to process it.
///
/// Why a queue at all: a shared free-tier search API key is spent
/// deliberately, one request at a time on a fixed schedule (see
/// supabase/migrations/0004_ai_queue_cron.sql), instead of however many
/// people happen to tap "Research" at the same moment.
class SupabaseAiQueueService implements AiQueueService {
  final SupabaseClient _client;
  SupabaseAiQueueService(this._client);

  @override
  Future<Object?> enqueueAndWait({
    required String kind,
    required String title,
    required String ideaId,
    String? notes,
    String? category,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');

    final inserted = await _client
        .from('ai_request_queue')
        .insert({
          'user_id': userId,
          'kind': kind,
          'title': title,
          'notes': notes,
          'category': category,
          'idea_id': ideaId,
        })
        .select('id')
        .single();
    final id = inserted['id'] as String;

    final completer = Completer<Object?>();
    late final StreamSubscription<List<Map<String, dynamic>>> sub;
    sub = _client
        .from('ai_request_queue')
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .listen(
      (rows) {
        if (completer.isCompleted) return;
        if (rows.isEmpty) {
          // Row was deleted (e.g. cancelForIdea ran because the idea was
          // deleted while this was still queued) — stop waiting instead of
          // hanging forever.
          completer.completeError(Exception('Request was cancelled'));
          sub.cancel();
          return;
        }
        final row = rows.first;
        final status = row['status'] as String?;
        if (status == 'done') {
          completer.complete(row['result']);
          sub.cancel();
        } else if (status == 'error') {
          completer.completeError(
            Exception(row['error_message']?.toString() ?? 'Processing failed'),
          );
          sub.cancel();
        }
        // status == 'pending' / 'processing': keep waiting.
      },
      onError: (Object e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    return completer.future;
  }

  @override
  Future<void> cancelForIdea(String ideaId) async {
    await _client.from('ai_request_queue').delete().eq('idea_id', ideaId);
  }
}

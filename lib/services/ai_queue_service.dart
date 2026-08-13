import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Enqueues a Research/News/For-you request and waits (via Supabase
/// Realtime, not polling) for process-ai-queue to process it.
///
/// Why a queue at all: Google Custom Search's free tier (100 queries/day)
/// is shared across every user of the app, not per-user — a queue
/// processed one item at a time on a fixed schedule (see
/// supabase/migrations/0004_ai_queue_cron.sql) spends that budget
/// deliberately instead of however many people happen to tap "Research"
/// at the same moment.
class AiQueueService {
  final SupabaseClient _client;
  AiQueueService(this._client);

  /// [kind] is 'research', 'news', or 'affiliate'.
  Future<Object?> enqueueAndWait({
    required String kind,
    required String title,
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
        if (rows.isEmpty || completer.isCompleted) return;
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
}

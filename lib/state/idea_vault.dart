import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/idea.dart';
import '../services/idea_store.dart';
import '../services/media_service.dart';
import '../services/reminder_service.dart';

class IdeaVault extends ChangeNotifier {
  final IdeaStore store;
  final MediaService media;
  final ReminderService reminders;
  final List<Idea> _ideas = [];

  String? _userId;

  IdeaVault({required this.store, required this.media, required this.reminders});

  String? get userId => _userId;

  void setUserId(String? userId) => _userId = userId;

  List<Idea> get ideas => List.unmodifiable(_ideas);

  List<Idea> get favorites => _ideas.where((i) => i.isFavorite).toList();

  Idea? byId(String id) {
    for (final idea in _ideas) {
      if (idea.id == id) return idea;
    }
    return null;
  }

  Future<void> load() async {
    final userId = _currentUserId();
    final stored = await store.loadIdeas(userId);
    for (final idea in stored) {
      if (idea.hasMedia) {
        try {
          await media.resolveMediaUrls(idea);
        } catch (_) {}
      }
    }
    _ideas
      ..clear()
      ..addAll(stored);
    notifyListeners();
  }

  Future<Idea> addIdea({
    required String title,
    String? notes,
    String? localImagePath,
    String? localAudioPath,
  }) async {
    final idea = Idea(
      id: const Uuid().v4(),
      title: title,
      notes: notes,
      createdAt: DateTime.now(),
    );

    final paths = await media.uploadIdeaMedia(
      ideaId: idea.id,
      localImagePath: localImagePath,
      localAudioPath: localAudioPath,
    );

    final saved = Idea(
      id: idea.id,
      title: idea.title,
      notes: idea.notes,
      imagePath: paths.imagePath,
      audioPath: paths.audioPath,
      createdAt: idea.createdAt,
    );
    final inserted = await store.insertIdea(saved);
    if (inserted.hasMedia) {
      await media.resolveMediaUrls(inserted);
    }
    _ideas.insert(0, inserted);
    notifyListeners();
    return inserted;
  }

  Future<void> deleteIdea(String id) async {
    final index = _ideas.indexWhere((i) => i.id == id);
    if (index < 0) return;
    final idea = _ideas[index];
    await store.deleteIdea(id);
    await media.deleteIdeaMedia(idea);
    await reminders.cancelRevisit(id);
    _ideas.removeAt(index);
    notifyListeners();
  }

  Future<void> updateIdea(Idea updated) async {
    final index = _ideas.indexWhere((i) => i.id == updated.id);
    if (index < 0) return;
    await store.updateIdea(updated);
    _ideas[index] = updated;
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final index = _ideas.indexWhere((i) => i.id == id);
    if (index < 0) return;
    final updated = _ideas[index].copyWith(isFavorite: !_ideas[index].isFavorite);
    await store.updateIdea(updated);
    _ideas[index] = updated;
    notifyListeners();
  }

  Future<bool> setReminder(String id, DateTime when) async {
    final index = _ideas.indexWhere((i) => i.id == id);
    if (index < 0) return false;
    final idea = _ideas[index];
    final scheduled = await reminders.scheduleRevisit(idea.id, idea.title, when);
    if (!scheduled) return false;
    final updated = idea.copyWith(reminderEnabled: true, reminderAt: when);
    await store.updateIdea(updated);
    _ideas[index] = updated;
    notifyListeners();
    return true;
  }

  Future<void> clearReminder(String id) async {
    final index = _ideas.indexWhere((i) => i.id == id);
    if (index < 0) return;
    await reminders.cancelRevisit(id);
    final updated =
        _ideas[index].copyWith(reminderEnabled: false, reminderAt: null);
    await store.updateIdea(updated);
    _ideas[index] = updated;
    notifyListeners();
  }

  void clear() {
    _ideas.clear();
    notifyListeners();
  }

  String _currentUserId() {
    final userId = _userId;
    if (userId == null) throw StateError('Not authenticated');
    return userId;
  }
}

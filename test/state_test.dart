import 'package:flutter_test/flutter_test.dart';

import 'package:idea_vault/models/idea.dart';
import 'package:idea_vault/services/idea_store.dart';
import 'package:idea_vault/services/media_service.dart';
import 'package:idea_vault/services/reminder_service.dart';
import 'package:idea_vault/state/idea_vault.dart';

class _FakeReminders extends ReminderService {
  final List<String> scheduled = [];
  final List<String> cancelled = [];

  @override
  Future<bool> scheduleRevisit(
      String ideaId, String title, DateTime when) async {
    scheduled.add(ideaId);
    return true;
  }

  @override
  Future<void> cancelRevisit(String ideaId) async {
    cancelled.add(ideaId);
  }
}

class _FakeStore extends IdeaStore {
  List<Idea> stored = [];
  int _deleted = 0;

  @override
  Future<List<Idea>> loadIdeas(String userId) async => List.of(stored);

  @override
  Future<Idea> insertIdea(Idea idea) async {
    stored.insert(0, idea);
    return idea;
  }

  @override
  Future<void> updateIdea(Idea idea) async {
    final index = stored.indexWhere((i) => i.id == idea.id);
    if (index >= 0) stored[index] = idea;
  }

  @override
  Future<void> deleteIdea(String ideaId) async {
    _deleted++;
    stored.removeWhere((i) => i.id == ideaId);
  }

  int get deleteCount => _deleted;
}

class _FakeMedia extends MediaService {
  int uploads = 0;

  @override
  Future<String> tempAudioPath(String ideaId) async => '/tmp/$ideaId.m4a';

  @override
  Future<IdeaMediaPaths> uploadIdeaMedia({
    required String ideaId,
    String? localImagePath,
    String? localAudioPath,
  }) async {
    uploads++;
    return IdeaMediaPaths(
      imagePath: localImagePath != null ? '$ideaId.jpg' : null,
      audioPath: localAudioPath != null ? '$ideaId.m4a' : null,
    );
  }

  @override
  Future<void> resolveMediaUrls(Idea idea) async {}

  @override
  Future<void> deleteIdeaMedia(Idea idea) async {}
}

void main() {
  late _FakeStore store;
  late _FakeMedia media;
  late _FakeReminders reminders;
  late IdeaVault vault;

  setUp(() {
    store = _FakeStore();
    media = _FakeMedia();
    reminders = _FakeReminders();
    vault = IdeaVault(store: store, media: media, reminders: reminders);
    vault.setUserId('user-1');
  });

  test('add, favorite, delete lifecycle', () async {
    await vault.load();

    final idea = await vault.addIdea(title: 'Coffee truck for offices');
    expect(vault.ideas.length, 1);

    await vault.toggleFavorite(idea.id);
    expect(vault.favorites.length, 1);

    await vault.deleteIdea(idea.id);
    expect(vault.ideas, isEmpty);
    expect(store.deleteCount, 1);
  });

  test('addIdea sorts newest first', () async {
    await vault.load();
    await vault.addIdea(title: 'First');
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await vault.addIdea(title: 'Second');
    expect(vault.ideas.first.title, 'Second');
  });

  test('addIdea uploads media when provided', () async {
    await vault.load();
    final idea = await vault.addIdea(
      title: 'Gym app',
      localImagePath: '/tmp/photo.jpg',
      localAudioPath: '/tmp/note.m4a',
    );
    expect(media.uploads, 1);
    expect(idea.imagePath, isNotNull);
    expect(idea.audioPath, isNotNull);
    expect(idea.hasMedia, isTrue);
  });

  test('setReminder schedules and persists', () async {
    await vault.load();
    final idea = await vault.addIdea(title: 'Gym app');

    final when = DateTime(2026, 9, 1, 9, 0);
    final ok = await vault.setReminder(idea.id, when);

    expect(ok, isTrue);
    expect(reminders.scheduled, contains(idea.id));
    final stored = vault.byId(idea.id)!;
    expect(stored.reminderEnabled, isTrue);
    expect(stored.reminderAt, when);
  });

  test('clearReminder cancels and resets', () async {
    await vault.load();
    final idea = await vault.addIdea(title: 'Gym app');
    await vault.setReminder(idea.id, DateTime(2026, 9, 1, 9, 0));
    await vault.clearReminder(idea.id);

    expect(reminders.cancelled, contains(idea.id));
    final stored = vault.byId(idea.id)!;
    expect(stored.reminderEnabled, isFalse);
    expect(stored.reminderAt, isNull);
  });

  test('load restores stored ideas for the user', () async {
    store.stored = [
      Idea(
        id: 'saved-1',
        title: 'Saved idea',
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
    await vault.load();
    expect(vault.byId('saved-1')?.title, 'Saved idea');
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:idea_vault/models/idea.dart';
import 'package:idea_vault/screens/home_screen.dart';
import 'package:idea_vault/services/idea_store.dart';
import 'package:idea_vault/services/media_service.dart';
import 'package:idea_vault/services/reminder_service.dart';
import 'package:idea_vault/state/idea_vault.dart';

class _FakeReminders extends ReminderService {
  final List<DateTime> scheduled = [];

  @override
  Future<bool> scheduleRevisit(
      String ideaId, String title, DateTime when) async {
    scheduled.add(when);
    return true;
  }

  @override
  Future<void> cancelRevisit(String ideaId) async {}
}

class _FakeStore extends IdeaStore {
  List<Idea> stored;
  _FakeStore([List<Idea>? ideas]) : stored = ideas ?? const [];

  @override
  Future<List<Idea>> loadIdeas(String userId) async => List.of(stored);

  @override
  Future<Idea> insertIdea(Idea idea) async {
    stored = [idea, ...stored];
    return idea;
  }

  @override
  Future<void> updateIdea(Idea idea) async {}

  @override
  Future<void> deleteIdea(String ideaId) async {}
}

class _FakeMedia extends MediaService {
  @override
  Future<String> tempAudioPath(String ideaId) async => '/tmp/$ideaId.m4a';

  @override
  Future<IdeaMediaPaths> uploadIdeaMedia({
    required String ideaId,
    String? localImagePath,
    String? localAudioPath,
  }) async {
    return IdeaMediaPaths(
      imagePath: localImagePath != null ? '$ideaId.jpg' : null,
      audioPath: localAudioPath != null ? '$ideaId.m4a' : null,
    );
  }

  @override
  Future<void> resolveMediaUrls(Idea idea) async {}

  @override
  Future<void> deleteIdeaMedia(String ideaId) async {}
}

void main() {
  testWidgets('shows empty state when no ideas exist', (tester) async {
    final vault = IdeaVault(
      store: _FakeStore(),
      media: _FakeMedia(),
      reminders: _FakeReminders(),
    );
    vault.setUserId('user-1');
    await vault.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: vault,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('IdeaVault'), findsOneWidget);
    expect(find.text('Your idea vault is empty'), findsOneWidget);
    expect(find.text('Capture idea'), findsOneWidget);
  });

  testWidgets('renders captured ideas in a list', (tester) async {
    final vault = IdeaVault(
      store: _FakeStore([
        Idea(
          id: '1',
          title: 'A local delivery service',
          createdAt: DateTime(2026, 8, 8),
          isFavorite: true,
        ),
      ]),
      media: _FakeMedia(),
      reminders: _FakeReminders(),
    );
    vault.setUserId('user-1');
    await vault.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: vault,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('A local delivery service'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsOneWidget);
  });
}

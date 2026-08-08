import 'package:flutter_test/flutter_test.dart';

import 'package:idea_vault/models/idea.dart';

void main() {
  test('Idea JSON round-trips', () {
    final idea = Idea(
      id: 'abc',
      title: 'A local delivery service',
      notes: 'Same-day for small shops',
      imagePath: '/media/abc/image.jpg',
      audioPath: '/media/abc/audio.m4a',
      createdAt: DateTime(2026, 8, 8, 10, 30),
      isFavorite: true,
      reminderEnabled: true,
      reminderAt: DateTime(2026, 8, 9, 9, 0),
    );

    final restored = Idea.fromJson(idea.toJson());

    expect(restored.id, idea.id);
    expect(restored.title, idea.title);
    expect(restored.notes, idea.notes);
    expect(restored.imagePath, idea.imagePath);
    expect(restored.audioPath, idea.audioPath);
    expect(restored.createdAt, idea.createdAt);
    expect(restored.isFavorite, isTrue);
    expect(restored.reminderEnabled, isTrue);
    expect(restored.reminderAt, idea.reminderAt);
    expect(restored.hasMedia, isTrue);
  });

  test('copyWith preserves id and createdAt', () {
    final idea = Idea(
      id: 'abc',
      title: 'Original',
      createdAt: DateTime(2026, 1, 1),
    );
    final updated = idea.copyWith(title: 'New title', isFavorite: true);
    expect(updated.id, 'abc');
    expect(updated.createdAt, idea.createdAt);
    expect(updated.title, 'New title');
    expect(updated.isFavorite, isTrue);
    expect(updated.notes, isNull);
  });
}

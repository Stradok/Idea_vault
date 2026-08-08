import 'package:flutter_test/flutter_test.dart';

import 'package:idea_vault/services/idea_category.dart';

void main() {
  test('detects delivery ideas', () {
    expect(detectCategory('Hyper-local delivery app for merchants'),
        IdeaCategory.delivery);
  });

  test('detects food ideas', () {
    expect(detectCategory('Home kitchen meal service'),
        IdeaCategory.food);
  });

  test('detects tech ideas', () {
    expect(detectCategory('SaaS platform for small teams'),
        IdeaCategory.technology);
  });

  test('falls back to generic', () {
    expect(detectCategory('Something completely random'), IdeaCategory.generic);
  });

  test('every category has a label', () {
    for (final c in IdeaCategory.values) {
      expect(c.label, isNotEmpty);
    }
  });
}

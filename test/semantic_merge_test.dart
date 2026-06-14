import 'package:flutter_test/flutter_test.dart';
import 'package:repotoire/domain/entities.dart';
import 'package:repotoire/sync/semantic_merge.dart';

void main() {
  final base = Score(
    id: 'score1',
    title: 'Nocturne',
    currentVersion: 'v1',
    createdAt: DateTime.utc(2026),
    tags: const ['practice'],
  );

  test('adopts one-sided scalar changes', () {
    final result = const ScoreSemanticMerger().merge(
      base: base,
      local: base.copyWith(title: 'Nocturne Op. 9 No. 2'),
      remote: base,
    );

    expect(result.hasConflicts, isFalse);
    expect(result.value.title, 'Nocturne Op. 9 No. 2');
  });

  test('adopts one-sided nullable scalar removals', () {
    final keyedBase = base.copyWith(key: 'C-dur');
    final result = const ScoreSemanticMerger().merge(
      base: keyedBase,
      local: keyedBase.copyWith(key: null),
      remote: keyedBase,
    );

    expect(result.hasConflicts, isFalse);
    expect(result.value.key, isNull);
  });

  test('unions additive tag changes', () {
    final result = const ScoreSemanticMerger().merge(
      base: base,
      local: base.copyWith(tags: const ['practice', 'piano']),
      remote: base.copyWith(tags: const ['practice', 'chopin']),
    );

    expect(result.hasConflicts, isFalse);
    expect(result.value.tags, ['chopin', 'piano', 'practice']);
  });

  test('conflicts on current version changes from both sides', () {
    final result = const ScoreSemanticMerger().merge(
      base: base,
      local: base.copyWith(currentVersion: 'v2'),
      remote: base.copyWith(currentVersion: 'v3'),
    );

    expect(result.hasConflicts, isTrue);
    expect(result.conflicts.single.field, ConflictField.currentVersion);
  });

  test('conflicts on delete edit changes', () {
    final result = const ScoreSemanticMerger().merge(
      base: base,
      local: base.copyWith(deletedAt: DateTime.utc(2026, 1, 2)),
      remote: base.copyWith(title: 'Remote title'),
    );

    expect(result.hasConflicts, isTrue);
    expect(result.conflicts.single.field, ConflictField.deletedAt);
  });

  test('does not treat validation state changes as delete edit conflicts', () {
    final result = const ScoreSemanticMerger().merge(
      base: base,
      local: base.copyWith(deletedAt: DateTime.utc(2026, 1, 2)),
      remote: base.copyWith(
        validity: ScoreValidity.invalid,
        invalidReason: 'PDFを開けません',
      ),
    );

    expect(result.hasConflicts, isFalse);
    expect(result.value.deletedAt, DateTime.utc(2026, 1, 2));
  });
}

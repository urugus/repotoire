import 'package:flutter_test/flutter_test.dart';
import 'package:repotoire/domain/entities.dart';

void main() {
  final score = Score(
    id: 'score1',
    title: 'Nocturne',
    currentVersion: 'v1',
    createdAt: DateTime.utc(2026),
  );

  test('copyWith can clear nullable fields', () {
    final keyed = score.copyWith(
      key: 'C-dur',
      invalidReason: 'PDFを開けません',
      deletedAt: DateTime.utc(2026, 1, 2),
    );

    final cleared = keyed.copyWith(
      key: null,
      invalidReason: null,
      deletedAt: null,
    );

    expect(cleared.key, isNull);
    expect(cleared.invalidReason, isNull);
    expect(cleared.deletedAt, isNull);
  });

  test('score equality includes validity, invalid reason, and extra fields',
      () {
    expect(score.copyWith(validity: ScoreValidity.invalid), isNot(score));
    expect(score.copyWith(invalidReason: 'PDFを開けません'), isNot(score));
    expect(score.copyWith(extra: const {'source': 'remote'}), isNot(score));
  });
}

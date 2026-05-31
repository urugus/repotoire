import 'package:flutter_test/flutter_test.dart';
import 'package:repotoire/domain/import_policy.dart';

void main() {
  test('allows files up to 1MB without warning', () {
    final result = const ImportPolicy().evaluate(1024 * 1024);

    expect(result.decision, ImportDecision.allow);
    expect(result.canImport, isTrue);
  });

  test('warns for files between 1MB and 20MB', () {
    final result = const ImportPolicy().evaluate(2 * 1024 * 1024);

    expect(result.decision, ImportDecision.warn);
    expect(result.canImport, isTrue);
  });

  test('rejects files over 20MB', () {
    final result = const ImportPolicy().evaluate(20 * 1024 * 1024 + 1);

    expect(result.decision, ImportDecision.reject);
    expect(result.canImport, isFalse);
  });
}

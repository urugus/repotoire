import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repotoire/data/local/app_database.dart';
import 'package:repotoire/data/local/library_repository.dart';

void main() {
  late AppDatabase database;
  late LibraryRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LibraryRepository(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  test('filters scores by key and tag', () async {
    await _insertScore(
      database,
      id: 'score-a',
      title: 'Nocturne',
      key: 'Es-dur',
      tags: const ['practice', 'piano'],
    );
    await _insertScore(
      database,
      id: 'score-b',
      title: 'Prelude',
      key: 'C-dur',
      tags: const ['recital'],
    );

    final byKey = await repository.watchScores(key: 'Es-dur').first;
    final byTag = await repository.watchScores(tag: 'practice').first;

    expect(byKey.map((score) => score.title), ['Nocturne']);
    expect(byTag.map((score) => score.title), ['Nocturne']);
    expect(byTag.single.tags, ['piano', 'practice']);
  });

  test('does not include logically deleted scores by default', () async {
    await _insertScore(
      database,
      id: 'score-a',
      title: 'Nocturne',
      deletedAt: DateTime.utc(2026),
    );

    final visible = await repository.watchScores().first;
    final withDeleted =
        await repository.watchScores(includeDeleted: true).first;

    expect(visible, isEmpty);
    expect(withDeleted.single.title, 'Nocturne');
  });
}

Future<void> _insertScore(
  AppDatabase database, {
  required String id,
  required String title,
  String? key,
  DateTime? deletedAt,
  List<String> tags = const [],
}) async {
  await database.into(database.scores).insert(
        ScoresCompanion.insert(
          id: id,
          title: title,
          key: Value(key),
          currentVersion: '$id-version',
          deletedAt: Value(deletedAt),
          createdAt: DateTime.utc(2026, 1, 1),
          titleNormalized: title.toLowerCase(),
        ),
      );
  for (final tag in tags) {
    await database.into(database.tags).insert(
          TagsCompanion.insert(
            scoreId: id,
            tag: tag,
            tagNormalized: tag.toLowerCase(),
          ),
        );
  }
}

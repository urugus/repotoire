import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repotoire/data/local/app_database.dart';
import 'package:repotoire/data/local/library_repository.dart';
import 'package:repotoire/domain/entities.dart';
import 'package:repotoire/sync/local_operation_queue.dart';

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

  test('updates score metadata and records a local operation', () async {
    final operationQueue = LocalOperationQueue(database: database);
    repository = LibraryRepository(
      database: database,
      operationQueue: operationQueue,
    );
    await _insertScore(
      database,
      id: 'score-a',
      title: 'Nocturne',
      key: 'Es-dur',
      tags: const ['practice'],
    );

    await repository.updateMetadata(
      const UpdateScoreMetadataRequest(
        scoreId: 'score-a',
        title: 'Nocturne Op. 9 No. 2',
        key: 'F-dur',
        tags: ['piano', 'recital', 'piano'],
      ),
    );

    final scores = await repository.watchScores().first;
    final operations = await operationQueue.watchPending().first;

    expect(scores.single.title, 'Nocturne Op. 9 No. 2');
    expect(scores.single.key, 'F-dur');
    expect(scores.single.tags, ['piano', 'recital']);
    expect(operations.single.type, LocalOperationType.updateMeta);
    expect(operations.single.payload['score_id'], 'score-a');
    expect(operations.single.payload['tags'], ['piano', 'recital']);
  });

  test('logical delete records a local operation', () async {
    final operationQueue = LocalOperationQueue(database: database);
    repository = LibraryRepository(
      database: database,
      operationQueue: operationQueue,
    );
    await _insertScore(database, id: 'score-a', title: 'Nocturne');

    await repository.logicalDelete('score-a');

    final scores = await repository.watchScores(includeDeleted: true).first;
    final operations = await operationQueue.watchPending().first;

    expect(scores.single.deletedAt, isA<DateTime>());
    expect(operations.single.type, LocalOperationType.deleteScore);
    expect(operations.single.payload['score_id'], 'score-a');
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

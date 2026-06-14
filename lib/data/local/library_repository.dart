import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:ulid/ulid.dart';

import '../../domain/entities.dart' as domain;
import '../../domain/import_policy.dart';
import '../../domain/text_normalizer.dart';
import '../../sync/local_operation_queue.dart';
import 'app_database.dart';

class ScoreListItem {
  const ScoreListItem({
    required this.id,
    required this.title,
    required this.currentVersion,
    required this.validity,
    this.tags = const [],
    this.key,
    this.deletedAt,
    this.invalidReason,
  });

  final String id;
  final String title;
  final String currentVersion;
  final domain.ScoreValidity validity;
  final List<String> tags;
  final String? key;
  final DateTime? deletedAt;
  final String? invalidReason;
}

class ImportScoreRequest {
  const ImportScoreRequest({
    required this.pdfFile,
    required this.title,
    this.key,
    this.tags = const [],
  });

  final File pdfFile;
  final String title;
  final String? key;
  final List<String> tags;
}

class UpdateScoreMetadataRequest {
  const UpdateScoreMetadataRequest({
    required this.scoreId,
    required this.title,
    this.key,
    this.tags = const [],
  });

  final String scoreId;
  final String title;
  final String? key;
  final List<String> tags;
}

class ImportScoreResult {
  const ImportScoreResult({
    required this.scoreId,
    required this.versionId,
    required this.policyResult,
  });

  final String scoreId;
  final String versionId;
  final ImportPolicyResult policyResult;
}

class LibraryRepository {
  LibraryRepository({
    required AppDatabase database,
    LocalOperationQueue? operationQueue,
    ImportPolicy importPolicy = const ImportPolicy(),
    TextNormalizer textNormalizer = const TextNormalizer(),
  })  : _database = database,
        _operationQueue = operationQueue,
        _importPolicy = importPolicy,
        _textNormalizer = textNormalizer;

  final AppDatabase _database;
  final LocalOperationQueue? _operationQueue;
  final ImportPolicy _importPolicy;
  final TextNormalizer _textNormalizer;

  Stream<List<ScoreListItem>> watchScores({
    String query = '',
    String? tag,
    String? key,
    bool includeDeleted = false,
  }) {
    final normalizedQuery = _textNormalizer.normalize(query);
    final normalizedTag = _textNormalizer.normalize(tag ?? '');
    final normalizedKey = key?.trim();
    final whereClauses = <String>[];
    final variables = <Variable>[];

    if (!includeDeleted) {
      whereClauses.add('s.deleted_at IS NULL');
    }
    if (normalizedQuery.isNotEmpty) {
      whereClauses.add("s.title_normalized LIKE '%' || ? || '%'");
      variables.add(Variable<String>(normalizedQuery));
    }
    if (normalizedKey != null && normalizedKey.isNotEmpty) {
      whereClauses.add('s.key = ?');
      variables.add(Variable<String>(normalizedKey));
    }
    if (normalizedTag.isNotEmpty) {
      whereClauses.add(
        '''
        EXISTS (
          SELECT 1
          FROM tags tf
          WHERE tf.score_id = s.id
            AND tf.tag_normalized = ?
        )
        ''',
      );
      variables.add(Variable<String>(normalizedTag));
    }

    final whereSql =
        whereClauses.isEmpty ? '' : 'WHERE ${whereClauses.join(' AND ')}';

    return _database
        .customSelect(
          '''
          SELECT
            s.id,
            s.title,
            s.key AS score_key,
            s.current_version,
            s.deleted_at,
            s.validity,
            s.invalid_reason,
            group_concat(t.tag, char(31)) AS tags
          FROM scores s
          LEFT JOIN tags t ON t.score_id = s.id
          $whereSql
          GROUP BY s.id
          ORDER BY s.title_normalized ASC, s.created_at ASC
          ''',
          variables: variables,
          readsFrom: {_database.scores, _database.tags},
        )
        .watch()
        .map((rows) {
      return rows.map((row) {
        final tags = row.readNullable<String>('tags');
        return ScoreListItem(
          id: row.read<String>('id'),
          title: row.read<String>('title'),
          key: row.readNullable<String>('score_key'),
          currentVersion: row.read<String>('current_version'),
          deletedAt: row.readNullable<DateTime>('deleted_at'),
          tags: tags == null
              ? const []
              : (tags.split(String.fromCharCode(31))..sort())
                  .toList(growable: false),
          validity: row.read<String>('validity') == 'invalid'
              ? domain.ScoreValidity.invalid
              : domain.ScoreValidity.valid,
          invalidReason: row.readNullable<String>('invalid_reason'),
        );
      }).toList(growable: false);
    });
  }

  Future<ImportScoreResult> importScore(ImportScoreRequest request) async {
    final size = await request.pdfFile.length();
    final policyResult = _importPolicy.evaluate(size);
    if (!policyResult.canImport) {
      throw StateError(policyResult.message);
    }

    final now = DateTime.now().toUtc();
    final scoreId = Ulid().toCanonical();
    final versionId = Ulid().toCanonical();
    final storageDir = await _scoreStorageDirectory(scoreId);
    await storageDir.create(recursive: true);
    final copiedPdf = File(p.join(storageDir.path, '$versionId.pdf'));
    await request.pdfFile.copy(copiedPdf.path);
    final pageCount = await _readPageCount(copiedPdf);
    final validity = pageCount == null
        ? domain.ScoreValidity.invalid
        : domain.ScoreValidity.valid;

    await _database.transaction(() async {
      await _database.into(_database.scores).insert(
            ScoresCompanion.insert(
              id: scoreId,
              title: request.title,
              key: Value(request.key),
              currentVersion: versionId,
              createdAt: now,
              titleNormalized: _textNormalizer.normalize(request.title),
              validity: Value(validity.name),
              invalidReason: Value(pageCount == null ? 'PDFを開けません' : null),
            ),
          );
      await _database.into(_database.scoreVersions).insert(
            ScoreVersionsCompanion.insert(
              id: versionId,
              scoreId: scoreId,
              localPath: copiedPdf.path,
              pageCount: pageCount ?? 0,
              addedAt: now,
            ),
          );
      for (final tag in _cleanTags(request.tags)) {
        await _database.into(_database.tags).insertOnConflictUpdate(
              TagsCompanion.insert(
                scoreId: scoreId,
                tag: tag,
                tagNormalized: _textNormalizer.normalize(tag),
              ),
            );
      }
      await _operationQueue?.enqueue(
        type: domain.LocalOperationType.addScore,
        baseHeadSha: null,
        payload: {
          'score_id': scoreId,
          'version_id': versionId,
          'title': request.title,
          'key': request.key,
          'tags': _cleanTags(request.tags),
          'local_path': copiedPdf.path,
          'page_count': pageCount ?? 0,
        },
      );
    });

    return ImportScoreResult(
      scoreId: scoreId,
      versionId: versionId,
      policyResult: policyResult,
    );
  }

  Future<File?> currentPdfFile(String scoreId) async {
    final score = await (_database.select(_database.scores)
          ..where((row) => row.id.equals(scoreId)))
        .getSingleOrNull();
    if (score == null) {
      return null;
    }
    final version = await (_database.select(_database.scoreVersions)
          ..where((row) => row.id.equals(score.currentVersion)))
        .getSingleOrNull();
    if (version == null) {
      return null;
    }
    final file = File(version.localPath);
    return file.existsSync() ? file : null;
  }

  Future<void> updateMetadata(UpdateScoreMetadataRequest request) async {
    final cleanedTags = _cleanTags(request.tags);
    final key = request.key?.trim();
    await _database.transaction(() async {
      final updated = await (_database.update(_database.scores)
            ..where((row) => row.id.equals(request.scoreId)))
          .write(
        ScoresCompanion(
          title: Value(request.title),
          key: Value(key == null || key.isEmpty ? null : key),
          titleNormalized: Value(_textNormalizer.normalize(request.title)),
        ),
      );
      if (updated == 0) {
        throw StateError('楽譜が見つかりません');
      }

      await (_database.delete(_database.tags)
            ..where((row) => row.scoreId.equals(request.scoreId)))
          .go();
      for (final tag in cleanedTags) {
        await _database.into(_database.tags).insertOnConflictUpdate(
              TagsCompanion.insert(
                scoreId: request.scoreId,
                tag: tag,
                tagNormalized: _textNormalizer.normalize(tag),
              ),
            );
      }
      await _operationQueue?.enqueue(
        type: domain.LocalOperationType.updateMeta,
        baseHeadSha: null,
        payload: {
          'score_id': request.scoreId,
          'title': request.title,
          'key': key == null || key.isEmpty ? null : key,
          'tags': cleanedTags,
        },
      );
    });
  }

  Future<void> logicalDelete(String scoreId) async {
    final deletedAt = DateTime.now().toUtc();
    await _database.transaction(() async {
      final updated = await (_database.update(_database.scores)
            ..where((row) => row.id.equals(scoreId)))
          .write(ScoresCompanion(deletedAt: Value(deletedAt)));
      if (updated == 0) {
        throw StateError('楽譜が見つかりません');
      }
      await _operationQueue?.enqueue(
        type: domain.LocalOperationType.deleteScore,
        baseHeadSha: null,
        payload: {
          'score_id': scoreId,
          'deleted_at': deletedAt.toIso8601String(),
        },
      );
    });
  }

  Future<Directory> _scoreStorageDirectory(String scoreId) async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory(p.join(documents.path, 'scores', scoreId, 'versions'));
  }

  Future<int?> _readPageCount(File pdfFile) async {
    try {
      final document = await PdfDocument.openFile(pdfFile.path);
      try {
        return document.pages.length;
      } finally {
        await document.dispose();
      }
    } catch (_) {
      return null;
    }
  }

  List<String> _cleanTags(List<String> tags) {
    final byNormalized = <String, String>{};
    for (final tag in tags) {
      final trimmed = tag.trim();
      final normalized = _textNormalizer.normalize(trimmed);
      if (normalized.isNotEmpty) {
        byNormalized[normalized] = trimmed;
      }
    }
    return byNormalized.values.toList(growable: false);
  }
}

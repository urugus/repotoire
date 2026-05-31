import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:ulid/ulid.dart';

import '../../domain/entities.dart' as domain;
import '../../domain/import_policy.dart';
import '../../domain/text_normalizer.dart';
import 'app_database.dart';

class ScoreListItem {
  const ScoreListItem({
    required this.id,
    required this.title,
    required this.currentVersion,
    required this.validity,
    this.key,
    this.deletedAt,
    this.invalidReason,
  });

  final String id;
  final String title;
  final String currentVersion;
  final domain.ScoreValidity validity;
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
    ImportPolicy importPolicy = const ImportPolicy(),
    TextNormalizer textNormalizer = const TextNormalizer(),
  })  : _database = database,
        _importPolicy = importPolicy,
        _textNormalizer = textNormalizer;

  final AppDatabase _database;
  final ImportPolicy _importPolicy;
  final TextNormalizer _textNormalizer;

  Stream<List<ScoreListItem>> watchScores({
    String query = '',
    String? tag,
    String? key,
    bool includeDeleted = false,
  }) {
    final normalizedQuery = _textNormalizer.normalize(query);
    final select = _database.select(_database.scores);
    if (!includeDeleted) {
      select.where((score) => score.deletedAt.isNull());
    }
    if (normalizedQuery.isNotEmpty) {
      select.where(
        (score) => score.titleNormalized.contains(normalizedQuery),
      );
    }
    if (key != null && key.isNotEmpty) {
      select.where((score) => score.key.equals(key));
    }
    select.orderBy([
      (score) => OrderingTerm.asc(score.titleNormalized),
      (score) => OrderingTerm.asc(score.createdAt),
    ]);

    return select.watch().map((rows) {
      return rows.map((row) {
        return ScoreListItem(
          id: row.id,
          title: row.title,
          key: row.key,
          currentVersion: row.currentVersion,
          deletedAt: row.deletedAt,
          validity: row.validity == 'invalid'
              ? domain.ScoreValidity.invalid
              : domain.ScoreValidity.valid,
          invalidReason: row.invalidReason,
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
    final validity =
        pageCount == null ? domain.ScoreValidity.invalid : domain.ScoreValidity.valid;

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
      for (final tag in request.tags) {
        await _database.into(_database.tags).insertOnConflictUpdate(
              TagsCompanion.insert(
                scoreId: scoreId,
                tag: tag,
                tagNormalized: _textNormalizer.normalize(tag),
              ),
            );
      }
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

  Future<void> logicalDelete(String scoreId) async {
    await (_database.update(_database.scores)..where((row) => row.id.equals(scoreId)))
        .write(ScoresCompanion(deletedAt: Value(DateTime.now().toUtc())));
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
}

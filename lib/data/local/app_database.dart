import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

@DataClassName('ScoreRow')
class Scores extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get key => text().nullable()();
  TextColumn get currentVersion => text()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get schemaVersion => integer().withDefault(const Constant(1))();
  TextColumn get titleNormalized => text()();
  TextColumn get kanaNormalized => text().withDefault(const Constant(''))();
  TextColumn get validity => text().withDefault(const Constant('valid'))();
  TextColumn get invalidReason => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ScoreVersionRow')
class ScoreVersions extends Table {
  TextColumn get id => text()();
  TextColumn get scoreId => text().references(Scores, #id)();
  TextColumn get localPath => text()();
  IntColumn get pageCount => integer()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ArtistRow')
class Artists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get nameKana => text().nullable()();
  TextColumn get nameNormalized => text()();
  IntColumn get schemaVersion => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ScoreArtistRow')
class ScoreArtists extends Table {
  TextColumn get scoreId => text().references(Scores, #id)();
  TextColumn get artistId => text().references(Artists, #id)();

  @override
  Set<Column<Object>> get primaryKey => {scoreId, artistId};
}

@DataClassName('TagRow')
class Tags extends Table {
  TextColumn get scoreId => text().references(Scores, #id)();
  TextColumn get tag => text()();
  TextColumn get tagNormalized => text()();

  @override
  Set<Column<Object>> get primaryKey => {scoreId, tagNormalized};
}

@DataClassName('ThumbnailRow')
class Thumbnails extends Table {
  TextColumn get versionId => text().references(ScoreVersions, #id)();
  IntColumn get page => integer()();
  TextColumn get localPath => text()();
  DateTimeColumn get generatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {versionId, page};
}

@DataClassName('SyncFileRow')
class SyncFiles extends Table {
  TextColumn get path => text()();
  TextColumn get blobSha => text()();
  DateTimeColumn get parsedAt => dateTime().nullable()();
  TextColumn get parseStatus => text()();

  @override
  Set<Column<Object>> get primaryKey => {path};
}

@DataClassName('LocalOperationRow')
class LocalOperations extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get status => text()();
  TextColumn get baseHeadSha => text().nullable()();
  TextColumn get createdCommitSha => text().nullable()();
  TextColumn get payloadJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Scores,
    ScoreVersions,
    Artists,
    ScoreArtists,
    Tags,
    Thumbnails,
    SyncFiles,
    LocalOperations,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'repotoire.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

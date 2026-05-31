import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:ulid/ulid.dart';

import '../data/local/app_database.dart';
import '../domain/entities.dart';

class LocalOperationQueue {
  LocalOperationQueue({required AppDatabase database}) : _database = database;

  final AppDatabase _database;

  Future<String> enqueue({
    required LocalOperationType type,
    required String? baseHeadSha,
    required Map<String, Object?> payload,
  }) async {
    final now = DateTime.now().toUtc();
    final id = Ulid().toCanonical();
    await _database.into(_database.localOperations).insert(
          LocalOperationsCompanion.insert(
            id: id,
            type: type.name,
            status: LocalOperationStatus.pending.name,
            baseHeadSha: Value(baseHeadSha),
            payloadJson: Value(jsonEncode(payload)),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Stream<List<LocalOperation>> watchPending() {
    final query = _database.select(_database.localOperations)
      ..where(
        (row) => row.status.isIn([
          LocalOperationStatus.pending.name,
          LocalOperationStatus.committing.name,
          LocalOperationStatus.failed.name,
        ]),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]);
    return query.watch().map((rows) => rows.map(_mapRow).toList(growable: false));
  }

  Future<void> markCommitting(String id) => _mark(
        id,
        status: LocalOperationStatus.committing,
      );

  Future<void> markPushed(String id, String commitSha) => _mark(
        id,
        status: LocalOperationStatus.pushed,
        createdCommitSha: commitSha,
      );

  Future<void> markConflict(String id) => _mark(
        id,
        status: LocalOperationStatus.conflict,
      );

  Future<void> markFailed(String id) => _mark(
        id,
        status: LocalOperationStatus.failed,
      );

  Future<void> _mark(
    String id, {
    required LocalOperationStatus status,
    String? createdCommitSha,
  }) {
    return (_database.update(_database.localOperations)
          ..where((row) => row.id.equals(id)))
        .write(
      LocalOperationsCompanion(
        status: Value(status.name),
        createdCommitSha: createdCommitSha == null
            ? const Value.absent()
            : Value(createdCommitSha),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  LocalOperation _mapRow(LocalOperationRow row) {
    final payload = jsonDecode(row.payloadJson) as Map<String, dynamic>;
    return LocalOperation(
      id: row.id,
      type: LocalOperationType.values.byName(row.type),
      status: LocalOperationStatus.values.byName(row.status),
      baseHeadSha: row.baseHeadSha,
      createdCommitSha: row.createdCommitSha,
      payload: payload,
    );
  }
}

import 'package:collection/collection.dart';

import '../domain/entities.dart';

class ScoreSemanticMerger {
  const ScoreSemanticMerger();

  MergeResult<Score> merge({
    required Score base,
    required Score local,
    required Score remote,
  }) {
    final conflicts = <MetadataConflict>[];

    final mergedDeletedAt = _mergeDeletedAt(
      base: base,
      local: local,
      remote: remote,
      conflicts: conflicts,
    );

    var merged = base.copyWith(
      title: _mergeScalar(
        field: ConflictField.title,
        baseValue: base.title,
        localValue: local.title,
        remoteValue: remote.title,
        conflicts: conflicts,
      ),
      key: _mergeScalar(
        field: ConflictField.key,
        baseValue: base.key,
        localValue: local.key,
        remoteValue: remote.key,
        conflicts: conflicts,
      ),
      currentVersion: _mergeScalar(
        field: ConflictField.currentVersion,
        baseValue: base.currentVersion,
        localValue: local.currentVersion,
        remoteValue: remote.currentVersion,
        conflicts: conflicts,
      ),
      tags: _mergeSet(
        field: ConflictField.tags,
        baseValue: base.tags,
        localValue: local.tags,
        remoteValue: remote.tags,
        conflicts: conflicts,
      ),
      artistIds: _mergeSet(
        field: ConflictField.artistIds,
        baseValue: base.artistIds,
        localValue: local.artistIds,
        remoteValue: remote.artistIds,
        conflicts: conflicts,
      ),
      pageSequence: _mergePageSequence(
        baseValue: base.pageSequence,
        localValue: local.pageSequence,
        remoteValue: remote.pageSequence,
        conflicts: conflicts,
      ),
      deletedAt: mergedDeletedAt,
      clearDeletedAt: mergedDeletedAt == null,
      extra: {
        ...base.extra,
        ...remote.extra,
        ...local.extra,
      },
    );

    if (base.id != local.id || base.id != remote.id) {
      conflicts.add(
        MetadataConflict(
          field: ConflictField.immutable,
          baseValue: base.id,
          localValue: local.id,
          remoteValue: remote.id,
        ),
      );
    }
    if (base.createdAt != local.createdAt || base.createdAt != remote.createdAt) {
      conflicts.add(
        MetadataConflict(
          field: ConflictField.immutable,
          baseValue: base.createdAt,
          localValue: local.createdAt,
          remoteValue: remote.createdAt,
        ),
      );
    }
    if (base.schemaVersion != local.schemaVersion ||
        base.schemaVersion != remote.schemaVersion) {
      conflicts.add(
        MetadataConflict(
          field: ConflictField.immutable,
          baseValue: base.schemaVersion,
          localValue: local.schemaVersion,
          remoteValue: remote.schemaVersion,
        ),
      );
    }

    if (conflicts.isNotEmpty) {
      merged = merged.copyWith(validity: ScoreValidity.invalid);
      return MergeResult.conflicted(merged, conflicts);
    }
    return MergeResult.clean(merged);
  }

  T _mergeScalar<T>({
    required ConflictField field,
    required T baseValue,
    required T localValue,
    required T remoteValue,
    required List<MetadataConflict> conflicts,
  }) {
    if (localValue == remoteValue) {
      return localValue;
    }
    if (localValue == baseValue) {
      return remoteValue;
    }
    if (remoteValue == baseValue) {
      return localValue;
    }
    conflicts.add(
      MetadataConflict(
        field: field,
        baseValue: baseValue,
        localValue: localValue,
        remoteValue: remoteValue,
      ),
    );
    return localValue;
  }

  List<String> _mergeSet({
    required ConflictField field,
    required List<String> baseValue,
    required List<String> localValue,
    required List<String> remoteValue,
    required List<MetadataConflict> conflicts,
  }) {
    final baseSet = baseValue.toSet();
    final localSet = localValue.toSet();
    final remoteSet = remoteValue.toSet();
    const equality = SetEquality<String>();

    if (equality.equals(localSet, remoteSet)) {
      return localSet.toList()..sort();
    }
    if (equality.equals(localSet, baseSet)) {
      return remoteSet.toList()..sort();
    }
    if (equality.equals(remoteSet, baseSet)) {
      return localSet.toList()..sort();
    }

    final localRemoved = baseSet.difference(localSet);
    final remoteRemoved = baseSet.difference(remoteSet);
    final localAdded = localSet.difference(baseSet);
    final remoteAdded = remoteSet.difference(baseSet);
    final hasDeletionAndAddition =
        (localRemoved.isNotEmpty || remoteRemoved.isNotEmpty) &&
            (localAdded.isNotEmpty || remoteAdded.isNotEmpty);

    if (hasDeletionAndAddition) {
      conflicts.add(
        MetadataConflict(
          field: field,
          baseValue: baseValue,
          localValue: localValue,
          remoteValue: remoteValue,
        ),
      );
      return localValue;
    }

    return {...localSet, ...remoteSet}.toList()..sort();
  }

  List<PageSequenceEntry> _mergePageSequence({
    required List<PageSequenceEntry> baseValue,
    required List<PageSequenceEntry> localValue,
    required List<PageSequenceEntry> remoteValue,
    required List<MetadataConflict> conflicts,
  }) {
    final baseJson = baseValue.map((entry) => entry.toJson()).toList();
    final localJson = localValue.map((entry) => entry.toJson()).toList();
    final remoteJson = remoteValue.map((entry) => entry.toJson()).toList();
    const equality = DeepCollectionEquality();

    if (equality.equals(localJson, remoteJson)) {
      return localValue;
    }
    if (equality.equals(localJson, baseJson)) {
      return remoteValue;
    }
    if (equality.equals(remoteJson, baseJson)) {
      return localValue;
    }
    conflicts.add(
      MetadataConflict(
        field: ConflictField.pageSequence,
        baseValue: baseJson,
        localValue: localJson,
        remoteValue: remoteJson,
      ),
    );
    return localValue;
  }

  DateTime? _mergeDeletedAt({
    required Score base,
    required Score local,
    required Score remote,
    required List<MetadataConflict> conflicts,
  }) {
    final localChanged = local.deletedAt != base.deletedAt;
    final remoteChanged = remote.deletedAt != base.deletedAt;

    if (!localChanged && !remoteChanged) {
      return base.deletedAt;
    }
    if (local.deletedAt == remote.deletedAt) {
      return local.deletedAt;
    }

    final localEditedBesidesDelete = _editedBesidesDelete(base, local);
    final remoteEditedBesidesDelete = _editedBesidesDelete(base, remote);
    final deleteEditConflict =
        (localChanged && remoteEditedBesidesDelete) ||
            (remoteChanged && localEditedBesidesDelete);

    if (deleteEditConflict || (localChanged && remoteChanged)) {
      conflicts.add(
        MetadataConflict(
          field: ConflictField.deletedAt,
          baseValue: base.deletedAt,
          localValue: local.deletedAt,
          remoteValue: remote.deletedAt,
        ),
      );
      return local.deletedAt;
    }
    return localChanged ? local.deletedAt : remote.deletedAt;
  }

  bool _editedBesidesDelete(Score base, Score changed) {
    final withoutDeleteBase = base.copyWith(clearDeletedAt: true);
    final withoutDeleteChanged = changed.copyWith(clearDeletedAt: true);
    return withoutDeleteBase != withoutDeleteChanged;
  }
}

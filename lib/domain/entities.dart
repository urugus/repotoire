import 'package:collection/collection.dart';

const Object _unset = Object();

enum ScoreValidity { valid, invalid }

enum LocalOperationType { addScore, updateMeta, deleteScore, addVersion }

enum LocalOperationStatus { pending, committing, pushed, conflict, failed }

enum ConflictField {
  title,
  key,
  tags,
  artistIds,
  currentVersion,
  pageSequence,
  deletedAt,
  immutable,
}

class Library {
  const Library({
    required this.schemaVersion,
    required this.name,
  });

  final int schemaVersion;
  final String name;
}

class Artist {
  const Artist({
    required this.id,
    required this.name,
    this.nameKana,
    this.roles = const [],
    this.schemaVersion = 1,
    this.extra = const {},
  });

  final String id;
  final String name;
  final String? nameKana;
  final List<String> roles;
  final int schemaVersion;
  final Map<String, Object?> extra;
}

class PageSequenceEntry {
  const PageSequenceEntry({
    required this.page,
    this.label,
  });

  final int page;
  final String? label;

  Map<String, Object?> toJson() => {
        'page': page,
        if (label != null) 'label': label,
      };
}

class ScoreVersion {
  const ScoreVersion({
    required this.id,
    required this.scoreId,
    required this.pdfPath,
    required this.pageCount,
    required this.addedAt,
  });

  final String id;
  final String scoreId;
  final String pdfPath;
  final int pageCount;
  final DateTime addedAt;
}

class Score {
  const Score({
    required this.id,
    required this.title,
    required this.currentVersion,
    required this.createdAt,
    this.schemaVersion = 1,
    this.artistIds = const [],
    this.tags = const [],
    this.key,
    this.pageSequence = const [],
    this.deletedAt,
    this.validity = ScoreValidity.valid,
    this.invalidReason,
    this.extra = const {},
  });

  final int schemaVersion;
  final String id;
  final String title;
  final List<String> artistIds;
  final List<String> tags;
  final String? key;
  final String currentVersion;
  final List<PageSequenceEntry> pageSequence;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final ScoreValidity validity;
  final String? invalidReason;
  final Map<String, Object?> extra;

  bool get isDeleted => deletedAt != null;

  Score copyWith({
    int? schemaVersion,
    String? id,
    String? title,
    List<String>? artistIds,
    List<String>? tags,
    // Sentinel-backed nullable fields distinguish omitted values from
    // explicit null updates.
    Object? key = _unset,
    String? currentVersion,
    List<PageSequenceEntry>? pageSequence,
    Object? deletedAt = _unset,
    bool clearDeletedAt = false,
    DateTime? createdAt,
    ScoreValidity? validity,
    Object? invalidReason = _unset,
    Map<String, Object?>? extra,
  }) {
    assert(
      !clearDeletedAt || identical(deletedAt, _unset),
      'Use either clearDeletedAt or deletedAt, not both.',
    );
    return Score(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      id: id ?? this.id,
      title: title ?? this.title,
      artistIds: artistIds ?? this.artistIds,
      tags: tags ?? this.tags,
      key: identical(key, _unset) ? this.key : key as String?,
      currentVersion: currentVersion ?? this.currentVersion,
      pageSequence: pageSequence ?? this.pageSequence,
      deletedAt: clearDeletedAt
          ? null
          : identical(deletedAt, _unset)
              ? this.deletedAt
              : deletedAt as DateTime?,
      createdAt: createdAt ?? this.createdAt,
      validity: validity ?? this.validity,
      invalidReason: identical(invalidReason, _unset)
          ? this.invalidReason
          : invalidReason as String?,
      extra: extra ?? this.extra,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Score &&
        other.schemaVersion == schemaVersion &&
        other.id == id &&
        other.title == title &&
        const ListEquality<String>().equals(other.artistIds, artistIds) &&
        const ListEquality<String>().equals(other.tags, tags) &&
        other.key == key &&
        other.currentVersion == currentVersion &&
        const DeepCollectionEquality().equals(
          other.pageSequence.map((entry) => entry.toJson()).toList(),
          pageSequence.map((entry) => entry.toJson()).toList(),
        ) &&
        other.deletedAt == deletedAt &&
        other.createdAt == createdAt &&
        other.validity == validity &&
        other.invalidReason == invalidReason &&
        const DeepCollectionEquality().equals(other.extra, extra);
  }

  @override
  int get hashCode => Object.hash(
        schemaVersion,
        id,
        title,
        Object.hashAll(artistIds),
        Object.hashAll(tags),
        key,
        currentVersion,
        const DeepCollectionEquality().hash(
          pageSequence.map((entry) => entry.toJson()).toList(),
        ),
        deletedAt,
        createdAt,
        validity,
        invalidReason,
        const DeepCollectionEquality().hash(extra),
      );
}

class SyncState {
  const SyncState({
    required this.remoteHeadSha,
    required this.baseBlobs,
    required this.baseYaml,
  });

  final String? remoteHeadSha;
  final Map<String, String> baseBlobs;
  final Map<String, String> baseYaml;
}

class LocalOperation {
  const LocalOperation({
    required this.id,
    required this.type,
    required this.status,
    required this.baseHeadSha,
    this.createdCommitSha,
    this.payload = const {},
  });

  final String id;
  final LocalOperationType type;
  final LocalOperationStatus status;
  final String? baseHeadSha;
  final String? createdCommitSha;
  final Map<String, Object?> payload;
}

class MetadataConflict {
  const MetadataConflict({
    required this.field,
    required this.baseValue,
    required this.localValue,
    required this.remoteValue,
  });

  final ConflictField field;
  final Object? baseValue;
  final Object? localValue;
  final Object? remoteValue;
}

class MergeResult<T> {
  const MergeResult.clean(this.value) : conflicts = const [];

  const MergeResult.conflicted(this.value, this.conflicts);

  final T value;
  final List<MetadataConflict> conflicts;

  bool get hasConflicts => conflicts.isNotEmpty;
}

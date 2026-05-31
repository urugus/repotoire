import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'entities.dart';

class ScoreYamlCodec {
  const ScoreYamlCodec();

  Score decode(String yamlSource) {
    final root = loadYaml(yamlSource);
    if (root is! YamlMap) {
      throw const FormatException('score.yml must be a YAML map');
    }

    final map = _toPlainMap(root);
    final schemaVersion = _requiredInt(map, 'schema_version');
    final id = _requiredString(map, 'id');
    final title = _requiredString(map, 'title');
    final currentVersion = _requiredString(map, 'current_version');
    final createdAt = DateTime.parse(_requiredString(map, 'created_at'));
    final deletedAtValue = map['deleted_at'];

    final knownKeys = {
      'schema_version',
      'id',
      'title',
      'artist_ids',
      'tags',
      'key',
      'current_version',
      'page_sequence',
      'deleted_at',
      'created_at',
    };

    return Score(
      schemaVersion: schemaVersion,
      id: id,
      title: title,
      artistIds: _stringList(map['artist_ids']),
      tags: _stringList(map['tags']),
      key: map['key'] as String?,
      currentVersion: currentVersion,
      pageSequence: _pageSequence(map['page_sequence']),
      deletedAt: deletedAtValue == null
          ? null
          : DateTime.parse(deletedAtValue.toString()),
      createdAt: createdAt,
      extra: Map.fromEntries(
        map.entries.where((entry) => !knownKeys.contains(entry.key)),
      ),
    );
  }

  String encode(Score score) {
    final editor = YamlEditor('');
    final data = <String, Object?>{
      ...score.extra,
      'schema_version': score.schemaVersion,
      'id': score.id,
      'title': score.title,
      'artist_ids': [...score.artistIds]..sort(),
      'tags': [...score.tags]..sort(),
      'key': score.key,
      'current_version': score.currentVersion,
      'page_sequence':
          score.pageSequence.map((entry) => entry.toJson()).toList(),
      'deleted_at': score.deletedAt?.toUtc().toIso8601String(),
      'created_at': score.createdAt.toUtc().toIso8601String(),
    };
    editor.update([], data);
    return editor.toString();
  }

  Map<String, Object?> _toPlainMap(YamlMap yamlMap) {
    return yamlMap.map(
      (key, value) => MapEntry(key.toString(), _toPlainValue(value)),
    );
  }

  Object? _toPlainValue(Object? value) {
    if (value is YamlMap) {
      return _toPlainMap(value);
    }
    if (value is YamlList) {
      return value.map(_toPlainValue).toList();
    }
    return value;
  }

  String _requiredString(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw FormatException('Missing required string field: $key');
  }

  int _requiredInt(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is int) {
      return value;
    }
    throw FormatException('Missing required integer field: $key');
  }

  List<String> _stringList(Object? value) {
    if (value == null) {
      return const [];
    }
    if (value is! List) {
      throw const FormatException('Expected list');
    }
    return value.map((entry) => entry.toString()).toList(growable: false);
  }

  List<PageSequenceEntry> _pageSequence(Object? value) {
    if (value == null) {
      return const [];
    }
    if (value is! List) {
      throw const FormatException('page_sequence must be a list');
    }
    return value.map((entry) {
      if (entry is! Map) {
        throw const FormatException('page_sequence entries must be maps');
      }
      final page = entry['page'];
      if (page is! int || page < 1) {
        throw const FormatException('page_sequence page must be 1-origin');
      }
      return PageSequenceEntry(
        page: page,
        label: entry['label'] as String?,
      );
    }).toList(growable: false);
  }
}

class ScoreValidationIssue {
  const ScoreValidationIssue(this.message);

  final String message;
}

class ScoreValidator {
  const ScoreValidator();

  List<ScoreValidationIssue> validate({
    required Score score,
    required int pageCount,
    required bool currentVersionPdfExists,
    required bool Function(String artistId) artistExists,
  }) {
    final issues = <ScoreValidationIssue>[];
    if (score.id.isEmpty) {
      issues.add(const ScoreValidationIssue('Score id is required'));
    }
    if (score.title.trim().isEmpty) {
      issues.add(const ScoreValidationIssue('Title is required'));
    }
    if (!currentVersionPdfExists) {
      issues.add(const ScoreValidationIssue('Current version PDF is missing'));
    }
    for (final artistId in score.artistIds) {
      if (!artistExists(artistId)) {
        issues.add(ScoreValidationIssue('Dangling artist_id: $artistId'));
      }
    }
    for (final entry in score.pageSequence) {
      if (entry.page < 1 || entry.page > pageCount) {
        issues.add(
          ScoreValidationIssue('Invalid page_sequence page: ${entry.page}'),
        );
      }
    }
    return issues;
  }
}

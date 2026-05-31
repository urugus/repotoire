import 'package:flutter_test/flutter_test.dart';
import 'package:repotoire/domain/score_yaml_codec.dart';

void main() {
  test('decodes score metadata and preserves unknown fields', () {
    const source = '''
schema_version: 1
id: 01JTEST
title: Nocturne
artist_ids:
  - 01JARTIST
tags:
  - piano
key: Es-dur
current_version: 01JVERSION
page_sequence:
  - page: 1
  - page: 2
    label: repeat
deleted_at: null
created_at: 2026-05-31T00:00:00Z
future_field: keep-me
''';

    final score = const ScoreYamlCodec().decode(source);

    expect(score.id, '01JTEST');
    expect(score.pageSequence.last.label, 'repeat');
    expect(score.extra['future_field'], 'keep-me');
  });
}

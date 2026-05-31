import 'package:flutter_test/flutter_test.dart';
import 'package:repotoire/domain/repository_layout.dart';

void main() {
  test('uses the public GitHub repository layout contract', () {
    const layout = RepositoryLayout();

    expect(layout.libraryPath, 'library.yml');
    expect(layout.artistPath('artist1'), 'artists/artist1.yml');
    expect(layout.scoreMetadataPath('score1'), 'scores/score1/score.yml');
    expect(
      layout.scoreVersionPath('score1', 'version1'),
      'scores/score1/versions/version1.pdf',
    );
    expect(
      layout.annotationPath('score1', 'version1'),
      'scores/score1/annotations/version1.json',
    );
  });
}

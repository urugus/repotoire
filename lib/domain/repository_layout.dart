class RepositoryLayout {
  const RepositoryLayout();

  String get libraryPath => 'library.yml';

  String artistPath(String artistId) => 'artists/$artistId.yml';

  String scoreMetadataPath(String scoreId) => 'scores/$scoreId/score.yml';

  String scoreVersionPath(String scoreId, String versionId) =>
      'scores/$scoreId/versions/$versionId.pdf';

  String annotationPath(String scoreId, String versionId) =>
      'scores/$scoreId/annotations/$versionId.json';
}

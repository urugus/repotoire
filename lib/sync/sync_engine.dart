import '../data/github/github_git_database_client.dart';
import '../data/github/github_models.dart';
import '../domain/repository_layout.dart';

class SyncManifest {
  const SyncManifest({
    required this.headSha,
    required this.treeSha,
    required this.entriesByPath,
  });

  final String headSha;
  final String treeSha;
  final Map<String, GitTreeEntry> entriesByPath;
}

class PullSyncService {
  PullSyncService({
    required GitHubGitDatabaseClient github,
    RepositoryLayout repositoryLayout = const RepositoryLayout(),
  })  : _github = github,
        _repositoryLayout = repositoryLayout;

  final GitHubGitDatabaseClient _github;
  final RepositoryLayout _repositoryLayout;

  Future<SyncManifest> fetchManifest({String branch = 'main'}) async {
    final headSha = await _github.getHeadSha(branch: branch);
    final commit = await _github.getCommit(headSha);
    final tree = await _github.getRecursiveTree(commit.treeSha);
    if (tree.truncated) {
      throw StateError('Recursive tree response was truncated');
    }
    final relevantEntries = <String, GitTreeEntry>{};
    for (final entry in tree.entries) {
      if (_isRepositoryDataPath(entry.path)) {
        relevantEntries[entry.path] = entry;
      }
    }
    return SyncManifest(
      headSha: headSha,
      treeSha: commit.treeSha,
      entriesByPath: relevantEntries,
    );
  }

  bool _isRepositoryDataPath(String path) {
    return path == _repositoryLayout.libraryPath ||
        path.startsWith('artists/') ||
        path.startsWith('scores/');
  }
}

class GitTreeWriteEntry {
  const GitTreeWriteEntry({
    required this.path,
    required this.sha,
    this.mode = '100644',
    this.type = 'blob',
  });

  final String path;
  final String sha;
  final String mode;
  final String type;

  Map<String, Object?> toJson() => {
        'path': path,
        'mode': mode,
        'type': type,
        'sha': sha,
      };
}

class PushCommitRequest {
  const PushCommitRequest({
    required this.message,
    required this.baseHeadSha,
    required this.baseTreeSha,
    required this.entries,
  });

  final String message;
  final String baseHeadSha;
  final String baseTreeSha;
  final List<GitTreeWriteEntry> entries;
}

class PushSyncService {
  PushSyncService({required GitHubGitDatabaseClient github}) : _github = github;

  final GitHubGitDatabaseClient _github;

  Future<String> commitAtomically(PushCommitRequest request) async {
    final treeSha = await _github.createTree(
      baseTreeSha: request.baseTreeSha,
      entries: request.entries.map((entry) => entry.toJson()).toList(),
    );
    final commitSha = await _github.createCommit(
      message: request.message,
      treeSha: treeSha,
      parentSha: request.baseHeadSha,
    );
    await _github.updateRef(commitSha: commitSha, force: false);
    return commitSha;
  }
}

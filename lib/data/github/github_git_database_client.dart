import 'dart:convert';

import 'package:dio/dio.dart';

import 'github_models.dart';

class GitHubGitDatabaseClient {
  GitHubGitDatabaseClient({
    required Dio dio,
    required this.owner,
    required this.repo,
  }) : _dio = dio;

  final Dio _dio;
  final String owner;
  final String repo;

  String get _repoPath => '/repos/$owner/$repo';

  Future<String> getHeadSha({String branch = 'main'}) async {
    final response = await _dio.get<Map<String, Object?>>(
      '$_repoPath/git/ref/heads/$branch',
    );
    final object = response.data?['object'] as Map<String, Object?>?;
    final sha = object?['sha'] as String?;
    if (sha == null) {
      throw const FormatException('GitHub ref response did not contain sha');
    }
    return sha;
  }

  Future<GitCommit> getCommit(String commitSha) async {
    final response = await _dio.get<Map<String, Object?>>(
      '$_repoPath/git/commits/$commitSha',
    );
    final data = response.data;
    final tree = data?['tree'] as Map<String, Object?>?;
    final treeSha = tree?['sha'] as String?;
    if (data == null || treeSha == null) {
      throw const FormatException('GitHub commit response was incomplete');
    }
    return GitCommit(sha: data['sha'] as String, treeSha: treeSha);
  }

  Future<GitTree> getRecursiveTree(String treeSha) async {
    final response = await _dio.get<Map<String, Object?>>(
      '$_repoPath/git/trees/$treeSha',
      queryParameters: {'recursive': '1'},
    );
    final data = response.data;
    final entries = (data?['tree'] as List<dynamic>? ?? const [])
        .cast<Map<String, Object?>>()
        .map(
          (entry) => GitTreeEntry(
            path: entry['path'] as String,
            mode: entry['mode'] as String,
            type: entry['type'] as String,
            sha: entry['sha'] as String,
            size: entry['size'] as int?,
          ),
        )
        .toList(growable: false);
    return GitTree(
      sha: data?['sha'] as String,
      entries: entries,
      truncated: data?['truncated'] as bool? ?? false,
    );
  }

  Future<String> createBlob({
    required List<int> bytes,
    String encoding = 'base64',
  }) async {
    final content = encoding == 'base64' ? base64Encode(bytes) : utf8.decode(bytes);
    final response = await _dio.post<Map<String, Object?>>(
      '$_repoPath/git/blobs',
      data: {
        'content': content,
        'encoding': encoding,
      },
    );
    final sha = response.data?['sha'] as String?;
    if (sha == null) {
      throw const FormatException('GitHub create blob response missed sha');
    }
    return sha;
  }

  Future<String> createTree({
    required String baseTreeSha,
    required List<Map<String, Object?>> entries,
  }) async {
    final response = await _dio.post<Map<String, Object?>>(
      '$_repoPath/git/trees',
      data: {
        'base_tree': baseTreeSha,
        'tree': entries,
      },
    );
    final sha = response.data?['sha'] as String?;
    if (sha == null) {
      throw const FormatException('GitHub create tree response missed sha');
    }
    return sha;
  }

  Future<String> createCommit({
    required String message,
    required String treeSha,
    required String parentSha,
  }) async {
    final response = await _dio.post<Map<String, Object?>>(
      '$_repoPath/git/commits',
      data: {
        'message': message,
        'tree': treeSha,
        'parents': [parentSha],
      },
    );
    final sha = response.data?['sha'] as String?;
    if (sha == null) {
      throw const FormatException('GitHub create commit response missed sha');
    }
    return sha;
  }

  Future<void> updateRef({
    required String commitSha,
    String branch = 'main',
    bool force = false,
  }) async {
    await _dio.patch<Map<String, Object?>>(
      '$_repoPath/git/refs/heads/$branch',
      data: {
        'sha': commitSha,
        'force': force,
      },
    );
  }

  Future<List<int>> getRawBlob(String blobSha) async {
    final response = await _dio.get<List<int>>(
      '$_repoPath/git/blobs/$blobSha',
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Accept': 'application/vnd.github.raw'},
      ),
    );
    return response.data ?? const [];
  }
}

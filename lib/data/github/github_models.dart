class GitTreeEntry {
  const GitTreeEntry({
    required this.path,
    required this.mode,
    required this.type,
    required this.sha,
    this.size,
  });

  final String path;
  final String mode;
  final String type;
  final String sha;
  final int? size;
}

class GitTree {
  const GitTree({
    required this.sha,
    required this.entries,
    required this.truncated,
  });

  final String sha;
  final List<GitTreeEntry> entries;
  final bool truncated;
}

class GitCommit {
  const GitCommit({
    required this.sha,
    required this.treeSha,
  });

  final String sha;
  final String treeSha;
}

class DeviceCodeResponse {
  const DeviceCodeResponse({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.expiresIn,
    required this.interval,
  });

  final String deviceCode;
  final String userCode;
  final Uri verificationUri;
  final int expiresIn;
  final int interval;
}

class GitHubTokenSet {
  const GitHubTokenSet({
    required this.accessToken,
    this.refreshToken,
    this.expiresIn,
    this.refreshTokenExpiresIn,
  });

  final String accessToken;
  final String? refreshToken;
  final int? expiresIn;
  final int? refreshTokenExpiresIn;
}

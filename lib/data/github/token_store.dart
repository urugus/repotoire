import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'github_models.dart';

class GitHubTokenStore {
  GitHubTokenStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  static const _accessTokenKey = 'github.access_token';
  static const _refreshTokenKey = 'github.refresh_token';
  static const _accessTokenExpiresAtKey = 'github.access_token_expires_at';
  static const _refreshTokenExpiresAtKey = 'github.refresh_token_expires_at';

  final FlutterSecureStorage _storage;

  Future<void> save(GitHubTokenSet tokenSet, {DateTime? now}) async {
    final clock = now ?? DateTime.now().toUtc();
    await _storage.write(key: _accessTokenKey, value: tokenSet.accessToken);
    if (tokenSet.refreshToken != null) {
      await _storage.write(key: _refreshTokenKey, value: tokenSet.refreshToken);
    }
    if (tokenSet.expiresIn != null) {
      await _storage.write(
        key: _accessTokenExpiresAtKey,
        value: clock.add(Duration(seconds: tokenSet.expiresIn!)).toIso8601String(),
      );
    }
    if (tokenSet.refreshTokenExpiresIn != null) {
      await _storage.write(
        key: _refreshTokenExpiresAtKey,
        value: clock
            .add(Duration(seconds: tokenSet.refreshTokenExpiresIn!))
            .toIso8601String(),
      );
    }
  }

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<bool> isAccessTokenExpired({DateTime? now}) async {
    final expiresAt = await _storage.read(key: _accessTokenExpiresAtKey);
    if (expiresAt == null) {
      return true;
    }
    final clock = now ?? DateTime.now().toUtc();
    return clock.isAfter(DateTime.parse(expiresAt));
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _accessTokenExpiresAtKey);
    await _storage.delete(key: _refreshTokenExpiresAtKey);
  }
}

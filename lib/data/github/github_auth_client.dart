import 'package:dio/dio.dart';

import 'github_models.dart';

class GitHubAuthClient {
  GitHubAuthClient({
    required Dio dio,
    required this.clientId,
  }) : _dio = dio;

  final Dio _dio;
  final String clientId;

  Future<DeviceCodeResponse> requestDeviceCode() async {
    final response = await _dio.post<Map<String, Object?>>(
      'https://github.com/login/device/code',
      data: {
        'client_id': clientId,
        'scope': 'repo',
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {'Accept': 'application/json'},
      ),
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('GitHub device code response was empty');
    }
    return DeviceCodeResponse(
      deviceCode: data['device_code'] as String,
      userCode: data['user_code'] as String,
      verificationUri: Uri.parse(data['verification_uri'] as String),
      expiresIn: data['expires_in'] as int,
      interval: data['interval'] as int,
    );
  }

  Future<GitHubTokenSet> pollToken(String deviceCode) async {
    final response = await _dio.post<Map<String, Object?>>(
      'https://github.com/login/oauth/access_token',
      data: {
        'client_id': clientId,
        'device_code': deviceCode,
        'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {'Accept': 'application/json'},
      ),
    );
    final data = response.data;
    if (data == null || data['access_token'] == null) {
      final error = data?['error'] ?? 'unknown_error';
      throw StateError(error.toString());
    }
    return GitHubTokenSet(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String?,
      expiresIn: data['expires_in'] as int?,
      refreshTokenExpiresIn: data['refresh_token_expires_in'] as int?,
    );
  }

  Future<GitHubTokenSet> refresh(String refreshToken) async {
    final response = await _dio.post<Map<String, Object?>>(
      'https://github.com/login/oauth/access_token',
      data: {
        'client_id': clientId,
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {'Accept': 'application/json'},
      ),
    );
    final data = response.data;
    if (data == null || data['access_token'] == null) {
      throw StateError((data?['error'] ?? 'refresh_failed').toString());
    }
    return GitHubTokenSet(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String?,
      expiresIn: data['expires_in'] as int?,
      refreshTokenExpiresIn: data['refresh_token_expires_in'] as int?,
    );
  }
}

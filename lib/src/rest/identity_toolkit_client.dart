import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../firebase_auth_kit_config.dart';
import '../platform_interface/firebase_auth_exception.dart';
import 'auth_error_codes.dart';

/// The result of exchanging a refresh token at the Secure Token service.
class TokenResponse {
  const TokenResponse({
    required this.idToken,
    required this.refreshToken,
    required this.expiresIn,
    this.userId,
  });

  final String idToken;
  final String refreshToken;
  final Duration expiresIn;
  final String? userId;
}

/// A thin HTTP client for the Identity Toolkit (v1 / v2) and Secure Token
/// APIs, with emulator routing and FlutterFire-compatible error mapping.
class IdentityToolkitClient {
  IdentityToolkitClient({
    required this.apiKey,
    http.Client? httpClient,
    this.emulatorOrigin,
  }) : _httpClient = httpClient;

  static const _v1Host = 'https://identitytoolkit.googleapis.com/v1/';
  static const _v2Host = 'https://identitytoolkit.googleapis.com/v2/';
  static const _tokenHost = 'https://securetoken.googleapis.com/v1/token';

  /// The web API key sent as `key=` on every request.
  final String apiKey;

  /// `http://host:port` of the Auth emulator, or `null` for production.
  String? emulatorOrigin;

  /// Sent as `X-Firebase-Locale` when set (email / SMS template language).
  String? languageCode;

  /// Included as `tenantId` in request bodies when set.
  String? tenantId;

  final http.Client? _httpClient;
  http.Client? _ownedClient;

  http.Client get _client {
    final configured = FirebaseAuthKit.httpClient;
    if (configured != null) return configured;
    if (_httpClient != null) return _httpClient;
    return _ownedClient ??= http.Client();
  }

  bool get usesEmulator => emulatorOrigin != null;

  /// `accounts:signInWithPassword` → the full v1 URL.
  Uri v1(String method) => _uri(_v1Host, method);

  /// `accounts/mfaEnrollment:start` → the full v2 URL.
  Uri v2(String method) => _uri(_v2Host, method);

  Uri _uri(String host, String path) {
    var base = host;
    if (emulatorOrigin != null) {
      base = '$emulatorOrigin/${host.substring('https://'.length)}';
    }
    return Uri.parse('$base$path').replace(queryParameters: {'key': apiKey});
  }

  Uri get _tokenUri {
    var base = _tokenHost;
    if (emulatorOrigin != null) {
      base = '$emulatorOrigin/${_tokenHost.substring('https://'.length)}';
    }
    return Uri.parse(base).replace(queryParameters: {'key': apiKey});
  }

  /// POSTs [body] as JSON to [uri] and returns the decoded JSON object.
  ///
  /// Throws [FirebaseAuthException] for error responses and network failures.
  Future<Map<String, Object?>> post(
    Uri uri,
    Map<String, Object?> body, {
    Map<String, String>? headers,
    bool includeTenant = true,
  }) async {
    final payload = _stripNulls(body);
    if (includeTenant && tenantId != null) payload['tenantId'] = tenantId;
    final requestHeaders = <String, String>{
      'Content-Type': 'application/json',
      'X-Client-Version': 'Dart/firebase_auth_kit/0.1.0',
      'X-Firebase-Locale': ?languageCode,
      ...?headers,
    };
    http.Response response;
    try {
      response = await _client.post(
        uri,
        headers: requestHeaders,
        body: jsonEncode(payload),
      );
    } on SocketException catch (e) {
      throw _networkError(uri, e);
    } on http.ClientException catch (e) {
      throw _networkError(uri, e);
    } on HandshakeException catch (e) {
      throw _networkError(uri, e);
    } on TimeoutException catch (e) {
      throw _networkError(uri, e);
    }
    _log('POST', uri, response.statusCode);
    return _decode(response);
  }

  /// GETs [uri] and returns the decoded JSON object.
  Future<Map<String, Object?>> get(Uri uri) async {
    http.Response response;
    try {
      response = await _client.get(uri, headers: {
        'X-Client-Version': 'Dart/firebase_auth_kit/0.1.0',
      });
    } on SocketException catch (e) {
      throw _networkError(uri, e);
    } on http.ClientException catch (e) {
      throw _networkError(uri, e);
    }
    _log('GET', uri, response.statusCode);
    return _decode(response);
  }

  /// Exchanges [refreshToken] for a fresh ID token.
  Future<TokenResponse> refreshIdToken(String refreshToken) async {
    final uri = _tokenUri;
    http.Response response;
    try {
      response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'X-Client-Version': 'Dart/firebase_auth_kit/0.1.0',
        },
        body: 'grant_type=refresh_token&refresh_token='
            '${Uri.encodeQueryComponent(refreshToken)}',
      );
    } on SocketException catch (e) {
      throw _networkError(uri, e);
    } on http.ClientException catch (e) {
      throw _networkError(uri, e);
    }
    _log('POST', uri, response.statusCode);
    final json = _decode(response);
    final expiresIn = int.tryParse(json['expires_in']?.toString() ?? '') ?? 3600;
    return TokenResponse(
      idToken: json['id_token'] as String,
      refreshToken: (json['refresh_token'] as String?) ?? refreshToken,
      expiresIn: Duration(seconds: expiresIn),
      userId: json['user_id'] as String?,
    );
  }

  /// Removes `null` values (recursively) so optional fields are omitted
  /// rather than sent as JSON null, which the API rejects.
  static Map<String, Object?> _stripNulls(Map<String, Object?> body) {
    final result = <String, Object?>{};
    for (final entry in body.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is Map<String, Object?>) {
        result[entry.key] = _stripNulls(value);
      } else if (value is Map) {
        result[entry.key] = _stripNulls(Map<String, Object?>.from(value));
      } else {
        result[entry.key] = value;
      }
    }
    return result;
  }

  Map<String, Object?> _decode(http.Response response) {
    Object? decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        decoded = null;
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map) return Map<String, Object?>.from(decoded);
      return <String, Object?>{};
    }
    throw exceptionFromErrorResponse(response.statusCode, decoded);
  }

  /// Builds the [FirebaseAuthException] for a non-2xx Identity Toolkit reply.
  static FirebaseAuthException exceptionFromErrorResponse(
    int statusCode,
    Object? decoded,
  ) {
    String? rawMessage;
    if (decoded is Map) {
      final error = decoded['error'];
      if (error is Map) {
        rawMessage = error['message']?.toString();
        final errors = error['errors'];
        if (rawMessage == null && errors is List && errors.isNotEmpty) {
          final first = errors.first;
          if (first is Map) rawMessage = first['message']?.toString();
        }
      } else if (error is String) {
        rawMessage = error;
      }
    }
    if (rawMessage == null || rawMessage.isEmpty) {
      return FirebaseAuthException(
        code: statusCode == 401 || statusCode == 403
            ? 'invalid-api-key'
            : 'internal-error',
        message: 'The Identity Toolkit API returned HTTP $statusCode.',
      );
    }
    final split = splitServerMessage(rawMessage);
    final code = authErrorCodeFor(split.serverCode);
    return FirebaseAuthException(
      code: code,
      message: split.detail ?? kDefaultErrorMessages[code] ?? rawMessage,
    );
  }

  FirebaseAuthException _networkError(Uri uri, Object cause) {
    _log('FAIL', uri, null, cause);
    return FirebaseAuthException(
      code: 'network-request-failed',
      message: '${kDefaultErrorMessages['network-request-failed']} ($cause)',
    );
  }

  void _log(String method, Uri uri, int? status, [Object? error]) {
    final logger = FirebaseAuthKit.logger;
    if (logger == null) return;
    final redacted = uri.replace(queryParameters: {'key': '<redacted>'});
    logger('[firebase_auth_kit] $method ${redacted.path} '
        '${status ?? ''}${error == null ? '' : ' $error'}');
  }

  /// Releases the client this instance created, if any.
  void close() {
    _ownedClient?.close();
    _ownedClient = null;
  }
}

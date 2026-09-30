import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../firebase_auth_kit_config.dart';
import '../platform_interface.dart';
import '../rest/auth_error_codes.dart';

/// Shows [url] to the user in an in-app web view and completes with the first
/// URL for which [isCallback] returns true. Complete with `null` if the user
/// closed the page without finishing.
///
/// Check [isCallback] on every URL the web view reports: navigation requests
/// (where the custom-scheme redirect arrives with dartnative_webview 1.0.1+)
/// and page loads alike, since a web view that only reports page loads
/// (dartnative_webview 1.0.0) still lets the kit recognise the callback from
/// the handler page. The README section "The web-view screen" shows the screen.
typedef WebFlowPresenter = Future<Uri?> Function(
  Uri url, {
  required bool Function(Uri candidate) isCallback,
});

/// Where a web flow completes.
///
/// Two shapes count as the callback:
///
/// 1. The custom-scheme URL the Firebase handler redirects to at the end
///    (`app-<appId>://firebaseauth/link?deep_link_id=…`, or an `intent://`
///    URL on Android). Any URL whose scheme is not `http` / `https` qualifies.
/// 2. The handler page itself once the identity provider has sent the user
///    back to it with a response (`…/__/auth/handler?state=…&code=…`,
///    `…&id_token=…`, or `…&firebaseError=…`). That page is what the handler
///    wraps into the deep link, so a web view that only reports page loads
///    (not navigation requests) can still complete the flow from it.
bool isFirebaseCallbackUrl(Uri candidate) {
  final scheme = candidate.scheme.toLowerCase();
  if (scheme.isEmpty) return false;
  if (scheme != 'http' && scheme != 'https') {
    return scheme != 'about' &&
        scheme != 'data' &&
        scheme != 'blob' &&
        scheme != 'javascript';
  }
  return isHandlerResponseUrl(candidate);
}

/// Whether [url] is the auth handler page carrying a provider response.
bool isHandlerResponseUrl(Uri url) {
  final path = url.path;
  if (!path.endsWith('/__/auth/handler') &&
      !path.endsWith('/emulator/auth/handler') &&
      !path.endsWith('/__/auth/callback')) {
    return false;
  }
  final q = url.queryParameters;
  if (q.containsKey('firebaseError')) return true;
  if (q.containsKey('link') || q.containsKey('deep_link_id')) return true;
  if (q.containsKey('recaptchaToken')) return true;
  final hasProviderResponse = q.containsKey('code') ||
      q.containsKey('id_token') ||
      q.containsKey('access_token') ||
      q.containsKey('oauth_token') ||
      q.containsKey('SAMLResponse');
  // The initial handler request carries apiKey/authType but no response yet.
  return hasProviderResponse && (q.containsKey('state') || q.containsKey('providerId'));
}

/// The parsed result of a Firebase auth handler callback.
class WebFlowResult {
  WebFlowResult({this.link, this.error, this.recaptchaToken});

  /// The provider response URL (`link`), to send as `requestUri`.
  final String? link;

  /// The `firebaseError` the handler reported, if any.
  final FirebaseAuthException? error;

  /// The reCAPTCHA token of an app-verification flow, if any.
  final String? recaptchaToken;
}

/// Parses the custom-scheme URL the Firebase auth handler redirects to.
///
/// iOS style: `<scheme>://firebaseauth/link?deep_link_id=<callback url>` where
/// the callback URL is `https://<authDomain>/__/auth/callback?authType=…&link=<url response>`.
/// Android style (an `intent://` URL) carries the same fields as `S.link=` and
/// `S.firebaseError=` segments.
WebFlowResult parseFirebaseCallback(Uri callback) {
  final scheme = callback.scheme.toLowerCase();
  if ((scheme == 'http' || scheme == 'https') &&
      isHandlerResponseUrl(callback) &&
      !callback.queryParameters.containsKey('link') &&
      !callback.queryParameters.containsKey('deep_link_id')) {
    // The handler page with the provider's response: this URL *is* the link.
    final q = callback.queryParameters;
    final rawError = q['firebaseError'];
    return WebFlowResult(
      link: callback.toString(),
      recaptchaToken: q['recaptchaToken'],
      error: rawError == null || rawError.isEmpty ? null : _parseFirebaseError(rawError),
    );
  }
  String? deepLink = callback.queryParameters['deep_link_id'] ??
      callback.queryParameters['link'];
  String? firebaseError = callback.queryParameters['firebaseError'];
  if (callback.scheme == 'intent') {
    // intent://firebase.auth/#Intent;scheme=genericidp;S.link=...;S.firebaseError=...;end;
    final fragment = Uri.decodeComponent(callback.fragment);
    for (final part in fragment.split(';')) {
      if (part.startsWith('S.link=')) {
        deepLink = Uri.decodeComponent(part.substring('S.link='.length));
      } else if (part.startsWith('S.firebaseError=')) {
        firebaseError = Uri.decodeComponent(part.substring('S.firebaseError='.length));
      }
    }
  }
  String? link = deepLink;
  String? recaptchaToken;
  if (deepLink != null) {
    final inner = Uri.tryParse(deepLink);
    if (inner != null) {
      link = inner.queryParameters['link'] ?? deepLink;
      firebaseError ??= inner.queryParameters['firebaseError'];
      recaptchaToken = inner.queryParameters['recaptchaToken'];
      final response = Uri.tryParse(link);
      if (response != null) {
        recaptchaToken ??= response.queryParameters['recaptchaToken'];
        firebaseError ??= response.queryParameters['firebaseError'];
      }
    }
  }
  FirebaseAuthException? error;
  if (firebaseError != null && firebaseError.isNotEmpty) {
    error = _parseFirebaseError(firebaseError);
  }
  return WebFlowResult(link: link, error: error, recaptchaToken: recaptchaToken);
}

FirebaseAuthException _parseFirebaseError(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      final code = (decoded['code'] as String? ?? 'unknown').replaceFirst('auth/', '');
      return FirebaseAuthException(
        code: code,
        message: decoded['message'] as String? ?? kDefaultErrorMessages[code],
      );
    }
  } on FormatException {
    // fall through
  }
  final split = splitServerMessage(raw);
  final code = authErrorCodeFor(split.serverCode);
  return FirebaseAuthException(code: code, message: split.detail ?? raw);
}

/// Builds the URLs of the Firebase-hosted auth handler
/// (`https://<authDomain>/__/auth/handler`, or the emulator's
/// `/emulator/auth/handler`) for the mobile redirect flows the iOS SDK uses.
class FirebaseAuthHandler {
  FirebaseAuthHandler({
    required this.apiKey,
    required this.appName,
    required this.authDomain,
    this.appId,
    this.iosBundleId,
    this.androidPackageName,
    this.tenantId,
    this.languageCode,
    this.emulatorOrigin,
  });

  final String apiKey;
  final String appName;

  /// `<project>.firebaseapp.com` unless the app set `customAuthDomain`.
  final String authDomain;
  final String? appId;
  final String? iosBundleId;
  final String? androidPackageName;
  final String? tenantId;
  final String? languageCode;

  /// `http://host:port` of the Auth emulator, or `null` for production.
  final String? emulatorOrigin;

  static const _version = 'Dart/firebase_auth_kit/0.1.0';

  Uri get _handlerBase {
    final origin = emulatorOrigin;
    if (origin != null) return Uri.parse('$origin/emulator/auth/handler');
    return Uri.parse('https://$authDomain/__/auth/handler');
  }

  Map<String, String> _commonParams(String authType, String eventId) {
    return <String, String>{
      'apiKey': apiKey,
      'appName': appName,
      'authType': authType,
      'v': _version,
      'eventId': eventId,
      'appId': ?appId,
      // The handler needs an app identity to decide how to redirect; iOS
      // style deep links (`ibi`) are the ones the kit parses, so prefer them
      // even on Android.
      'ibi': iosBundleId ?? androidPackageName ?? 'firebase_auth_kit',
      'tid': ?tenantId,
      'hl': ?languageCode,
    };
  }

  /// The URL that signs in with [provider] and redirects back with the
  /// provider response. [sessionIdHash] is the SHA-256 hex of the nonce that
  /// is later sent to `signInWithIdp` as `sessionId`.
  Uri signInWithRedirectUrl({
    required String providerId,
    required String sessionIdHash,
    required String eventId,
    List<String> scopes = const [],
    Map<String, String> customParameters = const {},
  }) {
    return _handlerBase.replace(queryParameters: {
      ..._commonParams('signInWithRedirect', eventId),
      'providerId': providerId,
      'sessionId': sessionIdHash,
      if (scopes.isNotEmpty) 'scopes': scopes.join(','),
      if (customParameters.isNotEmpty) 'customParameters': jsonEncode(customParameters),
    });
  }

  /// The URL that runs reCAPTCHA app verification for phone authentication
  /// and redirects back with `recaptchaToken`.
  Uri verifyAppUrl({required String eventId}) {
    return _handlerBase.replace(queryParameters: _commonParams('verifyApp', eventId));
  }
}

/// A random URL-safe string of [length] characters.
String randomToken([int length = 32]) {
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = Random.secure();
  return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
}

/// SHA-256 of [value] as lowercase hex (what the handler expects in `sessionId`).
String sha256Hex(String value) => sha256.convert(utf8.encode(value)).toString();

/// The scopes and custom parameters carried by any of the provider classes.
({List<String> scopes, Map<String, String> parameters}) providerOptions(
  AuthProvider provider,
) {
  List<String> scopes = const [];
  Map<String, String> parameters = const {};
  if (provider is OAuthProvider) {
    scopes = provider.scopes;
    parameters = _stringMap(provider.parameters);
  } else if (provider is GoogleAuthProvider) {
    scopes = provider.scopes;
    parameters = _stringMap(provider.parameters);
  } else if (provider is AppleAuthProvider) {
    scopes = provider.scopes;
    parameters = _stringMap(provider.parameters);
  } else if (provider is FacebookAuthProvider) {
    scopes = provider.scopes;
    parameters = _stringMap(provider.parameters);
  } else if (provider is GithubAuthProvider) {
    scopes = provider.scopes;
    parameters = _stringMap(provider.parameters);
  } else if (provider is MicrosoftAuthProvider) {
    scopes = provider.scopes;
    parameters = _stringMap(provider.parameters);
  } else if (provider is YahooAuthProvider) {
    scopes = provider.scopes;
    parameters = _stringMap(provider.parameters);
  } else if (provider is TwitterAuthProvider) {
    parameters = _stringMap(provider.parameters);
  } else if (provider is GameCenterAuthProvider) {
    parameters = _stringMap(provider.parameters);
  }
  return (scopes: scopes, parameters: parameters);
}

Map<String, String> _stringMap(Map<dynamic, dynamic> map) => {
      for (final entry in map.entries) '${entry.key}': '${entry.value}',
    };

/// The Android package name of the running app, from `/proc/self/cmdline`.
String? currentAndroidPackageName() {
  if (!Platform.isAndroid) return null;
  try {
    final raw = File('/proc/self/cmdline').readAsStringSync();
    final name = raw.split('\u0000').first.split(':').first.trim();
    return name.isEmpty ? null : name;
  } on FileSystemException {
    return null;
  }
}

/// Runs [url] through [FirebaseAuthKit.webFlowPresenter] and parses the
/// callback. Throws `web-flow-unavailable` when no presenter is configured and
/// `user-cancelled` when the page was dismissed.
Future<WebFlowResult> runWebFlow(Uri url, {required String operation}) async {
  final presenter = FirebaseAuthKit.webFlowPresenter;
  if (presenter == null) {
    throw FirebaseAuthException(
      code: 'operation-not-supported-in-this-environment',
      message: '$operation needs a web page shown to the user. Set '
          'FirebaseAuthKit.webFlowPresenter (a dozen lines with '
          'dartnative_webview, see the README), or use signInWithCredential '
          'with a token obtained natively.',
    );
  }
  final callback = await presenter(url, isCallback: isFirebaseCallbackUrl);
  if (callback == null) {
    throw FirebaseAuthException(
      code: 'user-cancelled',
      message: 'The user closed the sign-in page.',
    );
  }
  final result = parseFirebaseCallback(callback);
  if (result.error != null) throw result.error!;
  return result;
}

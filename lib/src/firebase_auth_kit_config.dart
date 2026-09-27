import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'platform_interface.dart';
import 'errors/firebase_auth_error_code.dart';
import 'errors/firebase_auth_exception_extensions.dart';
import 'rest/auth_persistence.dart';
import 'rest/secure_storage_auth_persistence.dart';
import 'web/web_flow.dart';
import '../firebase_auth_kit.dart' show FirebaseAuth;

/// Asks the app for a reCAPTCHA (or reCAPTCHA Enterprise) token that proves
/// the phone-number request comes from a real client.
///
/// Called by `verifyPhoneNumber`, `signInWithPhoneNumber`,
/// `linkWithPhoneNumber` and phone multi-factor enrolment when app
/// verification is enabled. Return the token string.
typedef RecaptchaTokenProvider = Future<String> Function(
  FirebaseAuthPlatform auth,
);

/// Runs a browser-based OAuth flow for [provider] and returns the resulting
/// credential (for example from `dartnative_webview` or a system browser plus
/// `app_links_kit`), so that `signInWithProvider`, `linkWithProvider` and
/// `reauthenticateWithProvider` can complete.
typedef OAuthFlowHandler = Future<AuthCredential> Function(
  FirebaseAuthPlatform auth,
  AuthProvider provider,
);

/// Opens [url] in an external application (used by `TotpSecret.openInOtpApp`).
typedef UrlLauncher = Future<void> Function(Uri url);

/// Stores sessions in [storage] (for example `SecureStorage()` from
/// `dartnative_secure_storage`) and waits until the session persisted by a
/// previous launch has been restored, so that `FirebaseAuth.instance
/// .currentUser` is populated when it returns.
///
/// ```dart
/// void main() async {
///   DartNativePluginRegistrant.registerAll();
///   await installSecureAuthPersistence(SecureStorage());
///   runApp(const MyApp());
/// }
/// ```
///
/// Pass [restoreDefaultApp] as `false` when the default Firebase app cannot be
/// resolved yet; the setting still applies to every instance created later.
Future<void> installSecureAuthPersistence(
  Object storage, {
  bool restoreDefaultApp = true,
}) async {
  FirebaseAuthKit.persistence = SecureStorageAuthPersistence(storage);
  if (restoreDefaultApp) {
    await FirebaseAuth.instance.authStateReady();
  }
}

/// Package-level configuration for `firebase_auth_kit`.
///
/// Everything here is optional; the defaults give you a working
/// `FirebaseAuth.instance` with sessions persisted to the app's private
/// storage directory. Set values before the first `FirebaseAuth` access.
///
/// ```dart
/// // Keep the session in the Keychain / EncryptedSharedPreferences instead of a file:
/// await installSecureAuthPersistence(SecureStorage()); // dartnative_secure_storage
///
/// // Point file persistence at the directory dartnative_path_provider resolves:
/// FirebaseAuthKit.storageDirectory = Directory(getApplicationSupportDirectory());
/// ```
class FirebaseAuthKit {
  FirebaseAuthKit._();

  /// Where signed-in sessions are stored. Defaults to a
  /// [FileAuthPersistence] rooted at [storageDirectory] (or the platform's
  /// application-support directory when that is `null`).
  ///
  /// Use [SecureStorageAuthPersistence] / [installSecureAuthPersistence] for
  /// `dartnative_secure_storage`, or implement [AuthPersistence] for any
  /// other store.
  static AuthPersistence? persistence;

  /// The directory the default [FileAuthPersistence] writes to.
  ///
  /// When `null`, [FileAuthPersistence.defaultDirectory] picks the
  /// application-support directory on iOS / macOS / Android and a per-user
  /// data directory elsewhere.
  static Directory? storageDirectory;

  /// The HTTP client used for every request. Defaults to a shared
  /// [http.Client]; supply your own for proxies, retries or tests.
  static http.Client? httpClient;

  /// Shows Firebase's hosted sign-in / verification pages inside the app and
  /// returns the callback URL (see [WebFlowPresenter]). With a presenter set,
  /// `signInWithProvider`, `linkWithProvider`, `reauthenticateWithProvider`
  /// and phone authentication against production work without any other
  /// configuration, exactly as the iOS Firebase SDK does them.
  ///
  /// ```dart
  /// FirebaseAuthKit.webFlowPresenter = (url, {required isCallback}) =>
  ///     Navigator.of(context).push(AuthWebPage(url: url, isCallback: isCallback));
  /// ```
  static WebFlowPresenter? webFlowPresenter;

  /// Provides reCAPTCHA tokens for phone authentication against production
  /// projects (see [RecaptchaTokenProvider]). Not needed for the Auth
  /// emulator or when `setSettings(appVerificationDisabledForTesting: true)`
  /// is used with test phone numbers.
  static RecaptchaTokenProvider? recaptchaTokenProvider;

  /// Runs browser-based OAuth for `signInWithProvider` and friends (see
  /// [OAuthFlowHandler]). When `null`, those methods throw
  /// `operation-not-supported-in-this-environment`; use
  /// `signInWithCredential` with a token obtained natively instead.
  static OAuthFlowHandler? oauthFlowHandler;

  /// Opens URLs for `TotpSecret.openInOtpApp`. When `null`, that method
  /// throws [UnimplementedError].
  static UrlLauncher? urlLauncher;

  /// User-facing messages that replace [FirebaseAuthErrorCode.defaultMessage]
  /// in `FirebaseAuthException.userMessage`, for localisation or tone:
  ///
  /// ```dart
  /// FirebaseAuthKit.errorMessages = {
  ///   FirebaseAuthErrorCode.invalidCredential: 'E-mail ou mot de passe incorrect.',
  ///   FirebaseAuthErrorCode.networkRequestFailed: 'Pas de connexion.',
  /// };
  /// ```
  static Map<FirebaseAuthErrorCode, String> errorMessages = {};

  /// A user-presentable description of any error thrown while authenticating;
  /// see `describeAuthError`.
  static String describeError(Object error) => describeAuthError(error);

  /// Receives one line per HTTP request (method, endpoint, status) with
  /// tokens, API keys and passwords redacted. `null` disables logging.
  static void Function(String message)? logger;

  /// Overrides the Auth emulator for every new `FirebaseAuth` instance, as
  /// `host:port`. Defaults to the `FIREBASE_AUTH_EMULATOR_HOST` environment
  /// variable when set, like the Firebase Admin SDKs.
  static String? emulatorHost;

  /// How long before expiry an ID token is refreshed proactively.
  static Duration tokenRefreshThreshold = const Duration(seconds: 30);

  /// Restores every setting to its default (used by tests).
  static void reset() {
    persistence = null;
    storageDirectory = null;
    httpClient = null;
    recaptchaTokenProvider = null;
    oauthFlowHandler = null;
    webFlowPresenter = null;
    urlLauncher = null;
    logger = null;
    emulatorHost = null;
    errorMessages = {};
    tokenRefreshThreshold = const Duration(seconds: 30);
  }
}

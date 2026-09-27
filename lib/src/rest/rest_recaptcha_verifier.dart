import 'dart:math';

import '../firebase_auth_kit_config.dart';
import '../platform_interface.dart';

/// The application verifier used for phone authentication.
///
/// There is no reCAPTCHA widget in a DartNative app, so [verify] returns:
///
/// - nothing to send when the Auth emulator is in use,
/// - a mock token when `setSettings(appVerificationDisabledForTesting: true)`
///   was called (valid for the test phone numbers configured in the Firebase
///   console, exactly like the web SDK's mock reCAPTCHA),
/// - the token from [FirebaseAuthKit.recaptchaTokenProvider] otherwise.
///
/// Without any of those it throws `missing-app-credential`.
class RestRecaptchaVerifierFactory extends RecaptchaVerifierFactoryPlatform {
  RestRecaptchaVerifierFactory() : super();

  RestRecaptchaVerifierFactory._delegate({
    required this.auth,
    this.onSuccess,
    this.onError,
    this.onExpired,
  }) : super();

  /// The auth instance this verifier belongs to.
  FirebaseAuthPlatform? auth;
  RecaptchaVerifierOnSuccess? onSuccess;
  RecaptchaVerifierOnError? onError;
  RecaptchaVerifierOnExpired? onExpired;

  /// Registers this factory as the platform default.
  static void ensureRegistered() {
    try {
      RecaptchaVerifierFactoryPlatform.instance;
    } on UnimplementedError {
      RecaptchaVerifierFactoryPlatform.instance = RestRecaptchaVerifierFactory();
    }
  }

  @override
  RecaptchaVerifierFactoryPlatform delegateFor({
    required FirebaseAuthPlatform auth,
    String? container,
    RecaptchaVerifierSize size = RecaptchaVerifierSize.normal,
    RecaptchaVerifierTheme theme = RecaptchaVerifierTheme.light,
    RecaptchaVerifierOnSuccess? onSuccess,
    RecaptchaVerifierOnError? onError,
    RecaptchaVerifierOnExpired? onExpired,
  }) {
    return RestRecaptchaVerifierFactory._delegate(
      auth: auth,
      onSuccess: onSuccess,
      onError: onError,
      onExpired: onExpired,
    );
  }

  @override
  dynamic get delegate => this;

  @override
  String get type => 'recaptcha';

  @override
  void clear() {}

  @override
  Future<int> render() async => 0;

  /// A token the backend accepts for allow-listed test phone numbers when app
  /// verification is disabled for testing.
  static String mockToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(40, (_) => chars[random.nextInt(chars.length)]).join();
  }

  @override
  Future<String> verify() async {
    final auth = this.auth;
    try {
      final settings = auth is RecaptchaVerifierSettings
          ? (auth as RecaptchaVerifierSettings)
          : null;
      if (settings != null && settings.usesEmulator) {
        onSuccess?.call();
        return '';
      }
      if (settings != null && settings.appVerificationDisabledForTesting) {
        onSuccess?.call();
        return mockToken();
      }
      final provider = FirebaseAuthKit.recaptchaTokenProvider;
      if (provider != null && auth != null) {
        final token = await provider(auth);
        onSuccess?.call();
        return token;
      }
      if (FirebaseAuthKit.webFlowPresenter != null && settings != null) {
        final token = await settings.verifyAppWithHostedRecaptcha();
        onSuccess?.call();
        return token;
      }
      throw FirebaseAuthException(
        code: 'missing-app-credential',
        message: 'Phone authentication needs app verification. Either set '
            'FirebaseAuthKit.webFlowPresenter so the kit can show Firebase\'s '
            'reCAPTCHA page, point FirebaseAuth at the emulator, or call '
            'setSettings(appVerificationDisabledForTesting: true) and use a '
            'test phone number from the Firebase console.',
      );
    } on FirebaseAuthException catch (e) {
      onError?.call(e);
      rethrow;
    }
  }
}

/// The settings a verifier reads off its auth instance.
abstract interface class RecaptchaVerifierSettings {
  bool get usesEmulator;
  bool get appVerificationDisabledForTesting;

  /// Runs Firebase's hosted reCAPTCHA page and returns its token.
  Future<String> verifyAppWithHostedRecaptcha();
}

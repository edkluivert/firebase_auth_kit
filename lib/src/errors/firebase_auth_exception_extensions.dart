import 'dart:async';
import 'dart:io';

import '../firebase_auth_kit_config.dart';
import '../platform_interface/firebase_auth_exception.dart';
import 'firebase_auth_error_code.dart';

/// Typed access to what went wrong, on top of the string [code] FlutterFire
/// exposes.
extension FirebaseAuthExceptionHandling on FirebaseAuthException {
  /// [code] as a [FirebaseAuthErrorCode] ([FirebaseAuthErrorCode.unknown] for
  /// codes this package does not know).
  FirebaseAuthErrorCode get errorCode => FirebaseAuthErrorCode.fromCode(code);

  /// The broad kind of failure.
  FirebaseAuthErrorCategory get category {
    if (errorCode != FirebaseAuthErrorCode.unknown) return errorCode.category;
    // Unknown codes still carry hints in their names.
    if (code.contains('network') || code.contains('timeout')) {
      return FirebaseAuthErrorCategory.network;
    }
    if (code.contains('too-many') || code.contains('quota')) {
      return FirebaseAuthErrorCategory.rateLimited;
    }
    return FirebaseAuthErrorCategory.unknown;
  }

  /// A short sentence you can show the user, in this order of preference:
  /// [FirebaseAuthKit.errorMessages] override, the built-in message for the
  /// code, then the server message for unknown codes.
  String get userMessage {
    final override = FirebaseAuthKit.errorMessages[errorCode];
    if (override != null) return override;
    if (errorCode != FirebaseAuthErrorCode.unknown) return errorCode.defaultMessage;
    final serverMessage = message;
    if (serverMessage != null &&
        serverMessage.isNotEmpty &&
        !_looksTechnical(serverMessage)) {
      return serverMessage;
    }
    return FirebaseAuthErrorCode.unknown.defaultMessage;
  }

  /// Wrong email / password / token / credential, including the
  /// `user-not-found` and `wrong-password` codes older projects still return.
  bool get isInvalidCredentials =>
      category == FirebaseAuthErrorCategory.invalidCredentials;

  /// The device is offline or the request timed out.
  bool get isNetworkError => category == FirebaseAuthErrorCategory.network;

  /// Too many attempts; the same request may succeed later.
  bool get isRateLimited => category == FirebaseAuthErrorCategory.rateLimited;

  /// Retrying the same call later is reasonable (network, rate limit,
  /// transient server error).
  bool get isRetryable =>
      isNetworkError ||
      isRateLimited ||
      errorCode == FirebaseAuthErrorCode.internalError;

  /// The user must sign in again before this operation (`requires-recent-login`).
  bool get requiresRecentLogin =>
      category == FirebaseAuthErrorCategory.reauthenticationRequired;

  /// The stored session is gone; the user has been signed out.
  bool get isSessionExpired => category == FirebaseAuthErrorCategory.sessionExpired;

  /// The user typed something wrong in a form (email, password strength,
  /// phone number, verification code, expired link).
  bool get isUserInputError => const {
        FirebaseAuthErrorCategory.validation,
        FirebaseAuthErrorCategory.verificationCode,
        FirebaseAuthErrorCategory.actionCode,
      }.contains(category);

  /// The account exists with other details; offer sign-in / linking.
  bool get isAccountConflict => category == FirebaseAuthErrorCategory.accountConflict;

  /// A project / app configuration problem that end users cannot fix; log it
  /// and show a generic message.
  bool get isDeveloperError => category == FirebaseAuthErrorCategory.configuration;

  /// A second factor is required or a multi-factor step failed.
  bool get isMultiFactorError => category == FirebaseAuthErrorCategory.multiFactor;

  static bool _looksTechnical(String text) {
    // Server names such as INVALID_LOGIN_CREDENTIALS or JSON fragments.
    return RegExp(r'^[A-Z0-9_]+$').hasMatch(text.trim()) ||
        text.contains('{') ||
        text.contains('Invalid JSON payload');
  }
}

/// A user-presentable description of any error thrown while authenticating:
/// [FirebaseAuthException]s through [FirebaseAuthExceptionHandling.userMessage],
/// plus network and timeout errors from the platform, with a generic fallback.
String describeAuthError(Object error) {
  if (error is FirebaseAuthException) return error.userMessage;
  if (error is SocketException ||
      error is HandshakeException ||
      error is TimeoutException ||
      error is HttpException) {
    return FirebaseAuthKit.errorMessages[FirebaseAuthErrorCode.networkRequestFailed] ??
        FirebaseAuthErrorCode.networkRequestFailed.defaultMessage;
  }
  if (error is ArgumentError) {
    return FirebaseAuthKit.errorMessages[FirebaseAuthErrorCode.argumentError] ??
        FirebaseAuthErrorCode.argumentError.defaultMessage;
  }
  return FirebaseAuthKit.errorMessages[FirebaseAuthErrorCode.unknown] ??
      FirebaseAuthErrorCode.unknown.defaultMessage;
}

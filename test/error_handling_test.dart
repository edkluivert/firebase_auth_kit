import 'dart:io';

import 'package:firebase_auth_kit/firebase_auth_kit.dart';
import 'package:test/test.dart';

FirebaseAuthException _e(String code, [String? message]) =>
    FirebaseAuthException(code: code, message: message);

void main() {
  setUp(FirebaseAuthKit.reset);

  test('every enum value round-trips through fromCode', () {
    for (final value in FirebaseAuthErrorCode.values) {
      expect(FirebaseAuthErrorCode.fromCode(value.code), value);
    }
    expect(FirebaseAuthErrorCode.fromCode('auth/invalid-email'),
        FirebaseAuthErrorCode.invalidEmail);
    expect(FirebaseAuthErrorCode.fromCode('ERROR_WRONG_PASSWORD'),
        FirebaseAuthErrorCode.wrongPassword);
    expect(FirebaseAuthErrorCode.fromCode('brand-new-code'),
        FirebaseAuthErrorCode.unknown);
    expect(FirebaseAuthErrorCode.fromCode(null), FirebaseAuthErrorCode.unknown);
  });

  test('exceptions expose typed code, category and predicates', () {
    final wrong = _e('invalid-credential', 'INVALID_LOGIN_CREDENTIALS');
    expect(wrong.errorCode, FirebaseAuthErrorCode.invalidCredential);
    expect(wrong.category, FirebaseAuthErrorCategory.invalidCredentials);
    expect(wrong.isInvalidCredentials, isTrue);
    expect(wrong.isRetryable, isFalse);
    expect(wrong.userMessage, 'The email or password is incorrect.');

    expect(_e('user-not-found').isInvalidCredentials, isTrue);
    expect(_e('wrong-password').isInvalidCredentials, isTrue);
    expect(_e('network-request-failed').isNetworkError, isTrue);
    expect(_e('network-request-failed').isRetryable, isTrue);
    expect(_e('too-many-requests').isRateLimited, isTrue);
    expect(_e('requires-recent-login').requiresRecentLogin, isTrue);
    expect(_e('user-token-expired').isSessionExpired, isTrue);
    expect(_e('weak-password').isUserInputError, isTrue);
    expect(_e('invalid-verification-code').isUserInputError, isTrue);
    expect(_e('expired-action-code').isUserInputError, isTrue);
    expect(_e('email-already-in-use').isAccountConflict, isTrue);
    expect(_e('operation-not-allowed').isDeveloperError, isTrue);
    expect(_e('second-factor-required').isMultiFactorError, isTrue);
  });

  test('unknown codes fall back sensibly', () {
    final unknownTechnical = _e('some-new-code', 'SOME_NEW_CODE');
    expect(unknownTechnical.errorCode, FirebaseAuthErrorCode.unknown);
    expect(unknownTechnical.category, FirebaseAuthErrorCategory.unknown);
    expect(unknownTechnical.userMessage,
        FirebaseAuthErrorCode.unknown.defaultMessage);

    final unknownReadable = _e('some-new-code', 'Your account needs attention.');
    expect(unknownReadable.userMessage, 'Your account needs attention.');

    expect(_e('network-something').category, FirebaseAuthErrorCategory.network);
    expect(_e('quota-thing').isRateLimited, isTrue);
  });

  test('errorMessages overrides localise userMessage', () {
    FirebaseAuthKit.errorMessages = {
      FirebaseAuthErrorCode.invalidCredential: 'E-mail ou mot de passe incorrect.',
    };
    expect(_e('invalid-credential').userMessage, 'E-mail ou mot de passe incorrect.');
    expect(_e('weak-password').userMessage,
        FirebaseAuthErrorCode.weakPassword.defaultMessage);
  });

  test('describeAuthError handles any error', () {
    expect(describeAuthError(_e('user-disabled')),
        'This account has been disabled.');
    expect(describeAuthError(const SocketException('offline')),
        FirebaseAuthErrorCode.networkRequestFailed.defaultMessage);
    expect(describeAuthError(StateError('x')),
        FirebaseAuthErrorCode.unknown.defaultMessage);
    expect(FirebaseAuthKit.describeError(ArgumentError('bad')),
        FirebaseAuthErrorCode.argumentError.defaultMessage);
  });

  test('every code has a category and a sentence', () {
    for (final value in FirebaseAuthErrorCode.values) {
      expect(value.defaultMessage, isNotEmpty, reason: value.code);
      expect(value.defaultMessage.endsWith('.'), isTrue, reason: value.code);
      expect(value.code, matches(RegExp(r'^[a-z][a-z0-9-]*$')), reason: value.code);
    }
  });
}

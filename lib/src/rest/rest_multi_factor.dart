import '../firebase_auth_kit_config.dart';
import '../platform_interface.dart';
import 'rest_firebase_auth.dart';
import 'rest_user.dart';
import 'user_mapper.dart';

/// Whether a [RestMultiFactorSession] enrols a new factor or resolves a
/// sign-in that requires one.
enum MultiFactorSessionType { enroll, signIn }

/// A [MultiFactorSession] that remembers what it was created for.
///
/// For [MultiFactorSessionType.enroll] the [id] is the user's ID token; for
/// [MultiFactorSessionType.signIn] it is the `mfaPendingCredential` returned
/// by the first-factor sign-in.
class RestMultiFactorSession extends MultiFactorSession {
  RestMultiFactorSession(super.id, this.type, this.auth);

  final MultiFactorSessionType type;

  /// The auth instance the session belongs to.
  final RestFirebaseAuth auth;
}

/// Multi-factor management for the signed-in user (`user.multiFactor`).
class RestMultiFactor extends MultiFactorPlatform {
  RestMultiFactor(RestFirebaseAuth super.auth) : restAuth = auth;

  final RestFirebaseAuth restAuth;

  RestUser _requireUser() {
    final user = restAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No user currently signed in.',
      );
    }
    return user;
  }

  @override
  Future<MultiFactorSession> getSession() async {
    final user = _requireUser();
    final idToken = await user.freshIdToken();
    return RestMultiFactorSession(idToken, MultiFactorSessionType.enroll, restAuth);
  }

  @override
  Future<void> enroll(
    MultiFactorAssertionPlatform assertion, {
    String? displayName,
  }) async {
    final user = _requireUser();
    final idToken = await user.freshIdToken();
    final body = <String, Object?>{
      'idToken': idToken,
      'displayName': displayName,
    };
    if (assertion is PhoneMultiFactorAssertion) {
      final credential = assertion.credential;
      final verificationId = credential.verificationId;
      final verificationCode = credential.smsCode;
      if (verificationCode == null) {
        throw ArgumentError('verificationCode must not be null');
      }
      if (verificationId == null) {
        throw ArgumentError('verificationId must not be null');
      }
      body['phoneVerificationInfo'] = {
        'sessionInfo': verificationId,
        'code': verificationCode,
      };
    } else if (assertion is TotpMultiFactorAssertion) {
      final sessionInfo = assertion.enrollmentSessionInfo;
      if (sessionInfo == null) {
        throw ArgumentError(
          'This TOTP assertion was created for sign-in; use '
          'TotpMultiFactorGenerator.getAssertionForEnrollment() to enrol.',
        );
      }
      body['totpVerificationInfo'] = {
        'sessionInfo': sessionInfo,
        'verificationCode': assertion.oneTimePassword,
      };
    } else {
      throw UnimplementedError(
        'Assertion type $assertion is not supported yet',
      );
    }
    final response = await restAuth.client.post(
      restAuth.client.v2('accounts/mfaEnrollment:finalize'),
      body,
    );
    user.applyTokens(
      idToken: response['idToken'] as String?,
      refreshToken: response['refreshToken'] as String?,
    );
    await restAuth.reloadUser(user);
    await restAuth.persistCurrentUser();
    restAuth.notifyUserChanged(user);
  }

  @override
  Future<void> unenroll({
    String? factorUid,
    MultiFactorInfo? multiFactorInfo,
  }) async {
    final uidToUnenroll = factorUid ?? multiFactorInfo?.uid;
    if (uidToUnenroll == null) {
      throw ArgumentError(
        'Either factorUid or multiFactorInfo must not be null',
      );
    }
    final user = _requireUser();
    final idToken = await user.freshIdToken();
    final response = await restAuth.client.post(
      restAuth.client.v2('accounts/mfaEnrollment:withdraw'),
      {'idToken': idToken, 'mfaEnrollmentId': uidToUnenroll},
    );
    user.applyTokens(
      idToken: response['idToken'] as String?,
      refreshToken: response['refreshToken'] as String?,
    );
    await restAuth.reloadUser(user);
    await restAuth.persistCurrentUser();
    restAuth.notifyUserChanged(user);
  }

  @override
  Future<List<MultiFactorInfo>> getEnrolledFactors() async {
    final user = _requireUser();
    await restAuth.reloadUser(user);
    return List.unmodifiable(user.enrolledFactors);
  }
}

/// Resolves a sign-in that stopped with `second-factor-required`.
class RestMultiFactorResolver extends MultiFactorResolverPlatform {
  RestMultiFactorResolver(
    super.hints,
    RestMultiFactorSession super.session,
    this.restAuth,
  );

  final RestFirebaseAuth restAuth;

  @override
  Future<UserCredentialPlatform> resolveSignIn(
    MultiFactorAssertionPlatform assertion,
  ) async {
    final body = <String, Object?>{'mfaPendingCredential': session.id};
    if (assertion is PhoneMultiFactorAssertion) {
      final credential = assertion.credential;
      if (credential.smsCode == null) {
        throw ArgumentError('verificationCode must not be null');
      }
      if (credential.verificationId == null) {
        throw ArgumentError('verificationId must not be null');
      }
      body['phoneVerificationInfo'] = {
        'sessionInfo': credential.verificationId,
        'code': credential.smsCode,
      };
    } else if (assertion is TotpMultiFactorAssertion) {
      final enrollmentId = assertion.enrollmentId;
      if (enrollmentId == null) {
        throw ArgumentError(
          'This TOTP assertion was created for enrolment; use '
          'TotpMultiFactorGenerator.getAssertionForSignIn() to sign in.',
        );
      }
      body['mfaEnrollmentId'] = enrollmentId;
      body['totpVerificationInfo'] = {
        'verificationCode': assertion.oneTimePassword,
      };
    } else {
      throw UnimplementedError(
        'Assertion type $assertion is not supported yet',
      );
    }
    final response = await restAuth.client.post(
      restAuth.client.v2('accounts/mfaSignIn:finalize'),
      body,
    );
    return restAuth.completeSignIn(
      response,
      isNewUser: false,
      providerId: assertion is PhoneMultiFactorAssertion
          ? PhoneAuthProvider.PROVIDER_ID
          : 'totp',
    );
  }
}

/// Base class of the assertions this implementation produces.
class MultiFactorAssertion extends MultiFactorAssertionPlatform {
  MultiFactorAssertion() : super();
}

/// Proof of ownership of a phone number (an SMS code).
class PhoneMultiFactorAssertion extends MultiFactorAssertion {
  PhoneMultiFactorAssertion(this.credential) : super();

  final PhoneAuthCredential credential;
}

/// Proof of ownership of a TOTP secret (a one-time password).
class TotpMultiFactorAssertion extends MultiFactorAssertion {
  TotpMultiFactorAssertion.forEnrollment(
    this.enrollmentSessionInfo,
    this.oneTimePassword,
  )   : enrollmentId = null,
        super();

  TotpMultiFactorAssertion.forSignIn(this.enrollmentId, this.oneTimePassword)
      : enrollmentSessionInfo = null,
        super();

  /// The `sessionInfo` from `mfaEnrollment:start`, for enrolment.
  final String? enrollmentSessionInfo;

  /// The enrolled factor id, for sign-in.
  final String? enrollmentId;

  final String oneTimePassword;
}

/// Produces phone assertions for enrolment and sign-in.
class RestPhoneMultiFactorGenerator extends PhoneMultiFactorGeneratorPlatform {
  @override
  MultiFactorAssertionPlatform getAssertion(PhoneAuthCredential credential) {
    return PhoneMultiFactorAssertion(credential);
  }
}

/// Produces TOTP secrets and assertions.
class RestTotpMultiFactorGenerator extends TotpMultiFactorGeneratorPlatform {
  @override
  Future<TotpSecretPlatform> generateSecret(MultiFactorSession session) async {
    final auth = RestFirebaseAuth.instanceForSession(session);
    final response = await auth.client.post(
      auth.client.v2('accounts/mfaEnrollment:start'),
      {'idToken': session.id, 'totpEnrollmentInfo': <String, Object?>{}},
    );
    final info = response['totpSessionInfo'];
    if (info is! Map) {
      throw FirebaseAuthException(
        code: 'internal-error',
        message: 'mfaEnrollment:start did not return totpSessionInfo.',
      );
    }
    final deadline = info['finalizeEnrollmentTime'];
    return RestTotpSecret(
      (info['periodSec'] as num?)?.toInt(),
      (info['verificationCodeLength'] as num?)?.toInt(),
      deadline is String ? DateTime.tryParse(deadline) : null,
      info['hashingAlgorithm'] as String?,
      info['sharedSecretKey'] as String,
      sessionInfo: info['sessionInfo'] as String,
    );
  }

  @override
  Future<MultiFactorAssertionPlatform> getAssertionForEnrollment(
    TotpSecretPlatform secret,
    String oneTimePassword,
  ) async {
    if (secret is! RestTotpSecret) {
      throw ArgumentError.value(secret, 'secret',
          'must come from TotpMultiFactorGenerator.generateSecret()');
    }
    return TotpMultiFactorAssertion.forEnrollment(
      secret.sessionInfo,
      oneTimePassword,
    );
  }

  @override
  Future<MultiFactorAssertionPlatform> getAssertionForSignIn(
    String enrollmentId,
    String oneTimePassword,
  ) async {
    return TotpMultiFactorAssertion.forSignIn(enrollmentId, oneTimePassword);
  }
}

/// A TOTP shared secret produced by `mfaEnrollment:start`.
class RestTotpSecret extends TotpSecretPlatform {
  RestTotpSecret(
    super.codeIntervalSeconds,
    super.codeLength,
    super.enrollmentCompletionDeadline,
    super.hashingAlgorithm,
    super.secretKey, {
    required this.sessionInfo,
  });

  /// Ties the secret to the enrolment session on the backend.
  final String sessionInfo;

  @override
  Future<String> generateQrCodeUrl({
    String? accountName,
    String? issuer,
  }) async {
    final label = Uri.encodeComponent(
      issuer == null || issuer.isEmpty
          ? (accountName ?? 'unknown')
          : '$issuer:${accountName ?? 'unknown'}',
    );
    final params = <String, String>{
      'secret': secretKey,
      if (issuer != null && issuer.isNotEmpty) 'issuer': issuer,
      'algorithm': ?hashingAlgorithm,
      if (codeLength != null) 'digits': '$codeLength',
      if (codeIntervalSeconds != null) 'period': '$codeIntervalSeconds',
    };
    return Uri(
      scheme: 'otpauth',
      host: 'totp',
      path: '/$label',
      queryParameters: params,
    ).toString();
  }

  @override
  Future<void> openInOtpApp(String qrCodeUrl) async {
    final launcher = FirebaseAuthKit.urlLauncher;
    if (launcher == null) {
      throw UnimplementedError(
        'openInOtpApp() needs FirebaseAuthKit.urlLauncher, e.g. '
        '(url) => launchUrl(url) from dartnative_url_launcher.',
      );
    }
    await launcher(Uri.parse(qrCodeUrl));
  }
}

/// Converts lookup `mfaInfo` into the public [MultiFactorInfo] types.
List<MultiFactorInfo> parseMultiFactorInfo(Object? raw) =>
    multiFactorInfoFromJson(raw);

/// What kind of problem a [FirebaseAuthErrorCode] describes, so UI code can
/// decide what to do without matching individual codes.
enum FirebaseAuthErrorCategory {
  /// The email, password, token or credential was wrong. Show an inline error
  /// and let the user try again.
  invalidCredentials,

  /// An account already exists with those details, or the credential is
  /// linked to another account. Offer sign-in or account linking.
  accountConflict,

  /// The account is disabled or gone; the user cannot proceed.
  accountUnavailable,

  /// Client-side input is malformed or missing (bad email, weak password,
  /// missing phone number…). Fix the form.
  validation,

  /// An SMS / OTP code is wrong, expired or missing. Ask for a new code.
  verificationCode,

  /// The password-reset / verification link is invalid or expired. Ask the
  /// user to request a new email.
  actionCode,

  /// The operation is sensitive and the user must sign in again first
  /// (`requires-recent-login`).
  reauthenticationRequired,

  /// The stored session is no longer valid; the user has been (or must be)
  /// signed out.
  sessionExpired,

  /// A second factor is required or a multi-factor operation failed.
  multiFactor,

  /// Too many attempts; retry later.
  rateLimited,

  /// The device is offline or the request timed out; retry.
  network,

  /// The user cancelled a flow.
  cancelled,

  /// The project or app is misconfigured (invalid API key, provider disabled,
  /// unsupported operation…). Nothing the end user can fix.
  configuration,

  /// Anything else.
  unknown,
}

/// Every error code `FirebaseAuthException.code` can carry, as a type.
///
/// Use it instead of comparing strings:
///
/// ```dart
/// } on FirebaseAuthException catch (e) {
///   switch (e.errorCode) {
///     case FirebaseAuthErrorCode.invalidCredential:
///     case FirebaseAuthErrorCode.wrongPassword:
///     case FirebaseAuthErrorCode.userNotFound:
///       showError(e.userMessage);
///     case FirebaseAuthErrorCode.tooManyRequests:
///       showError('Try again in a minute');
///     default:
///       showError(e.userMessage);
///   }
/// }
/// ```
///
/// Codes the backend introduces later arrive as [unknown]; the raw string is
/// always available on `FirebaseAuthException.code`.
enum FirebaseAuthErrorCode {
  // -- credentials -----------------------------------------------------------
  invalidCredential('invalid-credential', FirebaseAuthErrorCategory.invalidCredentials,
      'The email or password is incorrect.'),
  invalidLoginCredentials('invalid-login-credentials',
      FirebaseAuthErrorCategory.invalidCredentials, 'The email or password is incorrect.'),
  wrongPassword('wrong-password', FirebaseAuthErrorCategory.invalidCredentials,
      'The password is incorrect.'),
  userNotFound('user-not-found', FirebaseAuthErrorCategory.invalidCredentials,
      'No account was found for that email address.'),
  invalidCustomToken('invalid-custom-token', FirebaseAuthErrorCategory.invalidCredentials,
      'The sign-in token is not valid.'),
  customTokenMismatch('custom-token-mismatch', FirebaseAuthErrorCategory.configuration,
      'The sign-in token belongs to a different project.'),
  userMismatch('user-mismatch', FirebaseAuthErrorCategory.invalidCredentials,
      'Those details belong to a different account than the one signed in.'),
  rejectedCredential('rejected-credential', FirebaseAuthErrorCategory.invalidCredentials,
      'The sign-in credential was rejected.'),
  missingOrInvalidNonce('missing-or-invalid-nonce', FirebaseAuthErrorCategory.configuration,
      'The sign-in request is missing a valid nonce.'),

  // -- account conflicts -----------------------------------------------------
  emailAlreadyInUse('email-already-in-use', FirebaseAuthErrorCategory.accountConflict,
      'An account already exists with that email address.'),
  accountExistsWithDifferentCredential('account-exists-with-different-credential',
      FirebaseAuthErrorCategory.accountConflict,
      'An account already exists with that email address. Sign in with the method you used before.'),
  credentialAlreadyInUse('credential-already-in-use', FirebaseAuthErrorCategory.accountConflict,
      'That sign-in method is already linked to another account.'),
  providerAlreadyLinked('provider-already-linked', FirebaseAuthErrorCategory.accountConflict,
      'That sign-in method is already linked to this account.'),
  noSuchProvider('no-such-provider', FirebaseAuthErrorCategory.validation,
      'That sign-in method is not linked to this account.'),
  emailChangeNeedsVerification('email-change-needs-verification',
      FirebaseAuthErrorCategory.validation, 'Verify the new email address to continue.'),
  secondFactorAlreadyInUse('second-factor-already-in-use',
      FirebaseAuthErrorCategory.multiFactor, 'That second factor is already enrolled.'),

  // -- account state ---------------------------------------------------------
  userDisabled('user-disabled', FirebaseAuthErrorCategory.accountUnavailable,
      'This account has been disabled.'),
  unverifiedEmail('unverified-email', FirebaseAuthErrorCategory.validation,
      'Verify your email address to continue.'),

  // -- validation ------------------------------------------------------------
  invalidEmail('invalid-email', FirebaseAuthErrorCategory.validation,
      'Enter a valid email address.'),
  missingEmail('missing-email', FirebaseAuthErrorCategory.validation,
      'Enter your email address.'),
  missingPassword('missing-password', FirebaseAuthErrorCategory.validation,
      'Enter your password.'),
  weakPassword('weak-password', FirebaseAuthErrorCategory.validation,
      'Choose a stronger password (at least 6 characters).'),
  invalidPassword('invalid-password', FirebaseAuthErrorCategory.validation,
      'Enter a password.'),
  passwordDoesNotMeetRequirements('password-does-not-meet-requirements',
      FirebaseAuthErrorCategory.validation, 'The password does not meet the requirements.'),
  invalidPhoneNumber('invalid-phone-number', FirebaseAuthErrorCategory.validation,
      'Enter a valid phone number, including the country code.'),
  missingPhoneNumber('missing-phone-number', FirebaseAuthErrorCategory.validation,
      'Enter your phone number.'),
  invalidRecipientEmail('invalid-recipient-email', FirebaseAuthErrorCategory.validation,
      'The email address could not receive the message.'),
  argumentError('argument-error', FirebaseAuthErrorCategory.configuration,
      'An invalid argument was supplied.'),

  // -- verification codes ----------------------------------------------------
  invalidVerificationCode('invalid-verification-code',
      FirebaseAuthErrorCategory.verificationCode, 'The code you entered is incorrect.'),
  invalidVerificationId('invalid-verification-id',
      FirebaseAuthErrorCategory.verificationCode, 'The verification session is no longer valid. Request a new code.'),
  missingVerificationCode('missing-verification-code',
      FirebaseAuthErrorCategory.verificationCode, 'Enter the code we sent you.'),
  missingVerificationId('missing-verification-id',
      FirebaseAuthErrorCategory.verificationCode, 'Request a verification code first.'),
  codeExpired('code-expired', FirebaseAuthErrorCategory.verificationCode,
      'The code has expired. Request a new one.'),
  sessionExpired('session-expired', FirebaseAuthErrorCategory.verificationCode,
      'The verification session has expired. Request a new code.'),
  captchaCheckFailed('captcha-check-failed', FirebaseAuthErrorCategory.verificationCode,
      'The reCAPTCHA check failed. Try again.'),
  missingAppCredential('missing-app-credential', FirebaseAuthErrorCategory.configuration,
      'Phone verification is not set up for this app.'),
  invalidAppCredential('invalid-app-credential', FirebaseAuthErrorCategory.configuration,
      'Phone verification failed for this app.'),
  appNotVerified('app-not-verified', FirebaseAuthErrorCategory.configuration,
      'This app could not be verified for phone sign-in.'),
  missingRecaptchaToken('missing-recaptcha-token', FirebaseAuthErrorCategory.configuration,
      'The reCAPTCHA token is missing.'),
  invalidRecaptchaToken('invalid-recaptcha-token', FirebaseAuthErrorCategory.verificationCode,
      'The reCAPTCHA check failed. Try again.'),
  invalidRecaptchaAction('invalid-recaptcha-action', FirebaseAuthErrorCategory.configuration,
      'The reCAPTCHA action is not valid.'),
  recaptchaNotEnabled('recaptcha-not-enabled', FirebaseAuthErrorCategory.configuration,
      'reCAPTCHA is not enabled for this project.'),
  missingRecaptchaVersion('missing-recaptcha-version', FirebaseAuthErrorCategory.configuration,
      'The reCAPTCHA version is missing.'),
  invalidRecaptchaVersion('invalid-recaptcha-version', FirebaseAuthErrorCategory.configuration,
      'The reCAPTCHA version is not valid.'),
  missingClientType('missing-client-type', FirebaseAuthErrorCategory.configuration,
      'The client type is missing.'),
  invalidReqType('invalid-req-type', FirebaseAuthErrorCategory.configuration,
      'The request type is not valid.'),

  // -- action codes (email links) --------------------------------------------
  expiredActionCode('expired-action-code', FirebaseAuthErrorCategory.actionCode,
      'This link has expired. Request a new one.'),
  invalidActionCode('invalid-action-code', FirebaseAuthErrorCategory.actionCode,
      'This link is invalid or has already been used.'),
  invalidContinueUri('invalid-continue-uri', FirebaseAuthErrorCategory.configuration,
      'The continue URL is not valid.'),
  missingContinueUri('missing-continue-uri', FirebaseAuthErrorCategory.configuration,
      'A continue URL is required.'),
  unauthorizedContinueUri('unauthorized-continue-uri', FirebaseAuthErrorCategory.configuration,
      'The continue URL domain is not allow-listed in the Firebase console.'),
  invalidDynamicLinkDomain('invalid-dynamic-link-domain',
      FirebaseAuthErrorCategory.configuration, 'The link domain is not configured for this project.'),
  invalidHostingLinkDomain('invalid-hosting-link-domain',
      FirebaseAuthErrorCategory.configuration, 'The link domain is not configured for this project.'),
  missingAndroidPkgName('missing-android-pkg-name', FirebaseAuthErrorCategory.configuration,
      'An Android package name is required.'),
  missingIosBundleId('missing-ios-bundle-id', FirebaseAuthErrorCategory.configuration,
      'An iOS bundle ID is required.'),
  invalidMessagePayload('invalid-message-payload', FirebaseAuthErrorCategory.configuration,
      'The email template is not valid.'),
  invalidSender('invalid-sender', FirebaseAuthErrorCategory.configuration,
      'The email sender is not valid.'),

  // -- session -----------------------------------------------------------------
  requiresRecentLogin('requires-recent-login',
      FirebaseAuthErrorCategory.reauthenticationRequired,
      'Please sign in again to continue.'),
  userTokenExpired('user-token-expired', FirebaseAuthErrorCategory.sessionExpired,
      'Your session has expired. Please sign in again.'),
  invalidUserToken('invalid-user-token', FirebaseAuthErrorCategory.sessionExpired,
      'Your session is no longer valid. Please sign in again.'),
  invalidRefreshToken('invalid-refresh-token', FirebaseAuthErrorCategory.sessionExpired,
      'Your session is no longer valid. Please sign in again.'),
  missingRefreshToken('missing-refresh-token', FirebaseAuthErrorCategory.sessionExpired,
      'Your session is no longer valid. Please sign in again.'),
  nullUser('null-user', FirebaseAuthErrorCategory.sessionExpired, 'No user is signed in.'),
  noCurrentUser('no-current-user', FirebaseAuthErrorCategory.sessionExpired,
      'No user is signed in.'),

  // -- multi-factor --------------------------------------------------------------
  secondFactorRequired('second-factor-required', FirebaseAuthErrorCategory.multiFactor,
      'A second verification step is required.'),
  multiFactorAuthRequired('multi-factor-auth-required', FirebaseAuthErrorCategory.multiFactor,
      'A second verification step is required.'),
  multiFactorInfoNotFound('multi-factor-info-not-found', FirebaseAuthErrorCategory.multiFactor,
      'That second factor was not found.'),
  missingMultiFactorInfo('missing-multi-factor-info', FirebaseAuthErrorCategory.multiFactor,
      'Choose a second factor.'),
  missingMultiFactorSession('missing-multi-factor-session',
      FirebaseAuthErrorCategory.multiFactor, 'The multi-factor session is missing.'),
  invalidMultiFactorSession('invalid-multi-factor-session',
      FirebaseAuthErrorCategory.multiFactor, 'The multi-factor session is no longer valid. Sign in again.'),
  maximumSecondFactorCountExceeded('maximum-second-factor-count-exceeded',
      FirebaseAuthErrorCategory.multiFactor, 'The maximum number of second factors is already enrolled.'),
  unsupportedFirstFactor('unsupported-first-factor', FirebaseAuthErrorCategory.multiFactor,
      'Multi-factor authentication needs a different first sign-in method.'),

  // -- limits and network ---------------------------------------------------------
  tooManyRequests('too-many-requests', FirebaseAuthErrorCategory.rateLimited,
      'Too many attempts. Please try again later.'),
  quotaExceeded('quota-exceeded', FirebaseAuthErrorCategory.rateLimited,
      'The service is temporarily unavailable. Please try again later.'),
  networkRequestFailed('network-request-failed', FirebaseAuthErrorCategory.network,
      'Check your internet connection and try again.'),
  timeout('timeout', FirebaseAuthErrorCategory.network,
      'The request timed out. Please try again.'),

  // -- cancelled --------------------------------------------------------------------
  userCancelled('user-cancelled', FirebaseAuthErrorCategory.cancelled, 'Sign-in was cancelled.'),

  // -- configuration / developer errors -----------------------------------------------
  operationNotAllowed('operation-not-allowed', FirebaseAuthErrorCategory.configuration,
      'This sign-in method is not enabled for the project.'),
  operationNotSupportedInThisEnvironment('operation-not-supported-in-this-environment',
      FirebaseAuthErrorCategory.configuration, 'This operation is not supported here.'),
  adminRestrictedOperation('admin-restricted-operation', FirebaseAuthErrorCategory.configuration,
      'This operation is restricted to administrators.'),
  invalidApiKey('invalid-api-key', FirebaseAuthErrorCategory.configuration,
      'The app is not configured correctly (invalid API key).'),
  configurationNotFound('configuration-not-found', FirebaseAuthErrorCategory.configuration,
      'Sign-in is not set up for this app yet.'),
  appNotAuthorized('app-not-authorized', FirebaseAuthErrorCategory.configuration,
      'This app is not authorized to use Firebase Authentication.'),
  appNotInstalled('app-not-installed', FirebaseAuthErrorCategory.configuration,
      'The requested app is not installed.'),
  invalidOauthClientId('invalid-oauth-client-id', FirebaseAuthErrorCategory.configuration,
      'The OAuth client ID is not valid.'),
  invalidProviderId('invalid-provider-id', FirebaseAuthErrorCategory.configuration,
      'The sign-in provider is not valid.'),
  invalidTenantId('invalid-tenant-id', FirebaseAuthErrorCategory.configuration,
      'The tenant is not valid.'),
  tenantIdMismatch('tenant-id-mismatch', FirebaseAuthErrorCategory.configuration,
      'The account belongs to a different tenant.'),
  unsupportedTenantOperation('unsupported-tenant-operation',
      FirebaseAuthErrorCategory.configuration, 'This operation is not supported for tenants.'),
  blockingFunctionErrorResponse('blocking-function-error-response',
      FirebaseAuthErrorCategory.unknown, 'Sign-in was rejected.'),
  internalError('internal-error', FirebaseAuthErrorCategory.unknown,
      'Something went wrong. Please try again.'),

  /// A code this version of the package does not know.
  unknown('unknown', FirebaseAuthErrorCategory.unknown, 'Something went wrong. Please try again.');

  const FirebaseAuthErrorCode(this.code, this.category, this.defaultMessage);

  /// The string on `FirebaseAuthException.code`, e.g. `invalid-credential`.
  final String code;

  /// The broad kind of failure, for deciding how to react.
  final FirebaseAuthErrorCategory category;

  /// A short English sentence suitable for showing to the user. Override per
  /// code with `FirebaseAuthKit.errorMessages` for localisation.
  final String defaultMessage;

  static final Map<String, FirebaseAuthErrorCode> _byCode = {
    for (final value in values) value.code: value,
  };

  /// The enum value for [code], or [unknown]. Accepts the `auth/` prefix the
  /// web SDK uses and native `ERROR_SNAKE_CASE` spellings.
  static FirebaseAuthErrorCode fromCode(String? code) {
    if (code == null || code.isEmpty) return unknown;
    var normalized = code;
    if (normalized.startsWith('auth/')) normalized = normalized.substring(5);
    if (normalized.startsWith('ERROR_')) normalized = normalized.substring(6);
    normalized = normalized.toLowerCase().replaceAll('_', '-');
    return _byCode[normalized] ?? unknown;
  }
}

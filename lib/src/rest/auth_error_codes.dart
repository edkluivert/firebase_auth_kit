// Maps Identity Toolkit server error messages to the error codes FlutterFire
// surfaces on `FirebaseAuthException.code`.
//
// The table follows the Firebase JS SDK's `SERVER_ERROR_MAP` so that the codes
// match what firebase_auth returns on Android / iOS / web.

/// Server error message → `FirebaseAuthException.code`.
const Map<String, String> kServerErrorCodes = {
  // Custom token errors.
  'CREDENTIAL_MISMATCH': 'custom-token-mismatch',
  'MISSING_CUSTOM_TOKEN': 'internal-error',
  'INVALID_CUSTOM_TOKEN': 'invalid-custom-token',
  // Create Auth URI errors.
  'INVALID_IDENTIFIER': 'invalid-email',
  'MISSING_CONTINUE_URI': 'missing-continue-uri',
  // Sign in with email and password errors (some apply to sign up too).
  'INVALID_PASSWORD': 'wrong-password',
  'MISSING_PASSWORD': 'missing-password',
  'INVALID_LOGIN_CREDENTIALS': 'invalid-credential',
  // Sign up with email and password errors.
  'EMAIL_EXISTS': 'email-already-in-use',
  'PASSWORD_LOGIN_DISABLED': 'operation-not-allowed',
  'PASSWORD_DOES_NOT_MEET_REQUIREMENTS': 'password-does-not-meet-requirements',
  // Verify assertion for sign in with credential errors.
  'INVALID_IDP_RESPONSE': 'invalid-credential',
  'INVALID_PENDING_TOKEN': 'invalid-credential',
  'FEDERATED_USER_ID_ALREADY_LINKED': 'credential-already-in-use',
  'MISSING_REQ_TYPE': 'internal-error',
  // Send Password reset email errors.
  'EMAIL_NOT_FOUND': 'user-not-found',
  'RESET_PASSWORD_EXCEED_LIMIT': 'too-many-requests',
  'EXPIRED_OOB_CODE': 'expired-action-code',
  'INVALID_OOB_CODE': 'invalid-action-code',
  'MISSING_OOB_CODE': 'internal-error',
  // Operations that require ID token.
  'CREDENTIAL_TOO_OLD_LOGIN_AGAIN': 'requires-recent-login',
  'INVALID_ID_TOKEN': 'invalid-user-token',
  'TOKEN_EXPIRED': 'user-token-expired',
  'USER_NOT_FOUND': 'user-token-expired',
  // Other errors.
  'TOO_MANY_ATTEMPTS_TRY_LATER': 'too-many-requests',
  'PASSWORD_POLICY_NOT_FOUND': 'internal-error',
  // Phone Auth related errors.
  'INVALID_CODE': 'invalid-verification-code',
  'INVALID_SESSION_INFO': 'invalid-verification-id',
  'INVALID_TEMPORARY_PROOF': 'invalid-credential',
  'MISSING_SESSION_INFO': 'missing-verification-id',
  'SESSION_EXPIRED': 'code-expired',
  'MISSING_CODE': 'missing-verification-code',
  'MISSING_PHONE_NUMBER': 'missing-phone-number',
  'INVALID_PHONE_NUMBER': 'invalid-phone-number',
  'QUOTA_EXCEEDED': 'quota-exceeded',
  'CAPTCHA_CHECK_FAILED': 'captcha-check-failed',
  'MISSING_RECAPTCHA_TOKEN': 'missing-recaptcha-token',
  'INVALID_RECAPTCHA_TOKEN': 'invalid-recaptcha-token',
  'INVALID_RECAPTCHA_ACTION': 'invalid-recaptcha-action',
  'MISSING_CLIENT_TYPE': 'missing-client-type',
  'MISSING_RECAPTCHA_VERSION': 'missing-recaptcha-version',
  'INVALID_RECAPTCHA_VERSION': 'invalid-recaptcha-version',
  'INVALID_REQ_TYPE': 'invalid-req-type',
  'RECAPTCHA_NOT_ENABLED': 'recaptcha-not-enabled',
  'APP_NOT_VERIFIED': 'app-not-verified',
  'MISSING_APP_CREDENTIAL': 'missing-app-credential',
  'INVALID_APP_CREDENTIAL': 'invalid-app-credential',
  // Multi-factor errors.
  'MFA_ENROLLMENT_NOT_FOUND': 'multi-factor-info-not-found',
  'MISSING_MFA_ENROLLMENT_ID': 'missing-multi-factor-info',
  'MISSING_MFA_PENDING_CREDENTIAL': 'missing-multi-factor-session',
  'INVALID_MFA_PENDING_CREDENTIAL': 'invalid-multi-factor-session',
  'SECOND_FACTOR_EXISTS': 'second-factor-already-in-use',
  'SECOND_FACTOR_LIMIT_EXCEEDED': 'maximum-second-factor-count-exceeded',
  'UNSUPPORTED_FIRST_FACTOR': 'unsupported-first-factor',
  'UNVERIFIED_EMAIL': 'unverified-email',
  // Auth domain / continue URI errors.
  'INVALID_CONTINUE_URI': 'invalid-continue-uri',
  'UNAUTHORIZED_DOMAIN': 'unauthorized-continue-uri',
  'INVALID_DYNAMIC_LINK_DOMAIN': 'invalid-dynamic-link-domain',
  'INVALID_HOSTING_LINK_DOMAIN': 'invalid-hosting-link-domain',
  'MISSING_ANDROID_PACKAGE_NAME': 'missing-android-pkg-name',
  'MISSING_IOS_BUNDLE_ID': 'missing-ios-bundle-id',
  'INVALID_OAUTH_CLIENT_ID': 'invalid-oauth-client-id',
  // Tenant / project errors.
  'INVALID_TENANT_ID': 'invalid-tenant-id',
  'TENANT_ID_MISMATCH': 'tenant-id-mismatch',
  'UNSUPPORTED_TENANT_OPERATION': 'unsupported-tenant-operation',
  'INVALID_API_KEY': 'invalid-api-key',
  'CONFIGURATION_NOT_FOUND': 'configuration-not-found',
  'API_KEY_INVALID': 'invalid-api-key',
  'PROJECT_NOT_FOUND': 'invalid-api-key',
  'OPERATION_NOT_ALLOWED': 'operation-not-allowed',
  'ADMIN_ONLY_OPERATION': 'admin-restricted-operation',
  'USER_DISABLED': 'user-disabled',
  'USER_CANCELLED': 'user-cancelled',
  'WEAK_PASSWORD': 'weak-password',
  'INVALID_EMAIL': 'invalid-email',
  'INVALID_SENDER': 'invalid-sender',
  'INVALID_MESSAGE_PAYLOAD': 'invalid-message-payload',
  'INVALID_RECIPIENT_EMAIL': 'invalid-recipient-email',
  'INVALID_PROVIDER_ID': 'invalid-provider-id',
  'MISSING_OR_INVALID_NONCE': 'missing-or-invalid-nonce',
  'EMAIL_CHANGE_NEEDS_VERIFICATION': 'email-change-needs-verification',
  'REJECTED_CREDENTIAL': 'rejected-credential',
  'BLOCKING_FUNCTION_ERROR_RESPONSE': 'blocking-function-error-response',
  'INVALID_REFRESH_TOKEN': 'invalid-refresh-token',
  'MISSING_REFRESH_TOKEN': 'missing-refresh-token',
  'INVALID_GRANT_TYPE': 'internal-error',
};

/// Splits a raw Identity Toolkit error message such as
/// `TOO_MANY_ATTEMPTS_TRY_LATER : Access to this account has been ...` into
/// its server error name and the human-readable remainder.
({String serverCode, String? detail}) splitServerMessage(String message) {
  final separator = message.indexOf(' : ');
  if (separator == -1) {
    final colon = message.indexOf(':');
    if (colon == -1) return (serverCode: message.trim(), detail: null);
    return (
      serverCode: message.substring(0, colon).trim(),
      detail: message.substring(colon + 1).trim(),
    );
  }
  return (
    serverCode: message.substring(0, separator).trim(),
    detail: message.substring(separator + 3).trim(),
  );
}

/// The `FirebaseAuthException.code` for [serverCode], falling back to a
/// lower-kebab-case version of the server name when it is unknown (which is
/// what FlutterFire does with codes it does not recognise).
String authErrorCodeFor(String serverCode) {
  final known = kServerErrorCodes[serverCode];
  if (known != null) return known;
  if (serverCode.isEmpty) return 'unknown';
  return serverCode.toLowerCase().replaceAll('_', '-');
}

/// Default messages for codes where the server gives none, mirroring the
/// native SDKs' wording where practical.
const Map<String, String> kDefaultErrorMessages = {
  'invalid-credential':
      'The supplied auth credential is incorrect, malformed or has expired.',
  'email-already-in-use':
      'The email address is already in use by another account.',
  'user-not-found':
      'There is no user record corresponding to this identifier. The user may have been deleted.',
  'wrong-password':
      'The password is invalid or the user does not have a password.',
  'weak-password': 'Password should be at least 6 characters',
  'invalid-email': 'The email address is badly formatted.',
  'user-disabled':
      'The user account has been disabled by an administrator.',
  'too-many-requests':
      'We have blocked all requests from this device due to unusual activity. Try again later.',
  'requires-recent-login':
      'This operation is sensitive and requires recent authentication. Log in again before retrying this request.',
  'user-token-expired':
      "The user's credential is no longer valid. The user must sign in again.",
  'network-request-failed':
      'A network error (such as timeout, interrupted connection or unreachable host) has occurred.',
  'operation-not-allowed':
      'The given sign-in provider is disabled for this Firebase project. Enable it in the Firebase console, under the sign-in method tab of the Auth section.',
  'credential-already-in-use':
      'This credential is already associated with a different user account.',
  'account-exists-with-different-credential':
      'An account already exists with the same email address but different sign-in credentials. Sign in using a provider associated with this email address.',
  'invalid-verification-code':
      'The sms verification code used to create the phone auth credential is invalid. Please resend the verification code sms and be sure to use the verification code provided by the user.',
  'invalid-verification-id':
      'The verification ID used to create the phone auth credential is invalid.',
  'code-expired':
      'The SMS code has expired. Please re-send the verification code to try again.',
  'user-mismatch':
      'The supplied credentials do not correspond to the previously signed in user.',
  'no-current-user': 'No user currently signed in.',
  'invalid-action-code':
      'The action code is invalid. This can happen if the code is malformed, expired, or has already been used.',
  'expired-action-code': 'The action code has expired.',
  'second-factor-required':
      'Proof of ownership of a second factor is required to complete sign-in.',
  'missing-app-credential':
      'The phone verification request is missing an application verifier assertion.',
  'invalid-api-key':
      'Your API key is invalid, please check you have copied it correctly.',
  'configuration-not-found':
      'Firebase Authentication is not enabled for this project. In the Firebase console open Build → Authentication, click "Get started" and enable a sign-in method.',
};

## 0.1.0

Initial release: the `firebase_auth` 6.7.0 API for DartNative and plain Dart,
implemented over the Identity Toolkit REST API.

- **Same API as FlutterFire**: `FirebaseAuth`, `User`, `UserCredential`,
  `ConfirmationResult`, `MultiFactor`, every `AuthProvider` / `AuthCredential`,
  `FirebaseAuthException` codes and `FirebaseAuthMultiFactorException`.
- **Sign-in methods**: email/password, anonymous, email link, custom token,
  phone (SMS), and every OAuth provider through `signInWithCredential`
  (Google, Apple, Facebook, GitHub, Twitter, Microsoft, Yahoo, generic
  `OAuthProvider`). Linking, unlinking and re-authentication for all of them.
- **Account management**: profile updates, password change, delete, reload,
  email verification, `verifyBeforeUpdateEmail`, password reset and every
  action-code API (`checkActionCode`, `applyActionCode`,
  `verifyPasswordResetCode`, `confirmPasswordReset`).
- **Typed errors**: `FirebaseAuthErrorCode` / `FirebaseAuthErrorCategory`, and on every
  `FirebaseAuthException`: `errorCode`, `category`, `userMessage`, `isInvalidCredentials`,
  `isRetryable`, `requiresRecentLogin`, `isDeveloperError` and friends;
  `FirebaseAuthKit.errorMessages` for localisation, `FirebaseAuthKit.describeError`.
- **Tokens**: `getIdToken`, `getIdTokenResult` with decoded claims, proactive
  refresh with coalesced concurrent refreshes, sign-out on revoked sessions.
- **Streams**: `authStateChanges`, `idTokenChanges`, `userChanges` with the
  current value delivered to every new subscriber.
- **Multi-factor**: phone and TOTP enrolment, `getEnrolledFactors`,
  `unenroll`, `second-factor-required` resolution with
  `MultiFactorResolver`.
- **Sessions persist** across launches through `AuthPersistence`:
  `FileAuthPersistence` in the app's private directory by default,
  `SecureStorageAuthPersistence` / `installSecureAuthPersistence(SecureStorage())`
  for `dartnative_secure_storage` (Keychain / EncryptedSharedPreferences) without
  a dependency on it, `InMemoryAuthPersistence` for `Persistence.NONE`.
- **Zero-config**: `FirebaseAuth.instance` finds the project from
  `GoogleService-Info.plist` (iOS bundle), the `google-services.json` the Google
  Services Gradle plugin compiled into the Android APK (read back from
  `resources.arsc`, or from a bundled asset), `--dart-define`s or the
  environment; `Firebase.initializeApp(options:)` for explicit setup and
  secondary apps.
- **Emulator**: `useAuthEmulator`, or the `FIREBASE_AUTH_EMULATOR_HOST`
  environment variable.
- **Hosted web flows**: with `FirebaseAuthKit.webFlowPresenter` set (a small
  `dartnative_webview` screen), `signInWithProvider` / `linkWithProvider` /
  `reauthenticateWithProvider` run Firebase's hosted `__/auth/handler` redirect
  flow for any provider (GitHub, Microsoft, Yahoo, Twitter, SAML, …) and phone
  authentication in production gets its reCAPTCHA token from the same hosted
  page — the flows the iOS Firebase SDK uses, reproduced over REST
  (`signInWithIdp` with `requestUri` + `sessionId`). Needs `dartnative_webview`
  1.0.1+, which delivers the custom-scheme redirect to `onNavigationRequest`.
- **Tooling**: `FirebaseAuthKit` configuration (persistence, HTTP client,
  reCAPTCHA token provider, OAuth flow handler, URL launcher, redacted request
  logging).

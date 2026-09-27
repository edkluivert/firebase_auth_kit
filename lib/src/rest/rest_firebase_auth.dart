import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

import '../firebase_auth_kit_config.dart';
import '../platform_interface.dart';
import 'auth_error_codes.dart';
import 'auth_persistence.dart';
import 'identity_toolkit_client.dart';
import 'jwt.dart';
import 'rest_confirmation_result.dart';
import 'rest_multi_factor.dart';
import 'rest_recaptcha_verifier.dart';
import 'rest_user.dart';
import 'rest_user_credential.dart';
import 'user_mapper.dart';
import '../web/local_recaptcha_page.dart';
import '../web/web_flow.dart';

/// The [FirebaseAuthPlatform] implementation for DartNative and plain Dart:
/// Firebase Authentication over the Identity Toolkit REST API.
///
/// One instance exists per [FirebaseApp]; obtain it through
/// `FirebaseAuth.instance` / `FirebaseAuth.instanceFor(app:)` rather than
/// constructing it directly.
class RestFirebaseAuth extends FirebaseAuthPlatform
    implements RecaptchaVerifierSettings {
  /// The per-app instances, keyed by app name.
  static final Map<String, RestFirebaseAuth> instances = {};

  /// The root instance [FirebaseAuthPlatform.instance] defaults to; it only
  /// hands out per-app delegates through [delegateFor].
  static RestFirebaseAuth get instance {
    RestRecaptchaVerifierFactory.ensureRegistered();
    return _rootInstance ??= RestFirebaseAuth._root();
  }

  static RestFirebaseAuth? _rootInstance;

  /// The instance for the default app.
  static RestFirebaseAuth get defaultInstance =>
      instance.delegateFor(app: Firebase.app()) as RestFirebaseAuth;

  /// The instance a multi-factor [session] was created by.
  static RestFirebaseAuth instanceForSession(MultiFactorSession session) {
    if (session is RestMultiFactorSession) return session.auth;
    return defaultInstance;
  }

  RestFirebaseAuth._root()
      : client = IdentityToolkitClient(apiKey: ''),
        _persistence = InMemoryAuthPersistence(),
        super(appInstance: null);

  /// Creates the instance for [app].
  RestFirebaseAuth({required FirebaseApp app})
      : client = IdentityToolkitClient(
          apiKey: app.options.apiKey,
          emulatorOrigin: _configuredEmulatorOrigin(),
        ),
        _persistence = FirebaseAuthKit.persistence ?? _defaultPersistence(),
        super(appInstance: app) {
    RestRecaptchaVerifierFactory.ensureRegistered();
    _hydrate();
  }

  static String? _configuredEmulatorOrigin() {
    final host = FirebaseAuthKit.emulatorHost ??
        Platform.environment[FirebaseOptions.keyAuthEmulatorHost];
    if (host == null || host.isEmpty) return null;
    if (host.startsWith('http://') || host.startsWith('https://')) return host;
    return 'http://$host';
  }

  static AuthPersistence _defaultPersistence() {
    try {
      return FileAuthPersistence.defaults();
    } catch (_) {
      return InMemoryAuthPersistence();
    }
  }

  /// The HTTP client for this app's project.
  final IdentityToolkitClient client;

  AuthPersistence _persistence;

  RestUser? _currentUser;

  final StreamController<RestUser?> _authStateController =
      StreamController<RestUser?>.broadcast();
  final StreamController<RestUser?> _idTokenController =
      StreamController<RestUser?>.broadcast();
  final StreamController<RestUser?> _userChangesController =
      StreamController<RestUser?>.broadcast();

  Completer<void>? _hydration;
  bool _disposed = false;
  int _resendTokenCounter = 0;

  /// Settings from [setSettings].
  @override
  bool appVerificationDisabledForTesting = false;
  String? _testPhoneNumber;
  String? _testSmsCode;

  /// Forces app verification (reCAPTCHA) even while requests are routed to
  /// an emulator or fake server; for tests of the production phone flow.
  @visibleForTesting
  bool forceAppVerification = false;

  @override
  bool get usesEmulator => client.usesEmulator && !forceAppVerification;

  /// Completes once the persisted session (if any) has been restored.
  ///
  /// With the default file persistence this is already complete when the
  /// instance is created; asynchronous [AuthPersistence] implementations
  /// finish restoring shortly after.
  Future<void> get ready => _hydration?.future ?? Future.value();

  String get _storageKey =>
      'firebase_auth_kit:${app.options.projectId}:${app.name}';

  // ---------------------------------------------------------------------------
  // Instance management
  // ---------------------------------------------------------------------------

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) {
    return instances.putIfAbsent(app.name, () => RestFirebaseAuth(app: app));
  }

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) {
    if (languageCode != null) {
      this.languageCode = languageCode;
    }
    return this;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    instances.remove(app.name);
    await _authStateController.close();
    await _idTokenController.close();
    await _userChangesController.close();
    client.close();
    _currentUser = null;
  }

  @override
  String? get tenantId => client.tenantId;

  @override
  set tenantId(String? value) => client.tenantId = value;

  @override
  String? get languageCode => client.languageCode;

  set languageCode(String? value) => client.languageCode = value;

  @override
  RestUser? get currentUser => _currentUser;

  @override
  set currentUser(UserPlatform? userPlatform) {
    _currentUser = userPlatform as RestUser?;
  }

  // ---------------------------------------------------------------------------
  // Session persistence and change notifications
  // ---------------------------------------------------------------------------

  void _hydrate() {
    final persistence = _persistence;
    if (persistence is SyncReadableAuthPersistence) {
      String? raw;
      try {
        raw = persistence.readSync(_storageKey);
      } catch (_) {
        raw = null;
      }
      _currentUser = _decodeStoredUser(raw);
      return;
    }
    final completer = _hydration = Completer<void>();
    persistence.read(_storageKey).then((raw) {
      if (_disposed) return;
      final user = _decodeStoredUser(raw);
      if (user != null && _currentUser == null) {
        _currentUser = user;
        _authStateController.add(user);
        _idTokenController.add(user);
        _userChangesController.add(user);
      }
    }).catchError((Object _) {}).whenComplete(completer.complete);
  }

  RestUser? _decodeStoredUser(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final userJson = json['user'];
      if (userJson is! Map) return null;
      final details =
          InternalUserDetails.fromJson(userJson['details'] as Map<dynamic, dynamic>);
      final tokens = AuthTokens.fromJson(userJson['tokens'] as Map<dynamic, dynamic>);
      return RestUser(this, RestMultiFactor(this), details, tokens);
    } catch (_) {
      return null;
    }
  }

  /// Writes the current user to persistence (or clears it).
  Future<void> persistCurrentUser() async {
    final user = _currentUser;
    try {
      if (user == null) {
        await _persistence.delete(_storageKey);
      } else {
        await _persistence.write(
          _storageKey,
          jsonEncode({'version': 1, 'user': user.toJson()}),
        );
      }
    } catch (e) {
      FirebaseAuthKit.logger?.call(
        '[firebase_auth_kit] could not persist the session: $e',
      );
    }
  }

  /// Emits on `idTokenChanges()` and `userChanges()`.
  void notifyIdTokenChanged(RestUser user) {
    if (_disposed) return;
    _idTokenController.add(user);
    _userChangesController.add(user);
  }

  /// Emits on `userChanges()`. Callers persist first so that the next launch
  /// sees the change.
  void notifyUserChanged(RestUser user) {
    if (_disposed) return;
    _userChangesController.add(user);
  }

  @override
  void sendAuthChangesEvent(String appName, UserPlatform? userPlatform) {
    if (_disposed) return;
    _userChangesController.add(userPlatform as RestUser?);
  }

  Future<void> _setCurrentUser(RestUser? user) async {
    final previous = _currentUser;
    _currentUser = user;
    await persistCurrentUser();
    if (_disposed) return;
    final authStateChanged = previous?.uid != user?.uid;
    if (authStateChanged) _authStateController.add(user);
    _idTokenController.add(user);
    _userChangesController.add(user);
  }

  @override
  Stream<UserPlatform?> authStateChanges() async* {
    yield _currentUser;
    yield* _authStateController.stream;
  }

  @override
  Stream<UserPlatform?> idTokenChanges() async* {
    yield _currentUser;
    yield* _idTokenController.stream;
  }

  @override
  Stream<UserPlatform?> userChanges() async* {
    yield _currentUser;
    yield* _userChangesController.stream;
  }

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  @override
  Future<void> useAuthEmulator(String host, int port) async {
    client.emulatorOrigin = 'http://$host:$port';
  }

  @override
  Future<void> setLanguageCode(String? languageCode) async {
    client.languageCode = languageCode;
  }

  @override
  Future<void> setSettings({
    bool appVerificationDisabledForTesting = false,
    String? userAccessGroup,
    bool migrateCurrentUser = false,
    String? phoneNumber,
    String? smsCode,
    bool? forceRecaptchaFlow,
  }) async {
    if (migrateCurrentUser && userAccessGroup == null) {
      throw ArgumentError(
        'The [userAccessGroup] must be set when [migrateCurrentUser] is true.',
      );
    }
    if (phoneNumber != null && smsCode == null ||
        phoneNumber == null && smsCode != null) {
      throw ArgumentError(
        "The [smsCode] and the [phoneNumber] must both be either 'null' or a 'String''.",
      );
    }
    this.appVerificationDisabledForTesting = appVerificationDisabledForTesting;
    _testPhoneNumber = phoneNumber;
    _testSmsCode = smsCode;
    // userAccessGroup / migrateCurrentUser / forceRecaptchaFlow concern the
    // native Keychain and SafetyNet flows, which do not exist here.
  }

  @override
  Future<void> setPersistence(Persistence persistence) async {
    final AuthPersistence next = switch (persistence) {
      Persistence.NONE => InMemoryAuthPersistence(),
      Persistence.SESSION => InMemoryAuthPersistence(),
      Persistence.LOCAL || Persistence.INDEXED_DB =>
        FirebaseAuthKit.persistence ?? _defaultPersistence(),
    };
    if (next.runtimeType == _persistence.runtimeType &&
        next is! InMemoryAuthPersistence) {
      return;
    }
    try {
      await _persistence.delete(_storageKey);
    } catch (_) {}
    _persistence = next;
    await persistCurrentUser();
  }

  @override
  Future<void> initializeRecaptchaConfig() async {
    // Fetches the project's reCAPTCHA Enterprise configuration like the
    // native SDKs do; nothing is enforced client-side afterwards.
    final uri = client.v2('recaptchaConfig').replace(queryParameters: {
      'key': client.apiKey,
      'clientType': 'CLIENT_TYPE_WEB',
      'version': 'RECAPTCHA_ENTERPRISE',
    });
    try {
      await client.get(uri);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') rethrow;
      // Projects without reCAPTCHA Enterprise return an error; ignore it.
    }
  }

  // ---------------------------------------------------------------------------
  // Action codes
  // ---------------------------------------------------------------------------

  @override
  Future<void> applyActionCode(String code) async {
    await client.post(client.v1('accounts:update'), {'oobCode': code});
  }

  Future<Map<String, Object?>> _resetPassword(String code, [String? newPassword]) {
    return client.post(client.v1('accounts:resetPassword'), {
      'oobCode': code,
      'newPassword': newPassword,
    });
  }

  @override
  Future<ActionCodeInfo> checkActionCode(String code) async {
    final response = await _resetPassword(code);
    final requestType = response['requestType'] as String?;
    final operation = switch (requestType) {
      'PASSWORD_RESET' => ActionCodeInfoOperation.passwordReset,
      'VERIFY_EMAIL' => ActionCodeInfoOperation.verifyEmail,
      'RECOVER_EMAIL' => ActionCodeInfoOperation.recoverEmail,
      'EMAIL_SIGNIN' => ActionCodeInfoOperation.emailSignIn,
      'VERIFY_AND_CHANGE_EMAIL' => ActionCodeInfoOperation.verifyAndChangeEmail,
      'REVERT_SECOND_FACTOR_ADDITION' =>
        ActionCodeInfoOperation.revertSecondFactorAddition,
      _ => ActionCodeInfoOperation.unknown,
    };
    final email = response['email'] as String?;
    final newEmail = response['newEmail'] as String?;
    final swapsEmails = operation == ActionCodeInfoOperation.recoverEmail ||
        operation == ActionCodeInfoOperation.verifyAndChangeEmail;
    return ActionCodeInfo(
      operation: operation,
      data: ActionCodeInfoData(
        email: swapsEmails ? newEmail : email,
        previousEmail: swapsEmails ? email : null,
      ),
    );
  }

  @override
  Future<void> confirmPasswordReset(String code, String newPassword) async {
    await _resetPassword(code, newPassword);
  }

  @override
  Future<String> verifyPasswordResetCode(String code) async {
    final response = await _resetPassword(code);
    if (response['requestType'] != 'PASSWORD_RESET') {
      throw FirebaseAuthException(
        code: 'invalid-action-code',
        message: kDefaultErrorMessages['invalid-action-code'],
      );
    }
    return response['email'] as String;
  }

  @override
  Future<void> sendPasswordResetEmail(
    String email, [
    ActionCodeSettings? actionCodeSettings,
  ]) async {
    await client.post(client.v1('accounts:sendOobCode'), {
      'requestType': 'PASSWORD_RESET',
      'email': email,
      ...actionCodeSettingsToJson(actionCodeSettings),
    });
  }

  @override
  Future<void> sendSignInLinkToEmail(
    String email,
    ActionCodeSettings actionCodeSettings,
  ) async {
    await client.post(client.v1('accounts:sendOobCode'), {
      'requestType': 'EMAIL_SIGNIN',
      'email': email,
      ...actionCodeSettingsToJson(actionCodeSettings),
    });
  }

  @override
  Future<List<String>> fetchSignInMethodsForEmail(String email) async {
    final response = await client.post(client.v1('accounts:createAuthUri'), {
      'identifier': email,
      'continueUri': 'http://localhost',
    });
    final methods = response['signinMethods'];
    if (methods is List) return methods.whereType<String>().toList();
    return const [];
  }

  // ---------------------------------------------------------------------------
  // Sign-in
  // ---------------------------------------------------------------------------

  @override
  Future<UserCredentialPlatform> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final response = await client.post(client.v1('accounts:signUp'), {
      'email': email,
      'password': password,
      'returnSecureToken': true,
    });
    return completeSignIn(
      response,
      isNewUser: true,
      providerId: EmailAuthProvider.PROVIDER_ID,
    );
  }

  @override
  Future<UserCredentialPlatform> signInAnonymously() async {
    final existing = _currentUser;
    if (existing != null && existing.isAnonymous) {
      return RestUserCredential(
        auth: this,
        user: existing,
        additionalUserInfo: AdditionalUserInfo(isNewUser: false),
      );
    }
    final response = await client.post(client.v1('accounts:signUp'), {
      'returnSecureToken': true,
    });
    return completeSignIn(response, isNewUser: true, anonymous: true);
  }

  @override
  Future<UserCredentialPlatform> signInWithEmailAndPassword(
    String email,
    String password,
  ) {
    return signInWithCredentialInternal(
      EmailAuthProvider.credential(email: email, password: password),
    );
  }

  @override
  Future<UserCredentialPlatform> signInWithEmailLink(
    String email,
    String emailLink,
  ) {
    return signInWithCredentialInternal(
      EmailAuthProvider.credentialWithLink(email: email, emailLink: emailLink),
    );
  }

  @override
  Future<UserCredentialPlatform> signInWithCustomToken(String token) async {
    final response =
        await client.post(client.v1('accounts:signInWithCustomToken'), {
      'token': token,
      'returnSecureToken': true,
    });
    return completeSignIn(
      response,
      isNewUser: response['isNewUser'] == true,
      providerId: 'custom',
    );
  }

  @override
  Future<UserCredentialPlatform> signInWithCredential(
    AuthCredential credential,
  ) {
    return signInWithCredentialInternal(credential);
  }

  @override
  Future<UserCredentialPlatform> signInWithProvider(AuthProvider provider) {
    return signInWithProviderInternal(provider, method: 'signInWithProvider');
  }

  @override
  Future<ConfirmationResultPlatform> signInWithPhoneNumber(
    String phoneNumber,
    RecaptchaVerifierFactoryPlatform applicationVerifier,
  ) {
    return startPhoneSignIn(phoneNumber, applicationVerifier);
  }

  @override
  Future<UserCredentialPlatform> signInWithPopup(AuthProvider provider) {
    throw UnimplementedError(
      'signInWithPopup() is only supported on web based platforms',
    );
  }

  @override
  Future<void> signInWithRedirect(AuthProvider provider) {
    throw UnimplementedError(
      'signInWithRedirect() is only supported on web based platforms',
    );
  }

  @override
  Future<UserCredentialPlatform> getRedirectResult() {
    throw UnimplementedError(
      'getRedirectResult() is only supported on web based platforms',
    );
  }

  @override
  Future<void> signOut() async {
    await _setCurrentUser(null);
  }

  @override
  Future<void> revokeTokenWithAuthorizationCode(String authorizationCode) {
    return _revokeToken(authorizationCode, 'AUTHORIZATION_CODE');
  }

  @override
  Future<void> revokeAccessToken(String accessToken) {
    return _revokeToken(accessToken, 'ACCESS_TOKEN');
  }

  Future<void> _revokeToken(String token, String tokenType) async {
    final idToken = await _currentUser?.freshIdToken();
    await client.post(client.v2('accounts:revokeToken'), {
      'providerId': AppleAuthProvider.PROVIDER_ID,
      'tokenType': tokenType,
      'token': token,
      'idToken': idToken,
    });
  }

  // ---------------------------------------------------------------------------
  // Phone number verification
  // ---------------------------------------------------------------------------

  @override
  Future<void> verifyPhoneNumber({
    String? phoneNumber,
    PhoneMultiFactorInfo? multiFactorInfo,
    required PhoneVerificationCompleted verificationCompleted,
    required PhoneVerificationFailed verificationFailed,
    required PhoneCodeSent codeSent,
    required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
    Duration timeout = const Duration(seconds: 30),
    int? forceResendingToken,
    MultiFactorSession? multiFactorSession,
    String? autoRetrievedSmsCodeForTesting,
  }) async {
    try {
      final number = phoneNumber ?? multiFactorInfo?.phoneNumber;
      if (number == null) {
        throw FirebaseAuthException(
          code: 'missing-phone-number',
          message: 'Either phoneNumber or multiFactorInfo must be provided.',
        );
      }
      final isConfiguredTestNumber =
          phoneNumber != null && phoneNumber == _testPhoneNumber;
      final recaptchaToken = isConfiguredTestNumber
          ? (usesEmulator ? null : RestRecaptchaVerifierFactory.mockToken())
          : await _appVerificationToken(null);
      final verificationId = await sendVerificationCode(
        number,
        recaptchaToken: recaptchaToken,
        session: multiFactorSession,
        mfaEnrollmentId: multiFactorInfo?.uid,
      );
      codeSent(verificationId, ++_resendTokenCounter);

      final autoCode = autoRetrievedSmsCodeForTesting ??
          (phoneNumber != null && phoneNumber == _testPhoneNumber
              ? _testSmsCode
              : null);
      if (autoCode != null) {
        verificationCompleted(
          PhoneAuthProvider.credential(
            verificationId: verificationId,
            smsCode: autoCode,
          ),
        );
        return;
      }
      // There is no SMS auto-retrieval outside the Android SDK; report the
      // timeout after [timeout] like Android does so callers can re-prompt.
      Timer(timeout, () {
        if (!_disposed) codeAutoRetrievalTimeout(verificationId);
      });
    } on FirebaseAuthException catch (e) {
      verificationFailed(e);
    }
  }

  /// Runs app verification and returns the reCAPTCHA token to send, or `null`
  /// when none is needed (emulator).
  Future<String?> _appVerificationToken(
    RecaptchaVerifierFactoryPlatform? verifier,
  ) async {
    if (usesEmulator) return null;
    final effective = verifier ??
        RecaptchaVerifierFactoryPlatform.instance.delegateFor(auth: this);
    if (effective is RestRecaptchaVerifierFactory) {
      effective.auth ??= this;
    }
    final token = await effective.verify();
    return token.isEmpty ? null : token;
  }

  /// Sends an SMS and returns the `sessionInfo` (the verification id).
  Future<String> sendVerificationCode(
    String phoneNumber, {
    String? recaptchaToken,
    MultiFactorSession? session,
    String? mfaEnrollmentId,
  }) async {
    if (session == null) {
      final response =
          await client.post(client.v1('accounts:sendVerificationCode'), {
        'phoneNumber': phoneNumber,
        'recaptchaToken': recaptchaToken,
      });
      return _requireString(response, 'sessionInfo');
    }
    final type = session is RestMultiFactorSession
        ? session.type
        : MultiFactorSessionType.enroll;
    if (type == MultiFactorSessionType.enroll) {
      final response =
          await client.post(client.v2('accounts/mfaEnrollment:start'), {
        'idToken': session.id,
        'phoneEnrollmentInfo': {
          'phoneNumber': phoneNumber,
          'recaptchaToken': recaptchaToken,
        },
      });
      final info = response['phoneSessionInfo'];
      if (info is Map) return _requireString(info, 'sessionInfo');
      throw FirebaseAuthException(
        code: 'internal-error',
        message: 'mfaEnrollment:start did not return phoneSessionInfo.',
      );
    }
    final response = await client.post(client.v2('accounts/mfaSignIn:start'), {
      'mfaPendingCredential': session.id,
      'mfaEnrollmentId': mfaEnrollmentId,
      'phoneSignInInfo': {'recaptchaToken': recaptchaToken},
    });
    final info = response['phoneResponseInfo'];
    if (info is Map) return _requireString(info, 'sessionInfo');
    throw FirebaseAuthException(
      code: 'internal-error',
      message: 'mfaSignIn:start did not return phoneResponseInfo.',
    );
  }

  /// Starts the web-style phone flow used by `signInWithPhoneNumber` and
  /// `linkWithPhoneNumber`.
  Future<ConfirmationResultPlatform> startPhoneSignIn(
    String phoneNumber,
    RecaptchaVerifierFactoryPlatform applicationVerifier, {
    bool linkToCurrentUser = false,
  }) async {
    final token = await _appVerificationToken(applicationVerifier);
    final verificationId =
        await sendVerificationCode(phoneNumber, recaptchaToken: token);
    return RestConfirmationResult(
      this,
      verificationId,
      linkToCurrentUser: linkToCurrentUser,
    );
  }

  // ---------------------------------------------------------------------------
  // Credentials
  // ---------------------------------------------------------------------------

  /// The hosted auth handler for this app (`https://<authDomain>/__/auth/handler`
  /// or the emulator's).
  FirebaseAuthHandler get authHandler => FirebaseAuthHandler(
        apiKey: client.apiKey,
        appName: app.name,
        authDomain: customAuthDomain ??
            app.options.authDomain ??
            '${app.options.projectId}.firebaseapp.com',
        appId: app.options.appId.isEmpty ? null : app.options.appId,
        iosBundleId: app.options.iosBundleId,
        androidPackageName: currentAndroidPackageName(),
        tenantId: tenantId,
        languageCode: languageCode,
        emulatorOrigin: client.emulatorOrigin,
      );

  /// Obtains a credential for [provider] through
  /// [FirebaseAuthKit.oauthFlowHandler]. Used only when an app supplies its
  /// own OAuth implementation; otherwise [signInWithProviderInternal] runs the
  /// hosted redirect flow.
  Future<AuthCredential> runOAuthFlow(AuthProvider provider, String method) {
    final handler = FirebaseAuthKit.oauthFlowHandler;
    if (handler == null) {
      throw FirebaseAuthException(
        code: 'operation-not-supported-in-this-environment',
        message: '$method() needs a web page shown to the user. Set '
            'FirebaseAuthKit.webFlowPresenter (see the README), or obtain the '
            'provider token natively and call signInWithCredential().',
      );
    }
    return handler(this, provider);
  }

  /// Signs in, links or re-authenticates with [provider] through the
  /// Firebase-hosted auth handler shown by [FirebaseAuthKit.webFlowPresenter],
  /// the same redirect flow the iOS Firebase SDK uses. Falls back to
  /// [FirebaseAuthKit.oauthFlowHandler] when the app supplied one instead.
  Future<UserCredentialPlatform> signInWithProviderInternal(
    AuthProvider provider, {
    RestUser? linkTo,
    RestUser? reauthenticate,
    required String method,
  }) async {
    if (FirebaseAuthKit.webFlowPresenter == null &&
        FirebaseAuthKit.oauthFlowHandler != null) {
      final credential = await runOAuthFlow(provider, method);
      return signInWithCredentialInternal(
        credential,
        linkTo: linkTo,
        reauthenticate: reauthenticate,
      );
    }
    final options = providerOptions(provider);
    final nonce = randomToken();
    final url = authHandler.signInWithRedirectUrl(
      providerId: provider.providerId,
      sessionIdHash: sha256Hex(nonce),
      eventId: randomToken(20),
      scopes: options.scopes,
      customParameters: options.parameters,
    );
    final result = await runWebFlow(url, operation: '$method()');
    final link = result.link;
    if (link == null || link.isEmpty) {
      throw FirebaseAuthException(
        code: 'internal-error',
        message: 'The sign-in page returned no provider response.',
      );
    }
    final linkIdToken = linkTo == null ? null : await linkTo.freshIdToken();
    final response = await client.post(client.v1('accounts:signInWithIdp'), {
      'requestUri': link,
      'sessionId': nonce,
      'returnSecureToken': true,
      'returnIdpCredential': true,
      'idToken': linkIdToken,
    });
    return _finishIdpResponse(
      response,
      providerId: provider.providerId,
      fallbackCredential: null,
      linkTo: linkTo,
      reauthenticate: reauthenticate,
    );
  }

  /// Runs reCAPTCHA app verification and returns the token to send with
  /// phone requests: the project's reCAPTCHA rendered on a loopback page
  /// inside the app (the web SDK's approach), shown through
  /// [FirebaseAuthKit.webFlowPresenter].
  @override
  Future<String> verifyAppWithHostedRecaptcha() async {
    final presenter = FirebaseAuthKit.webFlowPresenter;
    if (presenter == null) {
      throw FirebaseAuthException(
        code: 'operation-not-supported-in-this-environment',
        message: 'Phone verification needs a web page shown to the user. Set '
            'FirebaseAuthKit.webFlowPresenter (see the README).',
      );
    }
    final params = await client.get(client.v1('recaptchaParams'));
    final siteKey = params['recaptchaSiteKey'] as String?;
    if (siteKey == null || siteKey.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-app-credential',
        message: 'The project did not return a reCAPTCHA site key; enable '
            'Phone sign-in in the Firebase console.',
      );
    }
    return runLocalRecaptcha(
      siteKey: siteKey,
      languageCode: languageCode,
      present: presenter,
    );
  }

  /// Signs in, links or re-authenticates with [credential].
  Future<UserCredentialPlatform> signInWithCredentialInternal(
    AuthCredential credential, {
    RestUser? linkTo,
    RestUser? reauthenticate,
  }) async {
    final linkIdToken = linkTo == null ? null : await linkTo.freshIdToken();

    if (credential is EmailAuthCredential) {
      if (credential.signInMethod == EmailAuthProvider.EMAIL_PASSWORD_SIGN_IN_METHOD) {
        final password = credential.password;
        if (password == null) {
          throw FirebaseAuthException(
            code: 'missing-password',
            message: 'A password is required.',
          );
        }
        if (linkTo != null) {
          // Linking a password is a signUp with the current idToken (what
          // the JS and native SDKs send); accounts:update refuses to set an
          // unverified email on projects with email enumeration protection.
          final response = await client.post(client.v1('accounts:signUp'), {
            'idToken': linkIdToken,
            'email': credential.email,
            'password': password,
            'returnSecureToken': true,
          });
          return completeSignIn(
            response,
            isNewUser: false,
            providerId: EmailAuthProvider.PROVIDER_ID,
            linkTo: linkTo,
          );
        }
        final response =
            await client.post(client.v1('accounts:signInWithPassword'), {
          'email': credential.email,
          'password': password,
          'returnSecureToken': true,
        });
        return completeSignIn(
          response,
          isNewUser: false,
          providerId: EmailAuthProvider.PROVIDER_ID,
          reauthenticate: reauthenticate,
        );
      }
      final oobCode = oobCodeFromEmailLink(credential.emailLink ?? '');
      if (oobCode == null) {
        throw FirebaseAuthException(
          code: 'argument-error',
          message: 'Invalid email link: no oobCode found.',
        );
      }
      final response =
          await client.post(client.v1('accounts:signInWithEmailLink'), {
        'email': credential.email,
        'oobCode': oobCode,
        'idToken': linkIdToken,
      });
      return completeSignIn(
        response,
        isNewUser: response['isNewUser'] == true,
        providerId: EmailAuthProvider.PROVIDER_ID,
        linkTo: linkTo,
        reauthenticate: reauthenticate,
      );
    }

    if (credential is PhoneAuthCredential) {
      final verificationId = credential.verificationId;
      final smsCode = credential.smsCode;
      if (verificationId == null || smsCode == null) {
        throw FirebaseAuthException(
          code: 'invalid-verification-id',
          message: 'Phone credentials must be created with '
              'PhoneAuthProvider.credential(verificationId:, smsCode:); '
              'native auto-retrieved credentials are not available here.',
        );
      }
      final response =
          await client.post(client.v1('accounts:signInWithPhoneNumber'), {
        'sessionInfo': verificationId,
        'code': smsCode,
        'idToken': linkIdToken,
      });
      return completeSignIn(
        response,
        isNewUser: response['isNewUser'] == true,
        providerId: PhoneAuthProvider.PROVIDER_ID,
        credential: credential,
        linkTo: linkTo,
        reauthenticate: reauthenticate,
      );
    }

    if (credential is OAuthCredential) {
      return _signInWithIdp(
        credential,
        linkTo: linkTo,
        linkIdToken: linkIdToken,
        reauthenticate: reauthenticate,
      );
    }

    if (credential is GameCenterAuthCredential ||
        credential is PlayGamesAuthCredential) {
      throw FirebaseAuthException(
        code: 'operation-not-supported-in-this-environment',
        message: '${credential.providerId} credentials are verified by the '
            'native Firebase SDKs and are not supported by firebase_auth_kit.',
      );
    }

    throw FirebaseAuthException(
      code: 'invalid-credential',
      message: 'Unsupported credential type ${credential.runtimeType} '
          '(${credential.providerId}).',
    );
  }

  Future<UserCredentialPlatform> _signInWithIdp(
    OAuthCredential credential, {
    RestUser? linkTo,
    String? linkIdToken,
    RestUser? reauthenticate,
  }) async {
    final params = <String, String>{'providerId': credential.providerId};
    if (credential.idToken != null) params['id_token'] = credential.idToken!;
    if (credential.accessToken != null) {
      params['access_token'] = credential.accessToken!;
    }
    if (credential.secret != null) {
      params['oauth_token_secret'] = credential.secret!;
    }
    if (credential.rawNonce != null) params['nonce'] = credential.rawNonce!;
    if (credential.serverAuthCode != null) {
      params['code'] = credential.serverAuthCode!;
    }
    final postBody = params.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');

    final response = await client.post(client.v1('accounts:signInWithIdp'), {
      'postBody': postBody,
      'requestUri': 'http://localhost',
      'returnSecureToken': true,
      'returnIdpCredential': true,
      'idToken': linkIdToken,
    });

    return _finishIdpResponse(
      response,
      providerId: credential.providerId,
      fallbackCredential: credential,
      appleFullPersonName: credential.appleFullPersonName,
      linkTo: linkTo,
      reauthenticate: reauthenticate,
    );
  }

  Future<UserCredentialPlatform> _finishIdpResponse(
    Map<String, Object?> response, {
    required String providerId,
    required OAuthCredential? fallbackCredential,
    AppleFullPersonName? appleFullPersonName,
    RestUser? linkTo,
    RestUser? reauthenticate,
  }) async {
    final returnedCredential = credentialFromIdpResponse(response) ?? fallbackCredential;
    final email = response['email'] as String?;
    if (response['needConfirmation'] == true) {
      throw FirebaseAuthException(
        code: 'account-exists-with-different-credential',
        message: kDefaultErrorMessages['account-exists-with-different-credential'],
        email: email,
        credential: returnedCredential,
      );
    }
    final errorMessage = response['errorMessage'] as String?;
    if (errorMessage != null && errorMessage.isNotEmpty) {
      final split = splitServerMessage(errorMessage);
      final code = authErrorCodeFor(split.serverCode);
      throw FirebaseAuthException(
        code: code,
        message: split.detail ?? kDefaultErrorMessages[code] ?? errorMessage,
        email: email,
        credential: returnedCredential,
      );
    }

    final isNewUser = response['isNewUser'] == true;
    final result = await completeSignIn(
      response,
      isNewUser: isNewUser,
      providerId: providerId,
      credential: returnedCredential,
      linkTo: linkTo,
      reauthenticate: reauthenticate,
    );

    // Sign in with Apple only reveals the name to the client; store it on the
    // new account like the native SDKs do.
    final name = appleFullPersonName;
    final user = result.user;
    if (isNewUser && name != null && user is RestUser && user.displayName == null) {
      final displayName = [name.givenName, name.middleName, name.familyName]
          .whereType<String>()
          .where((part) => part.isNotEmpty)
          .join(' ');
      if (displayName.isNotEmpty) {
        try {
          await user.updateProfile({'displayName': displayName});
        } on FirebaseAuthException {
          // Best effort.
        }
      }
    }
    return result;
  }

  /// Turns a successful sign-in / link / reauthenticate response into a
  /// [UserCredentialPlatform], updating [currentUser] and the streams.
  ///
  /// Throws [FirebaseAuthMultiFactorExceptionPlatform] when the backend asks
  /// for a second factor.
  Future<UserCredentialPlatform> completeSignIn(
    Map<String, Object?> response, {
    required bool isNewUser,
    String? providerId,
    AuthCredential? credential,
    RestUser? linkTo,
    RestUser? reauthenticate,
    bool anonymous = false,
  }) async {
    final idToken = response['idToken'] as String?;
    if (idToken == null || idToken.isEmpty) {
      final pending = response['mfaPendingCredential'] as String?;
      if (pending != null) {
        final hints = multiFactorInfoFromJson(response['mfaInfo']);
        throw FirebaseAuthMultiFactorExceptionPlatform(
          code: 'second-factor-required',
          message: kDefaultErrorMessages['second-factor-required'],
          resolver: RestMultiFactorResolver(
            hints,
            RestMultiFactorSession(pending, MultiFactorSessionType.signIn, this),
            this,
          ),
        );
      }
      throw FirebaseAuthException(
        code: 'internal-error',
        message: 'The sign-in response did not include an ID token.',
      );
    }
    final expiresIn = int.tryParse(response['expiresIn']?.toString() ?? '') ??
        (jwtExpiration(idToken)?.difference(DateTime.now().toUtc()).inSeconds ??
            3600);
    final target = reauthenticate ?? linkTo;
    final tokens = AuthTokens(
      idToken: idToken,
      refreshToken: (response['refreshToken'] as String?) ??
          target?.tokens.refreshToken ??
          '',
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
    );
    final localId = (response['localId'] as String?) ??
        decodeJwtPayload(idToken)?['sub'] as String?;

    final additionalUserInfo = additionalUserInfoFromResponse(
      response,
      isNewUser: isNewUser,
      providerId: providerId,
    );

    if (target != null) {
      if (reauthenticate != null &&
          localId != null &&
          localId != reauthenticate.uid) {
        throw FirebaseAuthException(
          code: 'user-mismatch',
          message: kDefaultErrorMessages['user-mismatch'],
        );
      }
      target.tokens = tokens;
      target.userDetailsRefreshToken = tokens.refreshToken;
      await reloadUser(target);
      await persistCurrentUser();
      notifyIdTokenChanged(target);
      return RestUserCredential(
        auth: this,
        user: target,
        additionalUserInfo: additionalUserInfo,
        credential: credential,
      );
    }

    if (localId == null) {
      throw FirebaseAuthException(
        code: 'internal-error',
        message: 'The sign-in response did not identify the user.',
      );
    }
    final user = RestUser(
      this,
      RestMultiFactor(this),
      InternalUserDetails(
        userInfo: InternalUserInfo(
          uid: localId,
          email: response['email'] as String?,
          displayName: response['displayName'] as String?,
          photoUrl: response['photoUrl'] as String?,
          phoneNumber: response['phoneNumber'] as String?,
          isAnonymous: anonymous,
          isEmailVerified: response['emailVerified'] == true,
          providerId: 'firebase',
          tenantId: tenantId,
          refreshToken: tokens.refreshToken,
        ),
        providerData: const [],
      ),
      tokens,
    );
    await reloadUser(user);
    await _setCurrentUser(user);
    return RestUserCredential(
      auth: this,
      user: user,
      additionalUserInfo: additionalUserInfo,
      credential: credential,
    );
  }

  /// Fetches the account record for [user] and replaces its profile.
  Future<void> reloadUser(RestUser user) async {
    final idToken = await user.freshIdToken();
    final response = await client.post(client.v1('accounts:lookup'), {
      'idToken': idToken,
    }, includeTenant: false);
    final users = response['users'];
    if (users is! List || users.isEmpty || users.first is! Map) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: kDefaultErrorMessages['user-not-found'],
      );
    }
    final record = Map<String, Object?>.from(users.first as Map);
    final wasAnonymous = user.details.userInfo.isAnonymous;
    final details = userDetailsFromLookup(
      record,
      refreshToken: user.tokens.refreshToken,
      isAnonymousHint: wasAnonymous,
      tenantId: tenantId,
    );
    user.replaceDetails(details);
    user.enrolledFactors = multiFactorInfoFromJson(record['mfaInfo']);
  }

  String _requireString(Map<dynamic, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.isNotEmpty) return value;
    throw FirebaseAuthException(
      code: 'internal-error',
      message: 'The server response did not include "$key".',
    );
  }
}

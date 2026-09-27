import 'dart:async';

import '../firebase_auth_kit_config.dart';
import '../platform_interface.dart';
import 'rest_firebase_auth.dart';
import 'user_mapper.dart';

/// The ID / refresh token pair held for a signed-in user.
class AuthTokens {
  AuthTokens({
    required this.idToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  String idToken;
  String refreshToken;
  DateTime expiresAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'idToken': idToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt.toUtc().toIso8601String(),
      };

  static AuthTokens fromJson(Map<dynamic, dynamic> json) => AuthTokens(
        idToken: json['idToken'] as String,
        refreshToken: json['refreshToken'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );
}

/// A signed-in user backed by the Identity Toolkit REST API.
class RestUser extends UserPlatform {
  RestUser(
    RestFirebaseAuth super.auth,
    super.multiFactor,
    super.details,
    this.tokens,
  ) : restAuth = auth;

  final RestFirebaseAuth restAuth;

  /// The current tokens; refreshed lazily by [getIdToken].
  AuthTokens tokens;

  Future<String>? _refreshInFlight;

  /// The enrolled second factors reported by the last `accounts:lookup`.
  List<MultiFactorInfo> enrolledFactors = const [];

  /// The current profile record.
  InternalUserDetails get details => userDetails;

  /// Replaces the profile with [details] (after a reload or update).
  void replaceDetails(InternalUserDetails details) {
    userDetails = details;
  }

  /// Keeps the exposed `refreshToken` in step with [tokens].
  set userDetailsRefreshToken(String value) {
    userDetails.userInfo.refreshToken = value;
  }

  /// Applies a new token pair, for example after `accounts:update` or a
  /// second-factor change returns `idToken` / `refreshToken`.
  void applyTokens({String? idToken, String? refreshToken, String? expiresIn}) {
    if (idToken == null || idToken.isEmpty) return;
    final seconds = int.tryParse(expiresIn ?? '') ?? 3600;
    tokens = AuthTokens(
      idToken: idToken,
      refreshToken: (refreshToken == null || refreshToken.isEmpty)
          ? tokens.refreshToken
          : refreshToken,
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: seconds)),
    );
    userDetails.userInfo.refreshToken = tokens.refreshToken;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'details': userDetails.toJson(),
        'tokens': tokens.toJson(),
      };

  // ---------------------------------------------------------------------------
  // Tokens
  // ---------------------------------------------------------------------------

  /// A valid ID token, refreshing it first when it is (about to be) expired.
  Future<String> freshIdToken({bool forceRefresh = false}) {
    final threshold = FirebaseAuthKit.tokenRefreshThreshold;
    final expired = DateTime.now().toUtc().add(threshold).isAfter(tokens.expiresAt);
    if (!forceRefresh && !expired) return Future.value(tokens.idToken);
    return _refreshInFlight ??= _refresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<String> _refresh() async {
    try {
      final response = await restAuth.client.refreshIdToken(tokens.refreshToken);
      tokens = AuthTokens(
        idToken: response.idToken,
        refreshToken: response.refreshToken,
        expiresAt: DateTime.now().toUtc().add(response.expiresIn),
      );
      userDetails.userInfo.refreshToken = tokens.refreshToken;
      await restAuth.persistCurrentUser();
      restAuth.notifyIdTokenChanged(this);
      return tokens.idToken;
    } on FirebaseAuthException catch (e) {
      if (const {
        'user-token-expired',
        'user-disabled',
        'user-not-found',
        'invalid-user-token',
        'invalid-refresh-token',
      }.contains(e.code)) {
        // The session is unrecoverable: mirror the native SDKs and sign out.
        if (identical(restAuth.currentUser, this)) {
          await restAuth.signOut();
        }
      }
      rethrow;
    }
  }

  @override
  Future<String?> getIdToken(bool forceRefresh) {
    return freshIdToken(forceRefresh: forceRefresh);
  }

  @override
  Future<IdTokenResult> getIdTokenResult(bool forceRefresh) async {
    final token = await freshIdToken(forceRefresh: forceRefresh);
    return IdTokenResult(idTokenResultFrom(token));
  }

  // ---------------------------------------------------------------------------
  // Account
  // ---------------------------------------------------------------------------

  @override
  Future<void> delete() async {
    final idToken = await freshIdToken();
    await restAuth.client.post(
      restAuth.client.v1('accounts:delete'),
      {'idToken': idToken},
    );
    if (identical(restAuth.currentUser, this)) {
      await restAuth.signOut();
    }
  }

  @override
  Future<void> reload() async {
    await restAuth.reloadUser(this);
    await restAuth.persistCurrentUser();
    restAuth.notifyUserChanged(this);
  }

  @override
  Future<void> sendEmailVerification(
    ActionCodeSettings? actionCodeSettings,
  ) async {
    final idToken = await freshIdToken();
    await restAuth.client.post(restAuth.client.v1('accounts:sendOobCode'), {
      'requestType': 'VERIFY_EMAIL',
      'idToken': idToken,
      ...actionCodeSettingsToJson(actionCodeSettings),
    });
  }

  @override
  Future<void> verifyBeforeUpdateEmail(
    String newEmail, [
    ActionCodeSettings? actionCodeSettings,
  ]) async {
    final idToken = await freshIdToken();
    await restAuth.client.post(restAuth.client.v1('accounts:sendOobCode'), {
      'requestType': 'VERIFY_AND_CHANGE_EMAIL',
      'idToken': idToken,
      'newEmail': newEmail,
      ...actionCodeSettingsToJson(actionCodeSettings),
    });
  }

  Future<void> _update(Map<String, Object?> fields) async {
    final idToken = await freshIdToken();
    final response = await restAuth.client.post(
      restAuth.client.v1('accounts:update'),
      {'idToken': idToken, 'returnSecureToken': true, ...fields},
    );
    applyTokens(
      idToken: response['idToken'] as String?,
      refreshToken: response['refreshToken'] as String?,
      expiresIn: response['expiresIn']?.toString(),
    );
    await restAuth.reloadUser(this);
    await restAuth.persistCurrentUser();
    restAuth.notifyUserChanged(this);
  }

  @override
  Future<void> updateEmail(String newEmail) => _update({'email': newEmail});

  @override
  Future<void> updatePassword(String newPassword) =>
      _update({'password': newPassword});

  @override
  Future<void> updateProfile(Map<String, String?> profile) {
    final deleteAttribute = <String>[];
    final fields = <String, Object?>{};
    if (profile.containsKey('displayName')) {
      final value = profile['displayName'];
      if (value == null) {
        deleteAttribute.add('DISPLAY_NAME');
      } else {
        fields['displayName'] = value;
      }
    }
    if (profile.containsKey('photoURL')) {
      final value = profile['photoURL'];
      if (value == null) {
        deleteAttribute.add('PHOTO_URL');
      } else {
        fields['photoUrl'] = value;
      }
    }
    if (deleteAttribute.isNotEmpty) fields['deleteAttribute'] = deleteAttribute;
    return _update(fields);
  }

  @override
  Future<void> updatePhoneNumber(PhoneAuthCredential phoneCredential) async {
    await linkWithCredential(phoneCredential);
  }

  @override
  Future<UserPlatform> unlink(String providerId) async {
    await _update({'deleteProvider': <String>[providerId]});
    return this;
  }

  // ---------------------------------------------------------------------------
  // Link / reauthenticate
  // ---------------------------------------------------------------------------

  @override
  Future<UserCredentialPlatform> linkWithCredential(AuthCredential credential) {
    return restAuth.signInWithCredentialInternal(
      credential,
      linkTo: this,
    );
  }

  @override
  Future<UserCredentialPlatform> reauthenticateWithCredential(
    AuthCredential credential,
  ) {
    return restAuth.signInWithCredentialInternal(
      credential,
      reauthenticate: this,
    );
  }

  @override
  Future<UserCredentialPlatform> linkWithProvider(AuthProvider provider) {
    return restAuth.signInWithProviderInternal(
      provider,
      linkTo: this,
      method: 'linkWithProvider',
    );
  }

  @override
  Future<UserCredentialPlatform> reauthenticateWithProvider(
    AuthProvider provider,
  ) {
    return restAuth.signInWithProviderInternal(
      provider,
      reauthenticate: this,
      method: 'reauthenticateWithProvider',
    );
  }

  @override
  Future<ConfirmationResultPlatform> linkWithPhoneNumber(
    String phoneNumber,
    RecaptchaVerifierFactoryPlatform applicationVerifier,
  ) {
    return restAuth.startPhoneSignIn(
      phoneNumber,
      applicationVerifier,
      linkToCurrentUser: true,
    );
  }

  @override
  Future<UserCredentialPlatform> linkWithPopup(AuthProvider provider) {
    throw UnimplementedError(
      'linkWithPopup() is only supported on web based platforms',
    );
  }

  @override
  Future<void> linkWithRedirect(AuthProvider provider) {
    throw UnimplementedError(
      'linkWithRedirect() is only supported on web based platforms',
    );
  }

  @override
  Future<UserCredentialPlatform> reauthenticateWithPopup(
    AuthProvider provider,
  ) {
    throw UnimplementedError(
      'reauthenticateWithPopup() is only supported on web based platforms',
    );
  }

  @override
  Future<void> reauthenticateWithRedirect(AuthProvider provider) {
    throw UnimplementedError(
      'reauthenticateWithRedirect() is only supported on web based platforms',
    );
  }
}

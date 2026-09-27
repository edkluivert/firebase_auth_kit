import 'dart:convert';
import 'dart:io';

/// An in-process stand-in for the Identity Toolkit + Secure Token APIs.
///
/// It implements enough of the v1 / v2 surface for the unit tests: accounts
/// with email/password, anonymous and custom-token sign-in, IdP sign-in,
/// lookup / update / delete, OOB codes, phone verification, token refresh and
/// a minimal TOTP / phone multi-factor flow. Every request is recorded in
/// [requests] so tests can assert on the wire format.
class FakeIdentityToolkit {
  FakeIdentityToolkit._(this._server);

  static Future<FakeIdentityToolkit> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = FakeIdentityToolkit._(server);
    server.listen(fake._handle);
    return fake;
  }

  final HttpServer _server;

  /// `http://127.0.0.1:<port>`, to be used as the emulator origin.
  String get origin => 'http://127.0.0.1:${_server.port}';

  /// Every request received: `{path, body, headers}`.
  final List<({String path, Map<String, Object?> body, HttpHeaders headers})>
      requests = [];

  /// Accounts keyed by localId.
  final Map<String, Map<String, Object?>> accounts = {};

  /// refreshToken → localId.
  final Map<String, String> refreshTokens = {};

  /// oobCode → {requestType, email, newEmail}.
  final Map<String, Map<String, Object?>> oobCodes = {};

  /// sessionInfo → {phoneNumber, code}.
  final Map<String, Map<String, String>> phoneSessions = {};

  /// Pending MFA credentials → localId.
  final Map<String, String> mfaPending = {};

  /// TOTP enrolment sessions → localId.
  final Map<String, String> totpSessions = {};

  /// Set to make the next request fail with this server error message.
  String? failNextWith;

  /// The next response for [path] overrides the built-in handler.
  final Map<String, Map<String, Object?>> canned = {};

  /// Seconds an issued ID token lives for.
  int expiresInSeconds = 3600;

  /// The SMS code the fake "sends".
  String smsCode = '123456';

  /// The `sessionId` of the last redirect-flow signInWithIdp call.
  String? lastSessionId;

  int _counter = 0;

  Future<void> close() => _server.close(force: true);

  String _id(String prefix) => '$prefix${++_counter}';

  String issueIdToken(String localId, {Map<String, Object?> extra = const {}}) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final account = accounts[localId];
    final payload = <String, Object?>{
      'iss': 'https://securetoken.google.com/demo-project',
      'aud': 'demo-project',
      'auth_time': now,
      'user_id': localId,
      'sub': localId,
      'iat': now,
      'exp': now + expiresInSeconds,
      'email': ?account?['email'],
      'firebase': {
        'sign_in_provider': extra['sign_in_provider'] ?? 'password',
        'sign_in_second_factor': ?extra['sign_in_second_factor'],
      },
      ...extra,
    };
    String b64(Object o) =>
        base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
    return '${b64({'alg': 'none', 'typ': 'JWT'})}.${b64(payload)}.sig';
  }

  Map<String, Object?> _tokensFor(String localId, {String provider = 'password'}) {
    final refresh = _id('refresh-');
    refreshTokens[refresh] = localId;
    return {
      'idToken': issueIdToken(localId, extra: {'sign_in_provider': provider}),
      'refreshToken': refresh,
      'expiresIn': '$expiresInSeconds',
      'localId': localId,
    };
  }

  Map<String, Object?> createAccount({
    String? email,
    String? password,
    String? phoneNumber,
    List<Map<String, Object?>> providers = const [],
    bool emailVerified = false,
  }) {
    final localId = _id('uid-');
    final now = DateTime.now().millisecondsSinceEpoch;
    accounts[localId] = {
      'localId': localId,
      'email': ?email,
      'passwordHash': ?(password == null ? null : 'hash:$password'),
      'phoneNumber': ?phoneNumber,
      'emailVerified': emailVerified,
      'providerUserInfo': [
        if (email != null && password != null)
          {
            'providerId': 'password',
            'rawId': email,
            'email': email,
            'federatedId': email,
          },
        if (phoneNumber != null)
          {'providerId': 'phone', 'rawId': phoneNumber, 'phoneNumber': phoneNumber},
        ...providers,
      ],
      'createdAt': '$now',
      'lastLoginAt': '$now',
      'mfaInfo': <Map<String, Object?>>[],
    };
    return accounts[localId]!;
  }

  Map<String, Object?>? _accountByEmail(String email) {
    for (final account in accounts.values) {
      if (account['email'] == email) return account;
    }
    return null;
  }

  Map<String, Object?>? _accountByIdToken(String? idToken) {
    if (idToken == null) return null;
    final parts = idToken.split('.');
    if (parts.length != 3) return null;
    final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map;
    if (payload['exp'] is int &&
        (payload['exp'] as int) < DateTime.now().millisecondsSinceEpoch ~/ 1000) {
      throw _ServerError('TOKEN_EXPIRED');
    }
    return accounts[payload['sub']];
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    final raw = await utf8.decoder.bind(request).join();
    Map<String, Object?> body = {};
    if (raw.isNotEmpty) {
      if (request.headers.contentType?.mimeType ==
          'application/x-www-form-urlencoded') {
        body = Uri.splitQueryString(raw);
      } else {
        body = Map<String, Object?>.from(jsonDecode(raw) as Map);
      }
    }
    requests.add((path: path, body: body, headers: request.headers));
    Object? result;
    int status = 200;
    try {
      final fail = failNextWith;
      if (fail != null) {
        failNextWith = null;
        throw _ServerError(fail);
      }
      final override = canned.remove(path);
      if (override != null) {
        result = override;
      } else {
        result = _dispatch(path, body, request);
      }
    } on _ServerError catch (e) {
      status = e.status;
      result = {
        'error': {
          'code': e.status,
          'message': e.message,
          'errors': [
            {'message': e.message, 'domain': 'global', 'reason': 'invalid'}
          ],
        }
      };
    }
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(result));
    await request.response.close();
  }

  Object? _dispatch(String path, Map<String, Object?> body, HttpRequest req) {
    if (path == '/securetoken.googleapis.com/v1/token') {
      final localId = refreshTokens[body['refresh_token']];
      if (localId == null) throw _ServerError('INVALID_REFRESH_TOKEN');
      if (accounts[localId] == null) throw _ServerError('USER_NOT_FOUND');
      final refresh = _id('refresh-');
      refreshTokens[refresh] = localId;
      return {
        'access_token': issueIdToken(localId),
        'expires_in': '$expiresInSeconds',
        'token_type': 'Bearer',
        'refresh_token': refresh,
        'id_token': issueIdToken(localId),
        'user_id': localId,
        'project_id': 'demo-project',
      };
    }
    const v1 = '/identitytoolkit.googleapis.com/v1/';
    const v2 = '/identitytoolkit.googleapis.com/v2/';
    if (path.startsWith(v1)) {
      return _v1(path.substring(v1.length), body);
    }
    if (path.startsWith(v2)) {
      return _v2(path.substring(v2.length), body, req);
    }
    throw _ServerError('NOT_FOUND', 404);
  }

  Object? _v1(String method, Map<String, Object?> body) {
    switch (method) {
      case 'recaptchaParams':
        return {'recaptchaSiteKey': 'fake-site-key'};
      case 'accounts:signUp':
        final email = body['email'] as String?;
        final linking = _accountByIdToken(body['idToken'] as String?);
        if (linking != null && email != null) {
          final other = _accountByEmail(email);
          if (other != null && other != linking) throw _ServerError('EMAIL_EXISTS');
          final password = body['password'] as String?;
          if (password == null) throw _ServerError('MISSING_PASSWORD');
          if (password.length < 6) throw _ServerError('WEAK_PASSWORD');
          linking['email'] = email;
          linking['passwordHash'] = 'hash:$password';
          (linking['providerUserInfo'] as List)
              .add({'providerId': 'password', 'rawId': email, 'email': email});
          return {..._tokensFor(linking['localId'] as String), 'email': email};
        }
        if (email != null) {
          if (!email.contains('@')) throw _ServerError('INVALID_EMAIL');
          if (_accountByEmail(email) != null) throw _ServerError('EMAIL_EXISTS');
          final password = body['password'] as String?;
          if (password == null) throw _ServerError('MISSING_PASSWORD');
          if (password.length < 6) {
            throw _ServerError('WEAK_PASSWORD : Password should be at least 6 characters');
          }
          final account = createAccount(email: email, password: password);
          return {..._tokensFor(account['localId'] as String), 'email': email};
        }
        final account = createAccount();
        return _tokensFor(account['localId'] as String, provider: 'anonymous');
      case 'accounts:signInWithPassword':
        final account = _accountByEmail(body['email'] as String? ?? '');
        if (account == null) throw _ServerError('EMAIL_NOT_FOUND');
        if (account['passwordHash'] != 'hash:${body['password']}') {
          throw _ServerError('INVALID_LOGIN_CREDENTIALS');
        }
        if (account['disabled'] == true) throw _ServerError('USER_DISABLED');
        final mfa = account['mfaInfo'] as List;
        if (mfa.isNotEmpty) {
          final pending = _id('mfa-pending-');
          mfaPending[pending] = account['localId'] as String;
          return {
            'mfaPendingCredential': pending,
            'mfaInfo': mfa,
            'email': account['email'],
          };
        }
        return {
          ..._tokensFor(account['localId'] as String),
          'email': account['email'],
          'registered': true,
        };
      case 'accounts:signInWithCustomToken':
        final token = body['token'] as String? ?? '';
        if (!token.startsWith('custom:')) throw _ServerError('INVALID_CUSTOM_TOKEN');
        final uid = token.substring('custom:'.length);
        var isNew = false;
        if (!accounts.containsKey(uid)) {
          isNew = true;
          accounts[uid] = {
            'localId': uid,
            'providerUserInfo': <Object?>[],
            'createdAt': '${DateTime.now().millisecondsSinceEpoch}',
            'lastLoginAt': '${DateTime.now().millisecondsSinceEpoch}',
            'mfaInfo': <Object?>[],
          };
        }
        final tokens = _tokensFor(uid, provider: 'custom')..remove('localId');
        return {...tokens, 'isNewUser': isNew};
      case 'accounts:signInWithIdp':
        Map<String, String> params;
        if (body['postBody'] is String) {
          params = Uri.splitQueryString(body['postBody'] as String);
        } else {
          // Redirect flow: the provider response travels in requestUri's query.
          final requestUri = Uri.tryParse(body['requestUri'] as String? ?? '');
          if (requestUri == null || body['sessionId'] == null) {
            throw _ServerError('INVALID_CREDENTIAL_OR_PROVIDER_ID');
          }
          params = Map<String, String>.from(requestUri.queryParameters);
          lastSessionId = body['sessionId'] as String?;
        }
        final providerId = params['providerId']!;
        final idpToken = params['id_token'] ?? params['access_token'] ?? '';
        if (idpToken.isEmpty || idpToken == 'bad') {
          throw _ServerError('INVALID_IDP_RESPONSE : Bad token');
        }
        final email = '$idpToken@$providerId';
        final linking = _accountByIdToken(body['idToken'] as String?);
        var account = _accountByEmail(email);
        if (linking != null) {
          if (account != null && account != linking) {
            return {
              'errorMessage': 'FEDERATED_USER_ID_ALREADY_LINKED',
              'email': email,
              'providerId': providerId,
              'oauthAccessToken': params['access_token'],
              'oauthIdToken': params['id_token'],
            };
          }
          (linking['providerUserInfo'] as List).add({
            'providerId': providerId,
            'rawId': idpToken,
            'email': email,
            'displayName': 'Idp User',
            'federatedId': 'https://$providerId/$idpToken',
          });
          return {
            ..._tokensFor(linking['localId'] as String, provider: providerId),
            'providerId': providerId,
            'email': email,
            'isNewUser': false,
            'oauthAccessToken': params['access_token'],
            'oauthIdToken': params['id_token'],
            'rawUserInfo': jsonEncode({'login': 'octocat', 'id': 1}),
          };
        }
        var isNew = false;
        if (account == null) {
          final conflicting = _accountByEmail('conflict@example.com');
          if (idpToken == 'conflict' && conflicting != null) {
            return {
              'needConfirmation': true,
              'email': 'conflict@example.com',
              'providerId': providerId,
              'oauthAccessToken': params['access_token'],
              'verifiedProvider': ['password'],
            };
          }
          isNew = true;
          account = createAccount(email: email, providers: [
            {
              'providerId': providerId,
              'rawId': idpToken,
              'email': email,
              'displayName': 'Idp User',
              'photoUrl': 'https://example.com/p.png',
              'federatedId': 'https://$providerId/$idpToken',
            }
          ]);
          account['displayName'] = 'Idp User';
          account['photoUrl'] = 'https://example.com/p.png';
        }
        return {
          ..._tokensFor(account['localId'] as String, provider: providerId),
          'providerId': providerId,
          'email': email,
          'isNewUser': isNew,
          'federatedId': 'https://$providerId/$idpToken',
          'oauthAccessToken': params['access_token'],
          'oauthIdToken': params['id_token'],
          'rawUserInfo': jsonEncode({'login': 'octocat', 'id': 1}),
          'displayName': 'Idp User',
          'photoUrl': 'https://example.com/p.png',
        };
      case 'accounts:lookup':
        final account = _accountByIdToken(body['idToken'] as String?);
        if (account == null) throw _ServerError('INVALID_ID_TOKEN');
        return {'users': [account]};
      case 'accounts:update':
        if (body['oobCode'] != null) {
          final oob = oobCodes.remove(body['oobCode']);
          if (oob == null) throw _ServerError('INVALID_OOB_CODE');
          final account = _accountByEmail(oob['email'] as String);
          if (oob['requestType'] == 'VERIFY_EMAIL') account?['emailVerified'] = true;
          if (oob['requestType'] == 'VERIFY_AND_CHANGE_EMAIL') {
            account?['email'] = oob['newEmail'];
          }
          return {'email': oob['email'], 'requestType': oob['requestType']};
        }
        final account = _accountByIdToken(body['idToken'] as String?);
        if (account == null) throw _ServerError('INVALID_ID_TOKEN');
        if (body['displayName'] != null) account['displayName'] = body['displayName'];
        if (body['photoUrl'] != null) account['photoUrl'] = body['photoUrl'];
        for (final attr in (body['deleteAttribute'] as List? ?? const [])) {
          if (attr == 'DISPLAY_NAME') account.remove('displayName');
          if (attr == 'PHOTO_URL') account.remove('photoUrl');
        }
        if (body['email'] != null) {
          final email = body['email'] as String;
          final other = _accountByEmail(email);
          if (other != null && other != account) throw _ServerError('EMAIL_EXISTS');
          account['email'] = email;
          final providers = account['providerUserInfo'] as List;
          if (body['password'] != null &&
              !providers.any((p) => (p as Map)['providerId'] == 'password')) {
            providers.add({'providerId': 'password', 'rawId': email, 'email': email});
          }
        }
        if (body['password'] != null) {
          final password = body['password'] as String;
          if (password.length < 6) throw _ServerError('WEAK_PASSWORD');
          account['passwordHash'] = 'hash:$password';
        }
        for (final provider in (body['deleteProvider'] as List? ?? const [])) {
          (account['providerUserInfo'] as List)
              .removeWhere((p) => (p as Map)['providerId'] == provider);
          if (provider == 'phone') account.remove('phoneNumber');
        }
        return {
          ..._tokensFor(account['localId'] as String),
          'email': account['email'],
          'displayName': account['displayName'],
          'photoUrl': account['photoUrl'],
        };
      case 'accounts:delete':
        final account = _accountByIdToken(body['idToken'] as String?);
        if (account == null) throw _ServerError('INVALID_ID_TOKEN');
        accounts.remove(account['localId']);
        return {};
      case 'accounts:sendOobCode':
        final type = body['requestType'] as String;
        String? email = body['email'] as String?;
        if (body['idToken'] != null) {
          email = _accountByIdToken(body['idToken'] as String)?['email'] as String?;
        }
        if (email == null) throw _ServerError('MISSING_EMAIL');
        if (type == 'PASSWORD_RESET' && _accountByEmail(email) == null) {
          throw _ServerError('EMAIL_NOT_FOUND');
        }
        final code = _id('oob-');
        oobCodes[code] = {
          'requestType': type,
          'email': email,
          'newEmail': body['newEmail'],
        };
        return {'email': email, 'oobCode': code};
      case 'accounts:resetPassword':
        final code = body['oobCode'] as String;
        final oob = oobCodes[code];
        if (oob == null) throw _ServerError('INVALID_OOB_CODE');
        if (body['newPassword'] != null) {
          final account = _accountByEmail(oob['email'] as String);
          if ((body['newPassword'] as String).length < 6) {
            throw _ServerError('WEAK_PASSWORD');
          }
          account?['passwordHash'] = 'hash:${body['newPassword']}';
          oobCodes.remove(code);
        }
        return {
          'email': oob['email'],
          'requestType': oob['requestType'],
          if (oob['newEmail'] != null) 'newEmail': oob['newEmail'],
        };
      case 'accounts:signInWithEmailLink':
        final oob = oobCodes.remove(body['oobCode']);
        if (oob == null || oob['requestType'] != 'EMAIL_SIGNIN') {
          throw _ServerError('INVALID_OOB_CODE');
        }
        final email = body['email'] as String;
        var account = _accountByEmail(email);
        var isNew = false;
        if (account == null) {
          isNew = true;
          account = createAccount(email: email, emailVerified: true);
        }
        return {
          ..._tokensFor(account['localId'] as String, provider: 'password'),
          'email': email,
          'isNewUser': isNew,
        };
      case 'accounts:sendVerificationCode':
        final phone = body['phoneNumber'] as String?;
        if (phone == null || !phone.startsWith('+')) {
          throw _ServerError('INVALID_PHONE_NUMBER');
        }
        final session = _id('session-');
        phoneSessions[session] = {'phoneNumber': phone, 'code': smsCode};
        return {'sessionInfo': session};
      case 'accounts:signInWithPhoneNumber':
        final session = phoneSessions.remove(body['sessionInfo']);
        if (session == null) throw _ServerError('INVALID_SESSION_INFO');
        if (session['code'] != body['code']) throw _ServerError('INVALID_CODE');
        final phone = session['phoneNumber']!;
        final linking = _accountByIdToken(body['idToken'] as String?);
        if (linking != null) {
          linking['phoneNumber'] = phone;
          (linking['providerUserInfo'] as List)
              .add({'providerId': 'phone', 'rawId': phone, 'phoneNumber': phone});
          return {
            ..._tokensFor(linking['localId'] as String, provider: 'phone'),
            'phoneNumber': phone,
            'isNewUser': false,
          };
        }
        var account = accounts.values
            .where((a) => a['phoneNumber'] == phone)
            .cast<Map<String, Object?>?>()
            .firstOrNull;
        var isNew = false;
        if (account == null) {
          isNew = true;
          account = createAccount(phoneNumber: phone);
        }
        return {
          ..._tokensFor(account['localId'] as String, provider: 'phone'),
          'phoneNumber': phone,
          'isNewUser': isNew,
        };
      case 'accounts:createAuthUri':
        final account = _accountByEmail(body['identifier'] as String? ?? '');
        return {
          'registered': account != null,
          'signinMethods': [
            if (account != null)
              for (final p in account['providerUserInfo'] as List)
                (p as Map<Object?, Object?>)['providerId'],
          ],
        };
    }
    throw _ServerError('UNKNOWN_METHOD $method', 404);
  }

  Object? _v2(String method, Map<String, Object?> body, HttpRequest req) {
    switch (method) {
      case 'accounts/mfaEnrollment:start':
        final account = _accountByIdToken(body['idToken'] as String?);
        if (account == null) throw _ServerError('INVALID_ID_TOKEN');
        if (body['totpEnrollmentInfo'] != null) {
          final session = _id('totp-session-');
          totpSessions[session] = account['localId'] as String;
          return {
            'totpSessionInfo': {
              'sharedSecretKey': 'JBSWY3DPEHPK3PXP',
              'verificationCodeLength': 6,
              'hashingAlgorithm': 'SHA1',
              'periodSec': 30,
              'sessionInfo': session,
              'finalizeEnrollmentTime': '2030-01-01T00:00:00Z',
            }
          };
        }
        final phoneInfo = body['phoneEnrollmentInfo'] as Map?;
        final phone = phoneInfo?['phoneNumber'] as String?;
        if (phone == null) throw _ServerError('MISSING_PHONE_NUMBER');
        final session = _id('mfa-phone-session-');
        phoneSessions[session] = {'phoneNumber': phone, 'code': smsCode};
        return {'phoneSessionInfo': {'sessionInfo': session}};
      case 'accounts/mfaEnrollment:finalize':
        final account = _accountByIdToken(body['idToken'] as String?);
        if (account == null) throw _ServerError('INVALID_ID_TOKEN');
        final mfa = account['mfaInfo'] as List;
        final totp = body['totpVerificationInfo'] as Map?;
        final phone = body['phoneVerificationInfo'] as Map?;
        if (totp != null) {
          if (totpSessions.remove(totp['sessionInfo']) == null) {
            throw _ServerError('INVALID_SESSION_INFO');
          }
          if (totp['verificationCode'] != '000000') throw _ServerError('INVALID_CODE');
          mfa.add({
            'mfaEnrollmentId': _id('enrollment-'),
            'displayName': body['displayName'],
            'enrolledAt': DateTime.now().toUtc().toIso8601String(),
            'totpInfo': <String, Object?>{},
          });
        } else if (phone != null) {
          final session = phoneSessions.remove(phone['sessionInfo']);
          if (session == null) throw _ServerError('INVALID_SESSION_INFO');
          if (session['code'] != phone['code']) throw _ServerError('INVALID_CODE');
          mfa.add({
            'mfaEnrollmentId': _id('enrollment-'),
            'displayName': body['displayName'],
            'enrolledAt': DateTime.now().toUtc().toIso8601String(),
            'phoneInfo': session['phoneNumber'],
          });
        } else {
          throw _ServerError('INVALID_ARGUMENT');
        }
        return _tokensFor(account['localId'] as String)..remove('localId');
      case 'accounts/mfaEnrollment:withdraw':
        final account = _accountByIdToken(body['idToken'] as String?);
        if (account == null) throw _ServerError('INVALID_ID_TOKEN');
        final mfa = account['mfaInfo'] as List;
        final before = mfa.length;
        mfa.removeWhere((e) => (e as Map)['mfaEnrollmentId'] == body['mfaEnrollmentId']);
        if (mfa.length == before) throw _ServerError('MFA_ENROLLMENT_NOT_FOUND');
        return _tokensFor(account['localId'] as String)..remove('localId');
      case 'accounts/mfaSignIn:start':
        final localId = mfaPending[body['mfaPendingCredential']];
        if (localId == null) throw _ServerError('INVALID_MFA_PENDING_CREDENTIAL');
        final account = accounts[localId]!;
        final factor = (account['mfaInfo'] as List).cast<Map<Object?, Object?>>().firstWhere(
            (e) => e['mfaEnrollmentId'] == body['mfaEnrollmentId'],
            orElse: () => throw _ServerError('MFA_ENROLLMENT_NOT_FOUND'));
        final session = _id('mfa-signin-session-');
        phoneSessions[session] = {'phoneNumber': factor['phoneInfo'] as String, 'code': smsCode};
        return {'phoneResponseInfo': {'sessionInfo': session}};
      case 'accounts/mfaSignIn:finalize':
        final localId = mfaPending.remove(body['mfaPendingCredential']);
        if (localId == null) throw _ServerError('INVALID_MFA_PENDING_CREDENTIAL');
        final totp = body['totpVerificationInfo'] as Map?;
        final phone = body['phoneVerificationInfo'] as Map?;
        String factor;
        if (totp != null) {
          if (totp['verificationCode'] != '000000') throw _ServerError('INVALID_CODE');
          factor = 'totp';
        } else if (phone != null) {
          final session = phoneSessions.remove(phone['sessionInfo']);
          if (session == null) throw _ServerError('INVALID_SESSION_INFO');
          if (session['code'] != phone['code']) throw _ServerError('INVALID_CODE');
          factor = 'phone';
        } else {
          throw _ServerError('INVALID_ARGUMENT');
        }
        final refresh = _id('refresh-');
        refreshTokens[refresh] = localId;
        return {
          'idToken': issueIdToken(localId, extra: {'sign_in_second_factor': factor}),
          'refreshToken': refresh,
        };
      case 'accounts:revokeToken':
        return {};
      case 'recaptchaConfig':
        return {'recaptchaKey': 'projects/1/keys/abc'};
    }
    throw _ServerError('UNKNOWN_METHOD $method', 404);
  }
}

class _ServerError implements Exception {
  _ServerError(this.message, [this.status = 400]);
  final String message;
  final int status;
}

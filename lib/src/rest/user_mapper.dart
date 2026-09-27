import 'dart:convert';

import '../platform_interface.dart';
import 'jwt.dart';

/// Builds [InternalUserDetails] from an `accounts:lookup` user record.
InternalUserDetails userDetailsFromLookup(
  Map<String, Object?> record, {
  required String refreshToken,
  bool? isAnonymousHint,
  String? tenantId,
}) {
  final providerUserInfo =
      (record['providerUserInfo'] as List<Object?>? ?? const [])
          .whereType<Map<Object?, Object?>>()
          .toList();
  final email = _nonEmpty(record['email'] as String?);
  final phoneNumber = _nonEmpty(record['phoneNumber'] as String?);
  final providerData = <Map<Object?, Object?>?>[
    for (final info in providerUserInfo)
      <Object?, Object?>{
        'uid': (info['rawId'] ?? info['federatedId'] ?? '') as String,
        'email': info['email'],
        'displayName': info['displayName'],
        'photoUrl': info['photoUrl'],
        'phoneNumber': info['phoneNumber'],
        'isAnonymous': false,
        'isEmailVerified': false,
        'providerId': info['providerId'],
      },
  ];
  final isAnonymous = providerUserInfo.isEmpty &&
      email == null &&
      phoneNumber == null &&
      (isAnonymousHint ?? true);
  return InternalUserDetails(
    userInfo: InternalUserInfo(
      uid: record['localId'] as String,
      email: email,
      displayName: _nonEmpty(record['displayName'] as String?),
      photoUrl: _nonEmpty(record['photoUrl'] as String?),
      phoneNumber: phoneNumber,
      isAnonymous: isAnonymous,
      isEmailVerified: record['emailVerified'] == true,
      providerId: 'firebase',
      tenantId: _nonEmpty(record['tenantId'] as String?) ?? tenantId,
      refreshToken: refreshToken,
      creationTimestamp: _parseMillis(record['createdAt']),
      lastSignInTimestamp: _parseMillis(record['lastLoginAt']),
    ),
    providerData: providerData,
  );
}

/// Converts the `mfaInfo` entries of a lookup / sign-in response.
List<MultiFactorInfo> multiFactorInfoFromJson(Object? raw) {
  if (raw is! List) return const [];
  return raw.whereType<Map<Object?, Object?>>().map((e) {
    final uid = (e['mfaEnrollmentId'] ?? '') as String;
    final displayName = e['displayName'] as String?;
    final enrolledAt = e['enrolledAt'];
    double enrollmentTimestamp = 0;
    if (enrolledAt is String) {
      final parsed = DateTime.tryParse(enrolledAt);
      if (parsed != null) {
        enrollmentTimestamp = parsed.millisecondsSinceEpoch.toDouble();
      }
    }
    final phoneInfo = e['phoneInfo'];
    if (phoneInfo is String) {
      return PhoneMultiFactorInfo(
        displayName: displayName,
        enrollmentTimestamp: enrollmentTimestamp,
        factorId: PhoneMultiFactorGenerator.factorId,
        uid: uid,
        phoneNumber: phoneInfo,
      );
    }
    if (e.containsKey('totpInfo')) {
      return TotpMultiFactorInfo(
        displayName: displayName,
        enrollmentTimestamp: enrollmentTimestamp,
        factorId: TotpMultiFactorGenerator.factorId,
        uid: uid,
      );
    }
    return MultiFactorInfo(
      displayName: displayName,
      enrollmentTimestamp: enrollmentTimestamp,
      factorId: '',
      uid: uid,
    );
  }).toList();
}

/// Factor id constants, matching the native SDKs.
abstract final class PhoneMultiFactorGenerator {
  static const String factorId = 'phone';
}

/// Factor id constants, matching the native SDKs.
abstract final class TotpMultiFactorGenerator {
  static const String factorId = 'totp';
}

/// The credential returned to callers after `signInWithIdp`.
OAuthCredential? credentialFromIdpResponse(Map<String, Object?> json) {
  final providerId = json['providerId'] as String?;
  if (providerId == null) return null;
  final accessToken = json['oauthAccessToken'] as String?;
  final idToken = json['oauthIdToken'] as String?;
  final secret = json['oauthTokenSecret'] as String?;
  if (accessToken == null && idToken == null && secret == null) return null;
  return OAuthProvider(providerId).credential(
    accessToken: accessToken,
    idToken: idToken,
    secret: secret,
    signInMethod: providerId,
  );
}

/// The [AdditionalUserInfo] for a sign-in response.
AdditionalUserInfo additionalUserInfoFromResponse(
  Map<String, Object?> json, {
  required bool isNewUser,
  String? providerId,
}) {
  Map<String, dynamic>? profile;
  final raw = json['rawUserInfo'];
  if (raw is String && raw.isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) profile = Map<String, dynamic>.from(decoded);
    } on FormatException {
      profile = null;
    }
  }
  final resolvedProvider = providerId ?? json['providerId'] as String?;
  String? username;
  if (profile != null) {
    username = switch (resolvedProvider) {
      'github.com' => profile['login'] as String?,
      'twitter.com' => profile['screen_name'] as String?,
      _ => json['screenName'] as String?,
    };
  }
  return AdditionalUserInfo(
    isNewUser: isNewUser,
    profile: profile ?? const {},
    providerId: resolvedProvider,
    username: username,
  );
}

/// Decodes [idToken] into an [InternalIdTokenResult].
InternalIdTokenResult idTokenResultFrom(String idToken) {
  final claims = decodeJwtPayload(idToken) ?? const {};
  int? seconds(Object? v) => v is num ? (v * 1000).round() : null;
  final firebase = claims['firebase'];
  return InternalIdTokenResult(
    token: idToken,
    expirationTimestamp: seconds(claims['exp']),
    authTimestamp: seconds(claims['auth_time']),
    issuedAtTimestamp: seconds(claims['iat']),
    signInProvider:
        firebase is Map ? firebase['sign_in_provider'] as String? : null,
    signInSecondFactor:
        firebase is Map ? firebase['sign_in_second_factor'] as String? : null,
    claims: Map<String?, Object?>.from(claims),
  );
}

/// Extracts the `oobCode` from an email sign-in link, unwrapping Dynamic
/// Links / Hosting links whose target is carried in a `link` parameter.
String? oobCodeFromEmailLink(String emailLink) {
  final uri = Uri.tryParse(emailLink);
  if (uri == null) return null;
  final direct = uri.queryParameters['oobCode'];
  if (direct != null && direct.isNotEmpty) return direct;
  final nested = uri.queryParameters['link'];
  if (nested != null) {
    final inner = Uri.tryParse(nested);
    final code = inner?.queryParameters['oobCode'];
    if (code != null && code.isNotEmpty) return code;
  }
  return null;
}

/// Maps `ActionCodeSettings` to the `sendOobCode` request fields.
Map<String, Object?> actionCodeSettingsToJson(ActionCodeSettings? settings) {
  if (settings == null) return const {};
  return <String, Object?>{
    'continueUrl': settings.url,
    'canHandleCodeInApp': settings.handleCodeInApp,
    'iOSBundleId': settings.iOSBundleId,
    'androidPackageName': settings.androidPackageName,
    'androidInstallApp': settings.androidInstallApp,
    'androidMinimumVersion': settings.androidMinimumVersion,
    'linkDomain': settings.linkDomain,
  };
}

int? _parseMillis(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String? _nonEmpty(String? value) =>
    (value == null || value.isEmpty) ? null : value;

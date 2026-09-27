// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Plain-Dart counterparts of the Pigeon message classes that
// `firebase_auth_platform_interface` generates for its method channels.
//
// firebase_auth_kit has no native side, so these are ordinary immutable-ish
// data holders with JSON codecs (used to persist the signed-in user).

/// The type of operation that generated the action code from calling
/// `checkActionCode`.
enum ActionCodeInfoOperation {
  /// Unknown operation.
  unknown,

  /// Password reset code generated via [sendPasswordResetEmail].
  passwordReset,

  /// Email verification code generated via [User.sendEmailVerification].
  verifyEmail,

  /// Email change revocation code generated via [User.updateEmail].
  recoverEmail,

  /// Email sign in code generated via [sendSignInLinkToEmail].
  emailSignIn,

  /// Verify and change email code generated via [User.verifyBeforeUpdateEmail].
  verifyAndChangeEmail,

  /// Action code for reverting second factor addition.
  revertSecondFactorAddition,
}

/// The core profile of a user (or of one linked provider account).
class InternalUserInfo {
  InternalUserInfo({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.phoneNumber,
    required this.isAnonymous,
    required this.isEmailVerified,
    this.providerId,
    this.tenantId,
    this.refreshToken,
    this.creationTimestamp,
    this.lastSignInTimestamp,
  });

  String uid;
  String? email;
  String? displayName;
  String? photoUrl;
  String? phoneNumber;
  bool isAnonymous;
  bool isEmailVerified;
  String? providerId;
  String? tenantId;
  String? refreshToken;

  /// Milliseconds since epoch.
  int? creationTimestamp;

  /// Milliseconds since epoch.
  int? lastSignInTimestamp;

  Map<String, Object?> toJson() => <String, Object?>{
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'phoneNumber': phoneNumber,
        'isAnonymous': isAnonymous,
        'isEmailVerified': isEmailVerified,
        'providerId': providerId,
        'tenantId': tenantId,
        'refreshToken': refreshToken,
        'creationTimestamp': creationTimestamp,
        'lastSignInTimestamp': lastSignInTimestamp,
      };

  static InternalUserInfo fromJson(Map<dynamic, dynamic> json) {
    return InternalUserInfo(
      uid: json['uid'] as String,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      isAnonymous: json['isAnonymous'] as bool? ?? false,
      isEmailVerified: json['isEmailVerified'] as bool? ?? false,
      providerId: json['providerId'] as String?,
      tenantId: json['tenantId'] as String?,
      refreshToken: json['refreshToken'] as String?,
      creationTimestamp: (json['creationTimestamp'] as num?)?.toInt(),
      lastSignInTimestamp: (json['lastSignInTimestamp'] as num?)?.toInt(),
    );
  }

  /// Kept for source compatibility with the Pigeon class; accepts the JSON
  /// produced by [toJson].
  static InternalUserInfo decode(Object result) =>
      fromJson(result as Map<dynamic, dynamic>);

  InternalUserInfo copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    String? phoneNumber,
    bool? isAnonymous,
    bool? isEmailVerified,
    String? providerId,
    String? tenantId,
    String? refreshToken,
    int? creationTimestamp,
    int? lastSignInTimestamp,
  }) {
    return InternalUserInfo(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      providerId: providerId ?? this.providerId,
      tenantId: tenantId ?? this.tenantId,
      refreshToken: refreshToken ?? this.refreshToken,
      creationTimestamp: creationTimestamp ?? this.creationTimestamp,
      lastSignInTimestamp: lastSignInTimestamp ?? this.lastSignInTimestamp,
    );
  }
}

/// A user profile together with the linked provider accounts.
class InternalUserDetails {
  InternalUserDetails({
    required this.userInfo,
    required this.providerData,
  });

  InternalUserInfo userInfo;

  /// Each entry has the keys of [InternalUserInfo.toJson].
  List<Map<Object?, Object?>?> providerData;

  Map<String, Object?> toJson() => <String, Object?>{
        'userInfo': userInfo.toJson(),
        'providerData': providerData,
      };

  static InternalUserDetails fromJson(Map<dynamic, dynamic> json) {
    final rawInfo = json['userInfo'];
    final providerData = (json['providerData'] as List<Object?>? ?? const [])
        .map((e) => e == null ? null : Map<Object?, Object?>.from(e as Map))
        .toList();
    return InternalUserDetails(
      userInfo: rawInfo is InternalUserInfo
          ? rawInfo
          : InternalUserInfo.fromJson(rawInfo as Map<dynamic, dynamic>),
      providerData: providerData,
    );
  }

  /// Kept for source compatibility with the Pigeon class; accepts either the
  /// JSON produced by [toJson] or the two-element list Pigeon used.
  static InternalUserDetails decode(Object result) {
    if (result is List<Object?>) {
      final first = result[0];
      return InternalUserDetails(
        userInfo: first is InternalUserInfo
            ? first
            : InternalUserInfo.fromJson(first as Map<dynamic, dynamic>),
        providerData: (result[1] as List<Object?>)
            .map((e) =>
                e == null ? null : Map<Object?, Object?>.from(e as Map))
            .toList(),
      );
    }
    return fromJson(result as Map<dynamic, dynamic>);
  }
}

/// The decoded contents of an ID token.
class InternalIdTokenResult {
  InternalIdTokenResult({
    this.token,
    this.expirationTimestamp,
    this.authTimestamp,
    this.issuedAtTimestamp,
    this.signInProvider,
    this.claims,
    this.signInSecondFactor,
  });

  String? token;

  /// Milliseconds since epoch.
  int? expirationTimestamp;

  /// Milliseconds since epoch.
  int? authTimestamp;

  /// Milliseconds since epoch.
  int? issuedAtTimestamp;
  String? signInProvider;
  Map<String?, Object?>? claims;
  String? signInSecondFactor;
}

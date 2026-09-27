// ignore_for_file: require_trailing_commas, prefer_final_fields, use_super_parameters, non_constant_identifier_names, constant_identifier_names, no_leading_underscores_for_local_identifiers, unnecessary_import
// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../firebase_auth_kit.dart';

/// A UserCredential is returned from authentication requests such as
/// [createUserWithEmailAndPassword].
class UserCredential {
  UserCredential._(this._auth, this._delegate) {
    UserCredentialPlatform.verify(_delegate);
  }

  final FirebaseAuth _auth;
  final UserCredentialPlatform _delegate;

  /// Returns additional information about the user, such as whether they are a
  /// newly created one.
  AdditionalUserInfo? get additionalUserInfo => _delegate.additionalUserInfo;

  /// The users [AuthCredential].
  AuthCredential? get credential => _delegate.credential;

  /// Returns a [User] containing additional information and user specific
  /// methods.
  User? get user {
    // TODO(rousselGit): cache the `user` instance or override == so that ".user == .user"
    return _delegate.user == null ? null : User._(_auth, _delegate.user!);
  }

  @override
  String toString() {
    return 'UserCredential('
        'additionalUserInfo: $additionalUserInfo, '
        'credential: $credential, '
        'user: $user)';
  }
}

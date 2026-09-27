// ignore_for_file: require_trailing_commas, prefer_final_fields, use_super_parameters, non_constant_identifier_names, constant_identifier_names, no_leading_underscores_for_local_identifiers, unnecessary_import
// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:firebase_auth_kit/platform_interface.dart';

/// A UserCredential is returned from authentication requests such as
/// [createUserWithEmailAndPassword].
abstract class UserCredentialPlatform extends PlatformInterface {
  // ignore: public_member_api_docs
  UserCredentialPlatform({
    required this.auth,
    this.additionalUserInfo,
    this.credential,
    this.user,
  }) : super(token: _token);

  static final Object _token = Object();

  /// Ensures that any delegate class has extended a [UserCredentialPlatform].
  static void verify(UserCredentialPlatform instance) {
    PlatformInterface.verify(instance, _token);
  }

  /// The current FirebaseAuth instance.
  final FirebaseAuthPlatform auth;

  /// Returns additional information about the user, such as whether they are a
  /// newly created one.
  final AdditionalUserInfo? additionalUserInfo;

  /// The users [AuthCredential].
  final AuthCredential? credential;

  /// Returns a [UserPlatform] containing additional information and user
  /// specific methods.
  final UserPlatform? user;
}

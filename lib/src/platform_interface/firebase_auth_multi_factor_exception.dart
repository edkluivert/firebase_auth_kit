// ignore_for_file: require_trailing_commas, prefer_final_fields, use_super_parameters, non_constant_identifier_names, constant_identifier_names, no_leading_underscores_for_local_identifiers, unnecessary_import
// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:firebase_auth_kit/platform_interface.dart';
import 'package:meta/meta.dart';

/// MultiFactor exception related to Firebase Authentication. Check the error code
/// and message for more details.
class FirebaseAuthMultiFactorExceptionPlatform extends FirebaseAuthException
    implements Exception {
  // ignore: public_member_api_docs
  @protected
  FirebaseAuthMultiFactorExceptionPlatform({
    String? message,
    required String code,
    String? email,
    AuthCredential? credential,
    String? phoneNumber,
    String? tenantId,
    required this.resolver,
  }) : super(
          message: message,
          code: code,
          email: email,
          credential: credential,
          phoneNumber: phoneNumber,
          tenantId: tenantId,
        );

  final MultiFactorResolverPlatform resolver;
}

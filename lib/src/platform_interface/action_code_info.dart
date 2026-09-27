// ignore_for_file: require_trailing_commas, prefer_final_fields, use_super_parameters, non_constant_identifier_names, constant_identifier_names, no_leading_underscores_for_local_identifiers, unnecessary_import
// Copyright 2020, the Chromium project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:firebase_auth_kit/src/platform_interface/internal_types.dart';
import 'package:meta/meta.dart';

/// A response from calling [checkActionCode].
class ActionCodeInfo {
  // ignore: public_member_api_docs
  @protected
  ActionCodeInfo({
    required this.operation,
    required ActionCodeInfoData data,
  }) : _data = data;

  ActionCodeInfoOperation operation;

  ActionCodeInfoData _data;

  Map<String, dynamic> get data => _data.toMap();
}

/// The data associated with the action code.
///
/// Depending on the [ActionCodeInfoOperation], `email` and `previousEmail`
/// may be available.
class ActionCodeInfoData {
  // ignore: public_member_api_docs
  @protected
  ActionCodeInfoData({
    required this.email,
    required this.previousEmail,
  });

  /// The email associated with the action code.
  final String? email;

  /// The previous email associated with the action code.
  final String? previousEmail;

  /// Converts the [ActionCodeInfoData] instance to a [Map].
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'email': email,
      'previousEmail': previousEmail,
    };
  }
}

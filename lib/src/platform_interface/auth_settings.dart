// ignore_for_file: require_trailing_commas, prefer_final_fields, use_super_parameters, non_constant_identifier_names, constant_identifier_names, no_leading_underscores_for_local_identifiers, unnecessary_import
// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Interface representing an Auth instance's settings, currently used for
/// enabling/disabling app verification for phone Auth testing.
class AuthSettings {
  /// Constructs a new [AuthSettings] instance with given settings.
  const AuthSettings({this.appVerificationDisabledForTesting});

  /// Default is false. When set, this property disabled app verification
  /// for the purpose of testing phone authentication. For this property to
  /// take effect, it needs to be set before rendering a reCAPTCHA app verifier.
  final bool? appVerificationDisabledForTesting;
}

// ignore_for_file: require_trailing_commas, prefer_final_fields, use_super_parameters, non_constant_identifier_names, constant_identifier_names, no_leading_underscores_for_local_identifiers, unnecessary_import
// Copyright 2025, the Chromium project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'password_policy.dart';

class PasswordValidationStatus {
  bool isValid;
  final PasswordPolicy passwordPolicy;

  // Initialize all fields to true by default (meaning they pass validation)
  bool meetsMinPasswordLength = true;
  bool meetsMaxPasswordLength = true;
  bool meetsLowercaseRequirement = true;
  bool meetsUppercaseRequirement = true;
  bool meetsDigitsRequirement = true;
  bool meetsSymbolsRequirement = true;

  PasswordValidationStatus(this.isValid, this.passwordPolicy);
}

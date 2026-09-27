// ignore_for_file: require_trailing_commas, prefer_final_fields, use_super_parameters, non_constant_identifier_names, constant_identifier_names, no_leading_underscores_for_local_identifiers, unnecessary_import
// Copyright 2025, the Chromium project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
class PasswordPolicy {
  final Map<String, dynamic> policy;

  // Backend enforced minimum
  late final int minPasswordLength;
  late final int? maxPasswordLength;
  late final bool? containsLowercaseCharacter;
  late final bool? containsUppercaseCharacter;
  late final bool? containsNumericCharacter;
  late final bool? containsNonAlphanumericCharacter;
  late final int schemaVersion;
  late final List<String> allowedNonAlphanumericCharacters;
  late final String enforcementState;

  PasswordPolicy(this.policy) {
    initialize();
  }

  void initialize() {
    final Map<String, dynamic> customStrengthOptions =
        (policy['customStrengthOptions'] as Map<String, dynamic>?) ?? {};

    minPasswordLength =
        (customStrengthOptions['minPasswordLength'] as int?) ?? 6;
    maxPasswordLength = customStrengthOptions['maxPasswordLength'] as int?;
    containsLowercaseCharacter =
        customStrengthOptions['containsLowercaseCharacter'] as bool?;
    containsUppercaseCharacter =
        customStrengthOptions['containsUppercaseCharacter'] as bool?;
    containsNumericCharacter =
        customStrengthOptions['containsNumericCharacter'] as bool?;
    containsNonAlphanumericCharacter =
        customStrengthOptions['containsNonAlphanumericCharacter'] as bool?;

    schemaVersion = (policy['schemaVersion'] as int?) ?? 1;
    allowedNonAlphanumericCharacters = List<String>.from(
      (policy['allowedNonAlphanumericCharacters'] ??
          customStrengthOptions['allowedNonAlphanumericCharacters'] ??
          <String>[]) as Iterable<dynamic>,
    );

    final enforcement =
        (policy['enforcement'] ?? policy['enforcementState']) as String?;
    enforcementState = enforcement == 'ENFORCEMENT_STATE_UNSPECIFIED'
        ? 'OFF'
        : (enforcement ?? 'OFF');
  }
}

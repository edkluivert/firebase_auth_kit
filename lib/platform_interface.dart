// ignore_for_file: require_trailing_commas
// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The platform-interface layer of `firebase_auth_kit`, mirroring
/// `firebase_auth_platform_interface`.
///
/// Most apps only need `package:firebase_auth_kit/firebase_auth_kit.dart`;
/// import this library to build an alternative `FirebaseAuthPlatform`
/// implementation or to reach the delegate types directly.
library;

export 'src/core/firebase_core.dart';
export 'src/platform_interface/action_code_info.dart';
export 'src/platform_interface/action_code_settings.dart';
export 'src/platform_interface/additional_user_info.dart';
export 'src/platform_interface/auth_credential.dart';
export 'src/platform_interface/auth_provider.dart';
export 'src/platform_interface/auth_settings.dart';
export 'src/platform_interface/firebase_auth_exception.dart';
export 'src/platform_interface/firebase_auth_multi_factor_exception.dart';
export 'src/platform_interface/id_token_result.dart';
export 'src/platform_interface/internal_types.dart'
    show
        InternalUserDetails,
        InternalUserInfo,
        ActionCodeInfoOperation,
        InternalIdTokenResult;
export 'src/platform_interface/platform_interface_confirmation_result.dart';
export 'src/platform_interface/platform_interface_firebase_auth.dart';
export 'src/platform_interface/platform_interface_multi_factor.dart';
export 'src/platform_interface/platform_interface_recaptcha_verifier_factory.dart';
export 'src/platform_interface/platform_interface_user.dart';
export 'src/platform_interface/platform_interface_user_credential.dart';
export 'src/platform_interface/providers/apple_auth.dart';
export 'src/platform_interface/providers/email_auth.dart';
export 'src/platform_interface/providers/facebook_auth.dart';
export 'src/platform_interface/providers/game_center_auth.dart';
export 'src/platform_interface/providers/github_auth.dart';
export 'src/platform_interface/providers/google_auth.dart';
export 'src/platform_interface/providers/microsoft_auth.dart';
export 'src/platform_interface/providers/oauth.dart';
export 'src/platform_interface/providers/phone_auth.dart';
export 'src/platform_interface/providers/saml_auth.dart';
export 'src/platform_interface/providers/twitter_auth.dart';
export 'src/platform_interface/providers/yahoo_auth.dart';
export 'src/platform_interface/providers/play_games_auth.dart';
export 'src/platform_interface/types.dart';
export 'src/platform_interface/user_info.dart';
export 'src/platform_interface/user_metadata.dart';
export 'src/platform_interface/password_policy/password_policy_api.dart';
export 'src/platform_interface/password_policy/password_policy_impl.dart';
export 'src/platform_interface/password_policy/password_policy.dart';
export 'src/platform_interface/password_policy/password_validation_status.dart';

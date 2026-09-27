// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Firebase Authentication for DartNative, in pure Dart.
///
/// The `firebase_auth` API (FlutterFire 6.7.0), implemented on top of the
/// Identity Toolkit REST API instead of the native Firebase SDKs.
library;

import 'dart:async';

import 'package:meta/meta.dart';

import 'src/platform_interface.dart';
import 'src/rest/rest_firebase_auth.dart';

export 'src/core/firebase_core.dart'
    show FirebaseApp, FirebaseOptions, FirebaseException, defaultFirebaseAppName;
export 'src/errors/firebase_auth_error_code.dart';
export 'src/errors/firebase_auth_exception_extensions.dart';
export 'src/firebase_auth_kit_config.dart';
export 'src/platform_interface.dart'
    show
        FirebaseAuthException,
        MultiFactorInfo,
        MultiFactorSession,
        PhoneMultiFactorInfo,
        TotpMultiFactorInfo,
        IdTokenResult,
        UserMetadata,
        UserInfo,
        ActionCodeInfo,
        ActionCodeSettings,
        AdditionalUserInfo,
        ActionCodeInfoOperation,
        Persistence,
        PhoneVerificationCompleted,
        PhoneVerificationFailed,
        PhoneCodeSent,
        PhoneCodeAutoRetrievalTimeout,
        AuthCredential,
        AuthProvider,
        AppleAuthProvider,
        AppleFullPersonName,
        AppleAuthCredential,
        EmailAuthProvider,
        EmailAuthCredential,
        FacebookAuthProvider,
        FacebookAuthCredential,
        GameCenterAuthProvider,
        GameCenterAuthCredential,
        PlayGamesAuthProvider,
        PlayGamesAuthCredential,
        GithubAuthProvider,
        GithubAuthCredential,
        GoogleAuthProvider,
        GoogleAuthCredential,
        YahooAuthProvider,
        YahooAuthCredential,
        MicrosoftAuthProvider,
        OAuthProvider,
        OAuthCredential,
        PhoneAuthProvider,
        PhoneAuthCredential,
        SAMLAuthProvider,
        TwitterAuthProvider,
        TwitterAuthCredential,
        RecaptchaVerifierOnSuccess,
        RecaptchaVerifierOnExpired,
        RecaptchaVerifierOnError,
        RecaptchaVerifierSize,
        RecaptchaVerifierTheme,
        PasswordValidationStatus,
        FirebaseAuthPlatform;
export 'src/rest/auth_persistence.dart';
export 'src/rest/secure_storage_auth_persistence.dart';
export 'src/web/web_flow.dart'
    show WebFlowPresenter, WebFlowResult, isFirebaseCallbackUrl, parseFirebaseCallback;

part 'src/confirmation_result.dart';
part 'src/firebase_auth.dart';
part 'src/multi_factor.dart';
part 'src/recaptcha_verifier.dart';
part 'src/user.dart';
part 'src/user_credential.dart';

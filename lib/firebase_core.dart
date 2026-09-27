/// The `firebase_core` API surface used by `firebase_auth_kit`:
/// [Firebase], [FirebaseApp], [FirebaseOptions] and [FirebaseException].
///
/// Kept in its own library so that apps which also depend on
/// `dartnative_firebase` (whose `Firebase.initializeApp()` boots the native
/// Crashlytics / Messaging SDKs) can import both without a name clash:
///
/// ```dart
/// import 'package:dartnative_firebase/dartnative_firebase.dart';
/// import 'package:firebase_auth_kit/firebase_auth_kit.dart';
/// // Only when you need FirebaseApp / FirebaseOptions from this package:
/// import 'package:firebase_auth_kit/firebase_core.dart' as auth_core;
/// ```
library;

export 'src/core/firebase_core.dart';

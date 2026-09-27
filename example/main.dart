// ignore_for_file: avoid_print
// A tour of firebase_auth_kit against the Firebase Auth emulator.
//
//   firebase emulators:start --only auth --project demo-firebase-auth-kit
//   FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 dart run example/main.dart
//
// In a DartNative app the same calls work unchanged; `FirebaseAuth.instance`
// reads GoogleService-Info.plist / your --dart-defines instead of the options
// passed below.
import 'dart:io';

import 'package:firebase_auth_kit/firebase_auth_kit.dart';
import 'package:firebase_auth_kit/firebase_core.dart' show Firebase;

Future<void> main() async {
  final emulatorHost = Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'];
  if (emulatorHost == null) {
    stderr.writeln('Set FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 first.');
    exit(1);
  }

  FirebaseAuthKit.logger = print;
  final app = await Firebase.initializeApp(
    name: 'example',
    options: const FirebaseOptions(
      apiKey: 'fake-api-key',
      appId: '1:1:dart:1',
      messagingSenderId: '1',
      projectId: 'demo-firebase-auth-kit',
    ),
  );
  final auth = FirebaseAuth.instanceFor(app: app);
  // With an asynchronous session store (installSecureAuthPersistence)
  // this is the point where the previous session is guaranteed to be back.
  await auth.authStateReady();
  print('restored session: ${auth.currentUser?.uid ?? 'none'}');

  final subscription = auth.authStateChanges().listen((user) {
    print('authStateChanges → ${user?.uid ?? 'signed out'}');
  });

  final email = 'demo-${DateTime.now().millisecondsSinceEpoch}@example.com';
  final credential = await auth.createUserWithEmailAndPassword(
    email: email,
    password: 'secret123',
  );
  print('created ${credential.user!.uid} (new user: '
      '${credential.additionalUserInfo!.isNewUser})');

  await auth.currentUser!.updateProfile(displayName: 'Demo User');
  print('display name: ${auth.currentUser!.displayName}');

  final token = await auth.currentUser!.getIdTokenResult();
  print('signed in with ${token.signInProvider}, '
      'token expires ${token.expirationTime}');

  await auth.signOut();

  try {
    await auth.signInWithEmailAndPassword(email: email, password: 'wrong');
  } on FirebaseAuthException catch (e) {
    print('expected failure: [${e.code}] ${e.message}');
  }

  await auth.signInWithEmailAndPassword(email: email, password: 'secret123');
  print('back in as ${auth.currentUser!.email}');

  // Phone sign-in: the emulator prints codes at
  // GET /emulator/v1/projects/<project>/verificationCodes.
  await auth.verifyPhoneNumber(
    phoneNumber: '+15555550123',
    verificationCompleted: (_) {},
    verificationFailed: (e) => print('phone failed: ${e.code}'),
    codeSent: (verificationId, _) =>
        print('SMS sent, verificationId=$verificationId'),
    codeAutoRetrievalTimeout: (_) {},
  );

  await auth.currentUser!.delete();
  await subscription.cancel();
  await app.delete();
}

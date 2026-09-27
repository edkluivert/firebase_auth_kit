@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth_kit/firebase_auth_kit.dart';
import 'package:firebase_auth_kit/firebase_core.dart' show Firebase;
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

/// Runs against a real Firebase Auth emulator:
///
/// ```sh
/// firebase emulators:start --only auth --project demo-firebase-auth-kit
/// FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 dart test test/live_emulator_test.dart
/// ```
void main() {
  final host = Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'];
  const projectId = 'demo-firebase-auth-kit';
  final runId = DateTime.now().microsecondsSinceEpoch;

  if (host == null || host.isEmpty) {
    test('live emulator tests are skipped without FIREBASE_AUTH_EMULATOR_HOST',
        () {}, skip: 'set FIREBASE_AUTH_EMULATOR_HOST to run');
    return;
  }

  late FirebaseAuth auth;
  final emulator = Uri.parse('http://$host');
  final logLines = <String>[];

  Future<Map<String, Object?>> emulatorGet(String path) async {
    final response = await http.get(emulator.replace(path: path));
    return Map<String, Object?>.from(jsonDecode(response.body) as Map);
  }

  setUpAll(() async {
    FirebaseAuthKit.reset();
    FirebaseAuthKit.persistence = InMemoryAuthPersistence();
    FirebaseAuthKit.logger = logLines.add;
    final app = await Firebase.initializeApp(
      name: 'live',
      options: const FirebaseOptions(
        apiKey: 'fake-api-key',
        appId: '1:1:dart:1',
        messagingSenderId: '1',
        projectId: projectId,
      ),
    );
    auth = FirebaseAuth.instanceFor(app: app);
    // Turn on SMS multi-factor for the emulated project.
    await http.patch(
      emulator.replace(path: '/emulator/v1/projects/$projectId/config'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'mfa': {'state': 'ENABLED', 'enabledProviders': ['PHONE_SMS']},
      }),
    );
  });

  tearDown(() async {
    if (auth.currentUser != null) await auth.signOut();
  });

  test('email/password sign-up, sign-in, refresh, profile, delete', () async {
    final email = 'live-$runId@example.com';
    final created = await auth.createUserWithEmailAndPassword(
        email: email, password: 'secret123');
    expect(created.user!.email, email);
    expect(created.additionalUserInfo!.isNewUser, isTrue);
    final uid = created.user!.uid;

    final token1 = await auth.currentUser!.getIdToken();
    logLines.clear();
    final token2 = await auth.currentUser!.getIdToken(true);
    expect(token2, isNotEmpty);
    expect(logLines.join('\n'), contains('/securetoken.googleapis.com/v1/token 200'));
    expect(token1, isNotEmpty);
    final result = await auth.currentUser!.getIdTokenResult();
    expect(result.signInProvider, 'password');
    expect(result.claims!['email'], email);

    await auth.currentUser!.updateProfile(displayName: 'Live User');
    expect(auth.currentUser!.displayName, 'Live User');
    await auth.currentUser!.reload();
    expect(auth.currentUser!.displayName, 'Live User');

    await auth.signOut();
    expect(auth.currentUser, isNull);

    await expectLater(
      auth.signInWithEmailAndPassword(email: email, password: 'wrong'),
      throwsA(isA<FirebaseAuthException>()
          .having((e) => e.code, 'code', anyOf('invalid-credential', 'wrong-password'))),
    );
    final signedIn =
        await auth.signInWithEmailAndPassword(email: email, password: 'secret123');
    expect(signedIn.user!.uid, uid);
    expect(signedIn.additionalUserInfo!.isNewUser, isFalse);

    await expectLater(
      auth.createUserWithEmailAndPassword(email: email, password: 'secret123'),
      throwsA(isA<FirebaseAuthException>()
          .having((e) => e.code, 'code', 'email-already-in-use')),
    );

    await auth.currentUser!.delete();
    expect(auth.currentUser, isNull);
  });

  test('anonymous sign-in then link email/password', () async {
    final anon = await auth.signInAnonymously();
    expect(anon.user!.isAnonymous, isTrue);
    final linked = await auth.currentUser!.linkWithCredential(
      EmailAuthProvider.credential(
          email: 'linked-$runId@example.com', password: 'secret123'),
    );
    expect(linked.user!.uid, anon.user!.uid);
    expect(auth.currentUser!.isAnonymous, isFalse);
    expect(auth.currentUser!.providerData.single.providerId, 'password');
  });

  test('password reset and email verification through emulator OOB codes',
      () async {
    final email = 'oob-$runId@example.com';
    await auth.createUserWithEmailAndPassword(email: email, password: 'secret123');
    await auth.currentUser!.sendEmailVerification();
    await auth.signOut();
    await auth.sendPasswordResetEmail(email: email);

    final codes = await emulatorGet('/emulator/v1/projects/$projectId/oobCodes');
    final list = (codes['oobCodes'] as List).cast<Map<dynamic, dynamic>>();
    final reset = list.lastWhere(
        (c) => c['email'] == email && c['requestType'] == 'PASSWORD_RESET');
    final verify = list.lastWhere(
        (c) => c['email'] == email && c['requestType'] == 'VERIFY_EMAIL');

    final info = await auth.checkActionCode(reset['oobCode'] as String);
    expect(info.operation, ActionCodeInfoOperation.passwordReset);
    expect(info.data['email'], email);
    expect(await auth.verifyPasswordResetCode(reset['oobCode'] as String), email);
    await auth.confirmPasswordReset(
        code: reset['oobCode'] as String, newPassword: 'newsecret123');

    await auth.applyActionCode(verify['oobCode'] as String);
    final signedIn = await auth.signInWithEmailAndPassword(
        email: email, password: 'newsecret123');
    expect(signedIn.user!.emailVerified, isTrue);
  });

  test('email link sign-in', () async {
    final email = 'link-$runId@example.com';
    await auth.sendSignInLinkToEmail(
      email: email,
      actionCodeSettings: ActionCodeSettings(
          url: 'https://example.com/finish', handleCodeInApp: true),
    );
    final codes = await emulatorGet('/emulator/v1/projects/$projectId/oobCodes');
    final entry = (codes['oobCodes'] as List)
        .cast<Map<dynamic, dynamic>>()
        .lastWhere((c) => c['email'] == email && c['requestType'] == 'EMAIL_SIGNIN');
    final link = entry['oobLink'] as String;
    expect(auth.isSignInWithEmailLink(link), isTrue);
    final credential =
        await auth.signInWithEmailLink(email: email, emailLink: link);
    expect(credential.user!.email, email);
    expect(credential.user!.emailVerified, isTrue);
  });

  test('phone sign-in with the emulator SMS code', () async {
    final phone = '+1555${(runId % 10000000).toString().padLeft(7, '0')}';
    String? verificationId;
    await auth.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (_) {},
      verificationFailed: (e) => fail('verificationFailed: $e'),
      codeSent: (id, _) => verificationId = id,
      codeAutoRetrievalTimeout: (_) {},
    );
    expect(verificationId, isNotNull);
    final codes =
        await emulatorGet('/emulator/v1/projects/$projectId/verificationCodes');
    final entry = (codes['verificationCodes'] as List)
        .cast<Map<dynamic, dynamic>>()
        .lastWhere((c) => c['phoneNumber'] == phone);
    final credential = await auth.signInWithCredential(
      PhoneAuthProvider.credential(
          verificationId: verificationId!, smsCode: entry['code'] as String),
    );
    expect(credential.user!.phoneNumber, phone);
    expect(credential.additionalUserInfo!.isNewUser, isTrue);
  });

  test('Google credential through signInWithIdp', () async {
    // The emulator accepts unsigned ID tokens whose payload is a JSON object.
    final payload = base64Url
        .encode(utf8.encode(jsonEncode({
          'sub': 'google-$runId',
          'email': 'google-$runId@example.com',
          'email_verified': true,
          'name': 'Google Person',
        })))
        .replaceAll('=', '');
    final idToken = 'eyJhbGciOiJub25lIn0.$payload.';
    final credential = await auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
    expect(credential.user!.providerData.single.providerId, 'google.com');
    expect(credential.user!.displayName, 'Google Person');
    expect(credential.additionalUserInfo!.providerId, 'google.com');
    expect(credential.additionalUserInfo!.isNewUser, isTrue);
    expect(credential.additionalUserInfo!.profile!['email'],
        'google-$runId@example.com');
  });

  test('signInWithProvider through the emulator handler (redirect flow)', () async {
    // Simulate what the emulator's handler page does after the user picks an
    // account: build the response URL exactly as its finishWithUser() does and
    // redirect to the iOS-style deep link.
    FirebaseAuthKit.webFlowPresenter = (url, {required isCallback}) async {
      expect(url.path, '/emulator/auth/handler');
      final claims = jsonEncode({
        'sub': 'redirect-$runId',
        'email': 'redirect-$runId@example.com',
        'email_verified': true,
        'name': 'Redirect Person',
      });
      final response = '${url.origin}${url.path}'
          '?providerId=${Uri.encodeComponent(url.queryParameters['providerId']!)}'
          '&id_token=${Uri.encodeComponent(claims)}';
      final callbackPage = '${url.origin}/__/auth/callback'
          '?authType=signInWithRedirect&link=${Uri.encodeComponent(response)}';
      return Uri.parse('app-1-1-dart-1://firebaseauth/link'
          '?deep_link_id=${Uri.encodeComponent(callbackPage)}');
    };
    addTearDown(() => FirebaseAuthKit.webFlowPresenter = null);
    final credential = await auth.signInWithProvider(GithubAuthProvider()..addScope('user:email'));
    expect(credential.user!.email, 'redirect-$runId@example.com');
    expect(credential.user!.displayName, 'Redirect Person');
    expect(credential.user!.providerData.single.providerId, 'github.com');
    expect(credential.additionalUserInfo!.isNewUser, isTrue);
  });

  test('custom token sign-in', () async {
    // Unsigned custom tokens are accepted by the emulator.
    String b64(Object o) =>
        base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final token = '${b64({'alg': 'none', 'typ': 'JWT'})}.${b64({
      'iss': 'firebase-auth-emulator@example.com',
      'sub': 'firebase-auth-emulator@example.com',
      'aud': 'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit',
      'iat': now,
      'exp': now + 3600,
      'uid': 'custom-$runId',
      'claims': {'role': 'tester'},
    })}.';
    final credential = await auth.signInWithCustomToken(token);
    expect(credential.user!.uid, 'custom-$runId');
    expect(credential.user!.isAnonymous, isFalse);
    final result = await auth.currentUser!.getIdTokenResult();
    expect(result.claims!['role'], 'tester');
  });

  test('phone second factor enrolment and sign-in', () async {
    final email = 'mfa-$runId@example.com';
    final phone = '+1666${(runId % 10000000).toString().padLeft(7, '0')}';
    await auth.createUserWithEmailAndPassword(email: email, password: 'secret123');
    // The emulator requires a verified email before enrolling a second factor.
    await auth.currentUser!.sendEmailVerification();
    final codes = await emulatorGet('/emulator/v1/projects/$projectId/oobCodes');
    final verify = (codes['oobCodes'] as List)
        .cast<Map<dynamic, dynamic>>()
        .lastWhere((c) => c['email'] == email && c['requestType'] == 'VERIFY_EMAIL');
    await auth.applyActionCode(verify['oobCode'] as String);
    await auth.currentUser!.reload();

    final session = await auth.currentUser!.multiFactor.getSession();
    String? enrolId;
    await auth.verifyPhoneNumber(
      phoneNumber: phone,
      multiFactorSession: session,
      verificationCompleted: (_) {},
      verificationFailed: (e) => fail('verificationFailed: $e'),
      codeSent: (id, _) => enrolId = id,
      codeAutoRetrievalTimeout: (_) {},
    );
    var sms = await emulatorGet('/emulator/v1/projects/$projectId/verificationCodes');
    var entry = (sms['verificationCodes'] as List)
        .cast<Map<dynamic, dynamic>>()
        .lastWhere((c) => c['phoneNumber'] == phone);
    await auth.currentUser!.multiFactor.enroll(
      PhoneMultiFactorGenerator.getAssertion(PhoneAuthProvider.credential(
          verificationId: enrolId!, smsCode: entry['code'] as String)),
      displayName: 'Live phone',
    );
    final factors = await auth.currentUser!.multiFactor.getEnrolledFactors();
    expect(factors.single, isA<PhoneMultiFactorInfo>());
    expect((factors.single as PhoneMultiFactorInfo).phoneNumber, phone);
    await auth.signOut();

    FirebaseAuthMultiFactorException error;
    try {
      await auth.signInWithEmailAndPassword(email: email, password: 'secret123');
      fail('expected second-factor-required');
    } on FirebaseAuthMultiFactorException catch (e) {
      error = e;
    }
    final hint = error.resolver.hints.single as PhoneMultiFactorInfo;
    String? signInId;
    await auth.verifyPhoneNumber(
      multiFactorInfo: hint,
      multiFactorSession: error.resolver.session,
      verificationCompleted: (_) {},
      verificationFailed: (e) => fail('verificationFailed: $e'),
      codeSent: (id, _) => signInId = id,
      codeAutoRetrievalTimeout: (_) {},
    );
    sms = await emulatorGet('/emulator/v1/projects/$projectId/verificationCodes');
    entry = (sms['verificationCodes'] as List)
        .cast<Map<dynamic, dynamic>>()
        .lastWhere((c) => c['phoneNumber'] == phone);
    final credential = await error.resolver.resolveSignIn(
      PhoneMultiFactorGenerator.getAssertion(PhoneAuthProvider.credential(
          verificationId: signInId!, smsCode: entry['code'] as String)),
    );
    expect(credential.user!.email, email);
    final result = await auth.currentUser!.getIdTokenResult();
    expect(result.signInSecondFactor, 'phone');
    await auth.currentUser!.multiFactor.unenroll(factorUid: factors.single.uid);
    expect(await auth.currentUser!.multiFactor.getEnrolledFactors(), isEmpty);
  });

  test('TOTP enrolment on the emulator', () async {
    final email = 'totp-$runId@example.com';
    await auth.createUserWithEmailAndPassword(email: email, password: 'secret123');
    await auth.currentUser!.sendEmailVerification();
    final codes = await emulatorGet('/emulator/v1/projects/$projectId/oobCodes');
    final verify = (codes['oobCodes'] as List)
        .cast<Map<dynamic, dynamic>>()
        .lastWhere((c) => c['email'] == email && c['requestType'] == 'VERIFY_EMAIL');
    await auth.applyActionCode(verify['oobCode'] as String);
    await auth.currentUser!.reload();
    final session = await auth.currentUser!.multiFactor.getSession();
    try {
      final secret = await TotpMultiFactorGenerator.generateSecret(session);
      expect(secret.secretKey, isNotEmpty);
      stderr.writeln('TOTP secret issued by the emulator: '
          '${secret.codeLength} digits / ${secret.codeIntervalSeconds}s');
    } on FirebaseAuthException catch (e) {
      stderr.writeln('TOTP not available on this emulator: ${e.code} ${e.message}');
      markTestSkipped('emulator rejected TOTP enrolment: ${e.code}');
    }
  });
}

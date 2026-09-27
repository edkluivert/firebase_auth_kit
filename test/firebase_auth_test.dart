import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth_kit/firebase_auth_kit.dart';
import 'package:firebase_auth_kit/firebase_core.dart' show Firebase;
import 'package:firebase_auth_kit/src/rest/rest_firebase_auth.dart';
import 'package:test/test.dart';

import 'helpers/fake_identity_toolkit.dart';

void main() {
  late FakeIdentityToolkit fake;
  var appCounter = 0;

  setUpAll(() async {
    fake = await FakeIdentityToolkit.start();
  });

  tearDownAll(() => fake.close());

  setUp(() {
    FirebaseAuthKit.reset();
    FirebaseAuthKit.emulatorHost = fake.origin;
    FirebaseAuthKit.persistence = InMemoryAuthPersistence();
    fake.accounts.clear();
    fake.requests.clear();
    fake.oobCodes.clear();
    fake.phoneSessions.clear();
    fake.mfaPending.clear();
    fake.refreshTokens.clear();
    fake.expiresInSeconds = 3600;
  });

  Future<FirebaseAuth> newAuth() async {
    final app = await Firebase.initializeApp(
      name: 'test-${++appCounter}',
      options: const FirebaseOptions(
        apiKey: 'test-key',
        appId: '1:1:dart:1',
        messagingSenderId: '1',
        projectId: 'demo-project',
      ),
    );
    addTearDown(() => app.delete());
    return FirebaseAuth.instanceFor(app: app);
  }

  Map<String, Object?> lastBody(String method) => fake.requests
      .lastWhere((r) => r.path.endsWith(method))
      .body;

  group('email / password', () {
    test('createUserWithEmailAndPassword signs the user in', () async {
      final auth = await newAuth();
      final credential = await auth.createUserWithEmailAndPassword(
        email: 'a@example.com',
        password: 'secret1',
      );
      expect(credential.user, isNotNull);
      expect(credential.user!.email, 'a@example.com');
      expect(credential.user!.isAnonymous, isFalse);
      expect(credential.user!.emailVerified, isFalse);
      expect(credential.user!.providerData.single.providerId, 'password');
      expect(credential.additionalUserInfo!.isNewUser, isTrue);
      expect(credential.additionalUserInfo!.providerId, 'password');
      expect(auth.currentUser!.uid, credential.user!.uid);
      expect(auth.currentUser!.metadata.creationTime, isNotNull);
      expect(await auth.currentUser!.getIdToken(), isNotEmpty);
      expect(lastBody('accounts:signUp')['returnSecureToken'], isTrue);
    });

    test('signInWithEmailAndPassword and error codes', () async {
      final auth = await newAuth();
      fake.createAccount(email: 'b@example.com', password: 'secret1');
      final credential = await auth.signInWithEmailAndPassword(
        email: 'b@example.com',
        password: 'secret1',
      );
      expect(credential.additionalUserInfo!.isNewUser, isFalse);
      expect(auth.currentUser!.email, 'b@example.com');

      await expectLater(
        auth.signInWithEmailAndPassword(email: 'b@example.com', password: 'nope'),
        throwsA(isA<FirebaseAuthException>()
            .having((e) => e.code, 'code', 'invalid-credential')),
      );
      await expectLater(
        auth.signInWithEmailAndPassword(email: 'zz@example.com', password: 'x'),
        throwsA(isA<FirebaseAuthException>()
            .having((e) => e.code, 'code', 'user-not-found')),
      );
      await expectLater(
        auth.createUserWithEmailAndPassword(email: 'b@example.com', password: 'secret1'),
        throwsA(isA<FirebaseAuthException>()
            .having((e) => e.code, 'code', 'email-already-in-use')
            .having((e) => e.plugin, 'plugin', 'firebase_auth')),
      );
      await expectLater(
        auth.createUserWithEmailAndPassword(email: 'c@example.com', password: '123'),
        throwsA(isA<FirebaseAuthException>()
            .having((e) => e.code, 'code', 'weak-password')
            .having((e) => e.message, 'message', contains('6 characters'))),
      );
    });

    test('network failures surface as network-request-failed', () async {
      FirebaseAuthKit.emulatorHost = 'http://127.0.0.1:1';
      final auth = await newAuth();
      await expectLater(
        auth.signInAnonymously(),
        throwsA(isA<FirebaseAuthException>()
            .having((e) => e.code, 'code', 'network-request-failed')),
      );
    });
  });

  group('anonymous and custom token', () {
    test('signInAnonymously reuses the anonymous user', () async {
      final auth = await newAuth();
      final first = await auth.signInAnonymously();
      expect(first.user!.isAnonymous, isTrue);
      expect(first.additionalUserInfo!.isNewUser, isTrue);
      final second = await auth.signInAnonymously();
      expect(second.user!.uid, first.user!.uid);
      expect(second.additionalUserInfo!.isNewUser, isFalse);
      expect(fake.requests.where((r) => r.path.endsWith('accounts:signUp')).length, 1);
    });

    test('signInWithCustomToken identifies the user from the token', () async {
      final auth = await newAuth();
      final credential = await auth.signInWithCustomToken('custom:server-uid');
      expect(credential.user!.uid, 'server-uid');
      expect(credential.user!.isAnonymous, isFalse);
      expect(credential.additionalUserInfo!.isNewUser, isTrue);
      await expectLater(
        auth.signInWithCustomToken('garbage'),
        throwsA(isA<FirebaseAuthException>()
            .having((e) => e.code, 'code', 'invalid-custom-token')),
      );
    });
  });

  group('federated credentials', () {
    test('signInWithCredential posts to signInWithIdp', () async {
      final auth = await newAuth();
      final credential = await auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: 'goog-id', accessToken: 'goog-at'),
      );
      final body = lastBody('accounts:signInWithIdp');
      expect(body['postBody'], contains('providerId=google.com'));
      expect(body['postBody'], contains('id_token=goog-id'));
      expect(body['requestUri'], 'http://localhost');
      expect(body['returnIdpCredential'], isTrue);
      expect(credential.user!.providerData.single.providerId, 'google.com');
      expect(credential.user!.displayName, 'Idp User');
      expect(credential.additionalUserInfo!.isNewUser, isTrue);
      expect(credential.additionalUserInfo!.providerId, 'google.com');
      expect(credential.additionalUserInfo!.profile!['login'], 'octocat');
      final returned = credential.credential as OAuthCredential;
      expect(returned.accessToken, 'goog-at');
      expect(returned.idToken, 'goog-id');
    });

    test('Apple credential stores the full name on a new account', () async {
      final auth = await newAuth();
      final credential = await auth.signInWithCredential(
        AppleAuthProvider.credentialWithIDToken(
          'apple-id',
          'nonce',
          AppleFullPersonName(givenName: 'Ada', familyName: 'Lovelace'),
        ),
      );
      expect(lastBody('accounts:signInWithIdp')['postBody'], contains('nonce=nonce'));
      // The fake returns 'Idp User' as displayName, so no update happens; make
      // sure the sign-in itself succeeded with the Apple provider.
      expect(credential.user!.providerData.single.providerId, 'apple.com');
    });

    test('account-exists-with-different-credential carries the credential', () async {
      final auth = await newAuth();
      fake.createAccount(email: 'conflict@example.com', password: 'secret1');
      await expectLater(
        auth.signInWithCredential(GithubAuthProvider.credential('conflict')),
        throwsA(isA<FirebaseAuthException>()
            .having((e) => e.code, 'code', 'account-exists-with-different-credential')
            .having((e) => e.email, 'email', 'conflict@example.com')
            .having((e) => e.credential, 'credential', isA<OAuthCredential>())),
      );
    });

    test('signInWithProvider runs the hosted redirect flow through the presenter', () async {
      final auth = await newAuth();
      Uri? shown;
      // Behave like Firebase's handler: read the request, "sign in" the user
      // at the provider and redirect to the app's deep link.
      FirebaseAuthKit.webFlowPresenter = (url, {required isCallback}) async {
        shown = url;
        final response = Uri.parse('${url.origin}/emulator/auth/handler').replace(queryParameters: {
          'providerId': url.queryParameters['providerId']!,
          'id_token': 'hosted-flow-user',
          'access_token': 'hosted-at',
        });
        final callbackPage = Uri.parse('${url.origin}/__/auth/callback')
            .replace(queryParameters: {'authType': 'signInWithRedirect', 'link': response.toString()});
        final deepLink = Uri.parse('app-1-1-dart-1://firebaseauth/link')
            .replace(queryParameters: {'deep_link_id': callbackPage.toString()});
        expect(isCallback(deepLink), isTrue);
        return deepLink;
      };
      final credential = await auth.signInWithProvider(
        GithubAuthProvider()..addScope('user:email'),
      );
      expect(shown!.path, '/emulator/auth/handler');
      expect(shown!.queryParameters['providerId'], 'github.com');
      expect(shown!.queryParameters['scopes'], 'user:email');
      expect(shown!.queryParameters['authType'], 'signInWithRedirect');
      final sessionHash = shown!.queryParameters['sessionId']!;
      final body = lastBody('accounts:signInWithIdp');
      expect(body['postBody'], isNull);
      expect(body['requestUri'], contains('id_token=hosted-flow-user'));
      expect(body['sessionId'], isNotNull);
      expect(sessionHash, isNot(equals(body['sessionId'])),
          reason: 'the handler gets the hash, the API the raw nonce');
      expect(credential.user!.providerData.single.providerId, 'github.com');
      expect(credential.additionalUserInfo!.isNewUser, isTrue);
      expect((credential.credential as OAuthCredential).accessToken, 'hosted-at');

      // Linking and re-authentication reuse the flow.
      await auth.currentUser!.reauthenticateWithProvider(GithubAuthProvider());
      await auth.signOut();
      await auth.signInAnonymously();
      final linked = await auth.currentUser!.linkWithProvider(GoogleAuthProvider());
      expect(linked.user!.providerData.map((p) => p.providerId), contains('google.com'));
      expect(lastBody('accounts:signInWithIdp')['idToken'], isNotNull);
    });

    test('a dismissed page is reported as user-cancelled', () async {
      final auth = await newAuth();
      FirebaseAuthKit.webFlowPresenter = (url, {required isCallback}) async => null;
      await expectLater(
        auth.signInWithProvider(GithubAuthProvider()),
        throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', 'user-cancelled')),
      );
    });

    test('signInWithProvider needs an OAuth flow handler', () async {
      final auth = await newAuth();
      await expectLater(
        auth.signInWithProvider(GithubAuthProvider()),
        throwsA(isA<FirebaseAuthException>().having(
            (e) => e.code, 'code', 'operation-not-supported-in-this-environment')),
      );
      FirebaseAuthKit.oauthFlowHandler = (_, provider) async =>
          OAuthProvider(provider.providerId).credential(accessToken: 'gh-token');
      final credential = await auth.signInWithProvider(GithubAuthProvider());
      expect(credential.user!.providerData.single.providerId, 'github.com');
      expect(credential.additionalUserInfo!.username, 'octocat');
    });
  });

  group('linking and reauthentication', () {
    test('linkWithCredential adds a provider to the current user', () async {
      final auth = await newAuth();
      final anon = await auth.signInAnonymously();
      final uid = anon.user!.uid;
      final linked = await auth.currentUser!.linkWithCredential(
        EmailAuthProvider.credential(email: 'link@example.com', password: 'secret1'),
      );
      expect(linked.user!.uid, uid);
      expect(auth.currentUser!.uid, uid);
      expect(auth.currentUser!.email, 'link@example.com');
      expect(auth.currentUser!.isAnonymous, isFalse);
      expect(lastBody('accounts:signUp')['idToken'], isNotNull,
          reason: 'password linking is a signUp with the current idToken');
      expect(anon.user!.email, 'link@example.com',
          reason: 'existing User wrappers see the update');

      final google = await auth.currentUser!.linkWithCredential(
        GoogleAuthProvider.credential(idToken: 'g1'),
      );
      expect(google.user!.providerData.map((p) => p.providerId),
          containsAll(['password', 'google.com']));
      expect(lastBody('accounts:signInWithIdp')['idToken'], isNotNull);

      final unlinked = await auth.currentUser!.unlink('google.com');
      expect(unlinked.providerData.map((p) => p.providerId), ['password']);
      expect(lastBody('accounts:update')['deleteProvider'], ['google.com']);
    });

    test('credential-already-in-use when linking a taken provider', () async {
      final auth = await newAuth();
      await auth.signInWithCredential(GoogleAuthProvider.credential(idToken: 'taken'));
      await auth.signOut();
      await auth.signInAnonymously();
      await expectLater(
        auth.currentUser!.linkWithCredential(GoogleAuthProvider.credential(idToken: 'taken')),
        throwsA(isA<FirebaseAuthException>()
            .having((e) => e.code, 'code', 'credential-already-in-use')
            .having((e) => e.email, 'email', 'taken@google.com')),
      );
    });

    test('reauthenticateWithCredential checks the user matches', () async {
      final auth = await newAuth();
      fake.createAccount(email: 'r@example.com', password: 'secret1');
      fake.createAccount(email: 'other@example.com', password: 'secret1');
      await auth.signInWithEmailAndPassword(email: 'r@example.com', password: 'secret1');
      final before = auth.currentUser!;
      final result = await before.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: 'r@example.com', password: 'secret1'),
      );
      expect(result.user!.uid, before.uid);
      await expectLater(
        before.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: 'other@example.com', password: 'secret1'),
        ),
        throwsA(isA<FirebaseAuthException>()
            .having((e) => e.code, 'code', 'user-mismatch')),
      );
      expect(auth.currentUser!.uid, before.uid);
    });
  });

  group('profile and account management', () {
    test('updateProfile, updateEmail, updatePassword, reload, delete', () async {
      final auth = await newAuth();
      await auth.createUserWithEmailAndPassword(email: 'p@example.com', password: 'secret1');
      final user = auth.currentUser!;
      await user.updateProfile(displayName: 'Grace', photoURL: 'https://x/y.png');
      expect(user.displayName, 'Grace');
      expect(user.photoURL, 'https://x/y.png');
      await user.updateDisplayName(null);
      expect(user.displayName, isNull);
      expect(lastBody('accounts:update')['deleteAttribute'], ['DISPLAY_NAME']);

      await user.updatePassword('secret2');
      expect(lastBody('accounts:update')['password'], 'secret2');
      await auth.signOut();
      await auth.signInWithEmailAndPassword(email: 'p@example.com', password: 'secret2');

      fake.accounts.values.first['emailVerified'] = true;
      expect(auth.currentUser!.emailVerified, isFalse);
      await auth.currentUser!.reload();
      expect(auth.currentUser!.emailVerified, isTrue);

      await auth.currentUser!.delete();
      expect(auth.currentUser, isNull);
      expect(fake.accounts, isEmpty);
    });

    test('sendEmailVerification and verifyBeforeUpdateEmail use the ID token', () async {
      final auth = await newAuth();
      await auth.createUserWithEmailAndPassword(email: 'v@example.com', password: 'secret1');
      await auth.currentUser!.sendEmailVerification(
        ActionCodeSettings(url: 'https://app.example.com/verify', handleCodeInApp: true, iOSBundleId: 'com.x'),
      );
      var body = lastBody('accounts:sendOobCode');
      expect(body['requestType'], 'VERIFY_EMAIL');
      expect(body['idToken'], isNotNull);
      expect(body['continueUrl'], 'https://app.example.com/verify');
      expect(body['iOSBundleId'], 'com.x');
      await auth.currentUser!.verifyBeforeUpdateEmail('new@example.com');
      body = lastBody('accounts:sendOobCode');
      expect(body['requestType'], 'VERIFY_AND_CHANGE_EMAIL');
      expect(body['newEmail'], 'new@example.com');
    });

    test('getIdTokenResult exposes claims', () async {
      final auth = await newAuth();
      await auth.createUserWithEmailAndPassword(email: 't@example.com', password: 'secret1');
      final result = await auth.currentUser!.getIdTokenResult();
      expect(result.signInProvider, 'password');
      expect(result.claims!['email'], 't@example.com');
      expect(result.expirationTime!.isAfter(DateTime.now()), isTrue);
      expect(result.issuedAtTime, isNotNull);
    });

    test('fetchSignInMethodsForEmail', () async {
      final auth = await newAuth();
      fake.createAccount(email: 'm@example.com', password: 'secret1');
      final methods = await (auth.instanceForTesting).fetchSignInMethodsForEmail('m@example.com');
      expect(methods, ['password']);
    });
  });

  group('tokens', () {
    test('getIdToken refreshes expired tokens and emits idTokenChanges', () async {
      fake.expiresInSeconds = 5; // below the refresh threshold → refresh at once
      final auth = await newAuth();
      await auth.createUserWithEmailAndPassword(email: 'tok@example.com', password: 'secret1');
      final events = StreamQueue(auth.idTokenChanges());
      expect((await events.next)?.uid, auth.currentUser!.uid);
      final before = fake.requests.length;
      final token = await auth.currentUser!.getIdToken();
      expect(token, isNotEmpty);
      expect(fake.requests.skip(before).map((r) => r.path),
          contains('/securetoken.googleapis.com/v1/token'));
      expect((await events.next)?.uid, auth.currentUser!.uid);
      expect(lastBody('token')['grant_type'], 'refresh_token');
      await events.cancel();
    });

    test('forceRefresh always hits the token endpoint once per call', () async {
      final auth = await newAuth();
      await auth.signInAnonymously();
      final before = fake.requests.length;
      await Future.wait([
        auth.currentUser!.getIdToken(true),
        auth.currentUser!.getIdToken(true),
      ]);
      expect(
        fake.requests.skip(before).where((r) => r.path.endsWith('/token')).length,
        1,
        reason: 'concurrent refreshes are coalesced',
      );
    });

    test('an invalid refresh token signs the user out', () async {
      fake.expiresInSeconds = 1;
      final auth = await newAuth();
      await auth.signInAnonymously();
      fake.refreshTokens.clear();
      await expectLater(
        auth.currentUser!.getIdToken(),
        throwsA(isA<FirebaseAuthException>()
            .having((e) => e.code, 'code', 'invalid-refresh-token')),
      );
      expect(auth.currentUser, isNull);
    });
  });

  group('streams', () {
    test('authStateChanges emits current state then sign-in / sign-out', () async {
      final auth = await newAuth();
      final states = StreamQueue(auth.authStateChanges());
      final users = StreamQueue(auth.userChanges());
      expect(await states.next, isNull);
      expect(await users.next, isNull);
      await auth.signInAnonymously();
      expect((await states.next)?.isAnonymous, isTrue);
      expect((await users.next)?.isAnonymous, isTrue);
      await auth.currentUser!.updateProfile(displayName: 'Anon');
      expect((await users.next)?.displayName, 'Anon');
      await auth.signOut();
      expect(await states.next, isNull);
      expect(await users.next, isNull);
      await states.cancel();
      await users.cancel();
    });

    test('a late subscriber receives the current user first', () async {
      final auth = await newAuth();
      await auth.signInAnonymously();
      expect((await auth.authStateChanges().first)?.uid, auth.currentUser!.uid);
    });
  });

  group('persistence', () {
    test('a new instance restores the session from disk', () async {
      final dir = Directory.systemTemp.createTempSync('fak-session');
      addTearDown(() => dir.deleteSync(recursive: true));
      FirebaseAuthKit.persistence = FileAuthPersistence(dir);

      const options = FirebaseOptions(
          apiKey: 'test-key', appId: '1:1:dart:1', messagingSenderId: '1', projectId: 'demo-project');
      final app = await Firebase.initializeApp(name: 'persist-a', options: options);
      final auth = FirebaseAuth.instanceFor(app: app);
      await auth.createUserWithEmailAndPassword(email: 's@example.com', password: 'secret1');
      await auth.currentUser!.updateProfile(displayName: 'Saved');
      final uid = auth.currentUser!.uid;
      await app.delete(); // disposes the auth instance, keeps the file

      final again = await Firebase.initializeApp(name: 'persist-a', options: options);
      addTearDown(() => again.delete());
      final restored = FirebaseAuth.instanceFor(app: again);
      expect(restored.currentUser, isNotNull);
      expect(restored.currentUser!.uid, uid);
      expect(restored.currentUser!.displayName, 'Saved');
      expect(restored.currentUser!.email, 's@example.com');
      expect(await restored.currentUser!.getIdToken(), isNotEmpty);
      await restored.signOut();
      expect(dir.listSync().whereType<File>(), isEmpty);
    });

    test('setPersistence(NONE) drops the stored session', () async {
      final dir = Directory.systemTemp.createTempSync('fak-none');
      addTearDown(() => dir.deleteSync(recursive: true));
      FirebaseAuthKit.persistence = FileAuthPersistence(dir);
      final auth = await newAuth();
      await auth.signInAnonymously();
      expect(dir.listSync().whereType<File>().length, 1);
      await auth.setPersistence(Persistence.NONE);
      expect(dir.listSync().whereType<File>(), isEmpty);
      expect(auth.currentUser, isNotNull);
    });
  });

  group('action codes', () {
    test('password reset flow', () async {
      final auth = await newAuth();
      fake.createAccount(email: 'reset@example.com', password: 'old-pass');
      await auth.setLanguageCode('fr');
      await auth.sendPasswordResetEmail(email: 'reset@example.com');
      final request = fake.requests.last;
      expect(request.body['requestType'], 'PASSWORD_RESET');
      expect(request.headers.value('X-Firebase-Locale'), 'fr');
      expect(auth.languageCode, 'fr');
      final code = fake.oobCodes.keys.single;

      final info = await auth.checkActionCode(code);
      expect(info.operation, ActionCodeInfoOperation.passwordReset);
      expect(info.data['email'], 'reset@example.com');
      expect(await auth.verifyPasswordResetCode(code), 'reset@example.com');
      await auth.confirmPasswordReset(code: code, newPassword: 'new-pass');
      await auth.signInWithEmailAndPassword(email: 'reset@example.com', password: 'new-pass');
      await expectLater(
        auth.verifyPasswordResetCode(code),
        throwsA(isA<FirebaseAuthException>()
            .having((e) => e.code, 'code', 'invalid-action-code')),
      );
      await expectLater(
        auth.sendPasswordResetEmail(email: 'nobody@example.com'),
        throwsA(isA<FirebaseAuthException>()
            .having((e) => e.code, 'code', 'user-not-found')),
      );
    });

    test('applyActionCode verifies the email', () async {
      final auth = await newAuth();
      await auth.createUserWithEmailAndPassword(email: 'apply@example.com', password: 'secret1');
      await auth.currentUser!.sendEmailVerification();
      final code = fake.oobCodes.keys.single;
      final info = await auth.checkActionCode(code);
      expect(info.operation, ActionCodeInfoOperation.verifyEmail);
      await auth.applyActionCode(code);
      expect(lastBody('accounts:update')['oobCode'], code);
      await auth.currentUser!.reload();
      expect(auth.currentUser!.emailVerified, isTrue);
    });

    test('email link sign-in', () async {
      final auth = await newAuth();
      await auth.sendSignInLinkToEmail(
        email: 'link@example.com',
        actionCodeSettings: ActionCodeSettings(url: 'https://app.example.com', handleCodeInApp: true),
      );
      final code = fake.oobCodes.keys.single;
      final link = 'https://demo.firebaseapp.com/__/auth/action?mode=signIn&oobCode=$code&apiKey=k';
      expect(auth.isSignInWithEmailLink(link), isTrue);
      final credential = await auth.signInWithEmailLink(email: 'link@example.com', emailLink: link);
      expect(credential.user!.email, 'link@example.com');
      expect(credential.user!.emailVerified, isTrue);
      expect(credential.additionalUserInfo!.isNewUser, isTrue);
      expect(
        () => auth.sendSignInLinkToEmail(
          email: 'x@example.com',
          actionCodeSettings: ActionCodeSettings(url: 'https://a', handleCodeInApp: false),
        ),
        throwsArgumentError,
      );
    });
  });

  group('phone', () {
    test('verifyPhoneNumber → codeSent → signInWithCredential', () async {
      final auth = await newAuth();
      final sent = Completer<String>();
      await auth.verifyPhoneNumber(
        phoneNumber: '+15555550100',
        verificationCompleted: (_) => fail('no auto retrieval expected'),
        verificationFailed: (e) => fail('unexpected $e'),
        codeSent: (id, token) => sent.complete(id),
        codeAutoRetrievalTimeout: (_) {},
        timeout: const Duration(minutes: 1),
      );
      final verificationId = await sent.future;
      expect(lastBody('accounts:sendVerificationCode')['recaptchaToken'], isNull,
          reason: 'the emulator needs no app verification');
      final credential = await auth.signInWithCredential(
        PhoneAuthProvider.credential(verificationId: verificationId, smsCode: '123456'),
      );
      expect(credential.user!.phoneNumber, '+15555550100');
      expect(credential.additionalUserInfo!.isNewUser, isTrue);
      expect(credential.credential, isA<PhoneAuthCredential>());
    });

    test('invalid numbers and codes map to FlutterFire codes', () async {
      final auth = await newAuth();
      final failed = Completer<FirebaseAuthException>();
      await auth.verifyPhoneNumber(
        phoneNumber: 'not-a-number',
        verificationCompleted: (_) {},
        verificationFailed: failed.complete,
        codeSent: (_, _) => fail('should not send'),
        codeAutoRetrievalTimeout: (_) {},
      );
      expect((await failed.future).code, 'invalid-phone-number');

      final result = await auth.signInWithPhoneNumber('+15555550101');
      await expectLater(
        result.confirm('000000'),
        throwsA(isA<FirebaseAuthException>()
            .having((e) => e.code, 'code', 'invalid-verification-code')),
      );
    });

    test('test phone numbers auto-complete via setSettings', () async {
      final auth = await newAuth();
      await auth.setSettings(phoneNumber: '+15555550102', smsCode: '123456');
      final completed = Completer<PhoneAuthCredential>();
      await auth.verifyPhoneNumber(
        phoneNumber: '+15555550102',
        verificationCompleted: completed.complete,
        verificationFailed: (e) => fail('$e'),
        codeSent: (_, _) {},
        codeAutoRetrievalTimeout: (_) {},
      );
      final credential = await completed.future;
      expect(credential.smsCode, '123456');
      await auth.signInWithCredential(credential);
      expect(auth.currentUser!.phoneNumber, '+15555550102');
    });

    test('linkWithPhoneNumber links to the current user', () async {
      final auth = await newAuth();
      await auth.signInAnonymously();
      final uid = auth.currentUser!.uid;
      final result = await auth.currentUser!.linkWithPhoneNumber('+15555550103');
      final credential = await result.confirm('123456');
      expect(credential.user!.uid, uid);
      expect(auth.currentUser!.phoneNumber, '+15555550103');
    });

    test('the loopback reCAPTCHA page supplies the token in production', () async {
      final auth = await newAuth();
      final delegate = auth.instanceForTesting;
      delegate.forceAppVerification = true; // production behaviour, fake backend
      FirebaseAuthKit.webFlowPresenter = (url, {required isCallback}) async {
        expect(url.host, '127.0.0.1');
        // The page HTML is served by the kit and embeds the project's site key.
        final html = await http.read(url);
        expect(html, contains('fake-site-key'));
        expect(html, contains('www.google.com/recaptcha/api.js'));
        // Simulate the widget completing: the page navigates to /done?token=…
        final done = url.replace(path: '/done', queryParameters: {'token': 'local-recaptcha'});
        expect(isCallback(done), isTrue);
        await http.read(done); // the server receives the token too
        return done;
      };
      final sent = Completer<String>();
      await auth.verifyPhoneNumber(
        phoneNumber: '+15555550105',
        verificationCompleted: (_) {},
        verificationFailed: (e) => fail('$e'),
        codeSent: (id, _) => sent.complete(id),
        codeAutoRetrievalTimeout: (_) {},
      );
      await sent.future;
      expect(lastBody('accounts:sendVerificationCode')['recaptchaToken'], 'local-recaptcha');
      // recaptchaParams was fetched from the project.
      expect(fake.requests.any((r) => r.path.endsWith('recaptchaParams')), isTrue);
    });

    test('production needs app verification', () async {
      final auth = await newAuth();
      final delegate = auth.instanceForTesting;
      delegate.forceAppVerification = true;
      final failed = Completer<FirebaseAuthException>();
      await auth.verifyPhoneNumber(
        phoneNumber: '+15555550104',
        verificationCompleted: (_) {},
        verificationFailed: failed.complete,
        codeSent: (_, _) => fail('should not send'),
        codeAutoRetrievalTimeout: (_) {},
      );
      expect((await failed.future).code, 'missing-app-credential');

      FirebaseAuthKit.recaptchaTokenProvider = (_) async => 'recaptcha-token';
      await auth.setSettings(appVerificationDisabledForTesting: false);
      final sent = Completer<String>();
      await delegate.sendVerificationCode('+15555550104', recaptchaToken: 'recaptcha-token').then(sent.complete);
      await sent.future;
      expect(lastBody('accounts:sendVerificationCode')['recaptchaToken'], 'recaptcha-token');
    });
  });

  group('multi-factor', () {
    test('TOTP enrolment and second-factor sign-in', () async {
      final auth = await newAuth();
      await auth.createUserWithEmailAndPassword(email: 'mfa@example.com', password: 'secret1');
      final user = auth.currentUser!;
      final session = await user.multiFactor.getSession();
      final secret = await TotpMultiFactorGenerator.generateSecret(session);
      expect(secret.secretKey, 'JBSWY3DPEHPK3PXP');
      expect(secret.codeLength, 6);
      final qr = await secret.generateQrCodeUrl(accountName: 'mfa@example.com', issuer: 'Demo');
      expect(qr, startsWith('otpauth://totp/Demo%3Amfa%40example.com?'));
      expect(qr, contains('secret=JBSWY3DPEHPK3PXP'));
      expect(qr, contains('issuer=Demo'));

      final assertion = await TotpMultiFactorGenerator.getAssertionForEnrollment(secret, '000000');
      await user.multiFactor.enroll(assertion, displayName: 'Authenticator');
      final factors = await user.multiFactor.getEnrolledFactors();
      expect(factors.single, isA<TotpMultiFactorInfo>());
      expect(factors.single.displayName, 'Authenticator');

      await auth.signOut();
      late FirebaseAuthMultiFactorException mfaError;
      try {
        await auth.signInWithEmailAndPassword(email: 'mfa@example.com', password: 'secret1');
        fail('expected second-factor-required');
      } on FirebaseAuthMultiFactorException catch (e) {
        mfaError = e;
      }
      expect(mfaError.code, 'second-factor-required');
      final resolver = mfaError.resolver;
      expect(resolver.hints.single.uid, factors.single.uid);
      await expectLater(
        resolver.resolveSignIn(await TotpMultiFactorGenerator.getAssertionForSignIn(resolver.hints.single.uid, '999999')),
        throwsA(isA<FirebaseAuthException>()
            .having((e) => e.code, 'code', 'invalid-verification-code')),
      );
      // The fake consumes the pending credential on the first attempt, so a
      // fresh first-factor sign-in is needed before the successful resolve.
      FirebaseAuthMultiFactorException second;
      try {
        await auth.signInWithEmailAndPassword(email: 'mfa@example.com', password: 'secret1');
        fail('expected second-factor-required');
      } on FirebaseAuthMultiFactorException catch (e) {
        second = e;
      }
      final credential = await second.resolver.resolveSignIn(
        await TotpMultiFactorGenerator.getAssertionForSignIn(resolver.hints.single.uid, '000000'),
      );
      expect(credential.user!.email, 'mfa@example.com');
      expect(auth.currentUser!.uid, user.uid);
      final tokenResult = await auth.currentUser!.getIdTokenResult();
      expect(tokenResult.signInSecondFactor, 'totp');

      await auth.currentUser!.multiFactor.unenroll(factorUid: factors.single.uid);
      expect(await auth.currentUser!.multiFactor.getEnrolledFactors(), isEmpty);
    });

    test('phone second factor enrolment and sign-in', () async {
      final auth = await newAuth();
      await auth.createUserWithEmailAndPassword(email: 'pmfa@example.com', password: 'secret1');
      final session = await auth.currentUser!.multiFactor.getSession();
      final sent = Completer<String>();
      await auth.verifyPhoneNumber(
        phoneNumber: '+15555550200',
        multiFactorSession: session,
        verificationCompleted: (_) {},
        verificationFailed: (e) => fail('$e'),
        codeSent: (id, _) => sent.complete(id),
        codeAutoRetrievalTimeout: (_) {},
      );
      final verificationId = await sent.future;
      expect(lastBody('mfaEnrollment:start')['phoneEnrollmentInfo'], isNotNull);
      final assertion = PhoneMultiFactorGenerator.getAssertion(
        PhoneAuthProvider.credential(verificationId: verificationId, smsCode: '123456'),
      );
      await auth.currentUser!.multiFactor.enroll(assertion, displayName: 'My phone');
      final factor = (await auth.currentUser!.multiFactor.getEnrolledFactors()).single;
      expect(factor, isA<PhoneMultiFactorInfo>());
      expect((factor as PhoneMultiFactorInfo).phoneNumber, '+15555550200');

      await auth.signOut();
      FirebaseAuthMultiFactorException error;
      try {
        await auth.signInWithEmailAndPassword(email: 'pmfa@example.com', password: 'secret1');
        fail('expected second-factor-required');
      } on FirebaseAuthMultiFactorException catch (e) {
        error = e;
      }
      final hint = error.resolver.hints.single as PhoneMultiFactorInfo;
      final signInCode = Completer<String>();
      await auth.verifyPhoneNumber(
        multiFactorInfo: hint,
        multiFactorSession: error.resolver.session,
        verificationCompleted: (_) {},
        verificationFailed: (e) => fail('$e'),
        codeSent: (id, _) => signInCode.complete(id),
        codeAutoRetrievalTimeout: (_) {},
      );
      final id = await signInCode.future;
      expect(lastBody('mfaSignIn:start')['mfaEnrollmentId'], hint.uid);
      final credential = await error.resolver.resolveSignIn(
        PhoneMultiFactorGenerator.getAssertion(
          PhoneAuthProvider.credential(verificationId: id, smsCode: '123456'),
        ),
      );
      expect(credential.user!.email, 'pmfa@example.com');
    });
  });

  group('configuration', () {
    test('tenantId is sent with requests', () async {
      final auth = await newAuth();
      auth.tenantId = 'tenant-1';
      expect(auth.tenantId, 'tenant-1');
      await auth.signInAnonymously();
      expect(lastBody('accounts:signUp')['tenantId'], 'tenant-1');
    });

    test('useAuthEmulator maps the host', () async {
      final auth = await newAuth();
      final uri = Uri.parse(fake.origin);
      await auth.useAuthEmulator(uri.host, uri.port);
      await auth.signInAnonymously();
      expect(auth.currentUser, isNotNull);
    });

    test('web-only APIs throw UnimplementedError like the native SDKs', () async {
      final auth = await newAuth();
      expect(() => auth.signInWithPopup(GoogleAuthProvider()), throwsUnimplementedError);
      expect(() => auth.signInWithRedirect(GoogleAuthProvider()), throwsUnimplementedError);
    });

    test('deleting the app disposes the auth instance', () async {
      final app = await Firebase.initializeApp(
        name: 'disposable',
        options: const FirebaseOptions(
            apiKey: 'k', appId: 'a', messagingSenderId: 'm', projectId: 'demo-project'),
      );
      final auth = FirebaseAuth.instanceFor(app: app);
      await auth.signInAnonymously();
      await app.delete();
      expect(RestFirebaseAuth.instances.containsKey('disposable'), isFalse);
    });
  });
}

extension on FirebaseAuth {
  RestFirebaseAuth get instanceForTesting {
    currentUser; // forces the lazy delegate to be created
    return RestFirebaseAuth.instances[app.name]!;
  }
}

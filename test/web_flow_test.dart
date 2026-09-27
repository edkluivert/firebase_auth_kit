import 'dart:convert';

import 'package:firebase_auth_kit/firebase_auth_kit.dart';
import 'package:firebase_auth_kit/src/web/web_flow.dart';
import 'package:test/test.dart';

void main() {
  group('FirebaseAuthHandler URLs', () {
    final handler = FirebaseAuthHandler(
      apiKey: 'AIzaKey',
      appName: '[DEFAULT]',
      authDomain: 'demo.firebaseapp.com',
      appId: '1:123:ios:abc',
      iosBundleId: 'com.example.app',
      tenantId: 'tenant-1',
      languageCode: 'fr',
    );

    test('signInWithRedirect carries provider, scopes, params and session hash', () {
      final url = handler.signInWithRedirectUrl(
        providerId: 'github.com',
        sessionIdHash: 'abc123',
        eventId: 'evt',
        scopes: ['repo', 'user:email'],
        customParameters: {'allow_signup': 'false'},
      );
      expect(url.scheme, 'https');
      expect(url.host, 'demo.firebaseapp.com');
      expect(url.path, '/__/auth/handler');
      final q = url.queryParameters;
      expect(q['apiKey'], 'AIzaKey');
      expect(q['authType'], 'signInWithRedirect');
      expect(q['providerId'], 'github.com');
      expect(q['sessionId'], 'abc123');
      expect(q['scopes'], 'repo,user:email');
      expect(jsonDecode(q['customParameters']!), {'allow_signup': 'false'});
      expect(q['appId'], '1:123:ios:abc');
      expect(q['ibi'], 'com.example.app');
      expect(q['tid'], 'tenant-1');
      expect(q['hl'], 'fr');
      expect(q['eventId'], 'evt');
    });

    test('verifyApp URL and emulator routing', () {
      final emulator = FirebaseAuthHandler(
        apiKey: 'k',
        appName: '[DEFAULT]',
        authDomain: 'demo.firebaseapp.com',
        emulatorOrigin: 'http://127.0.0.1:9099',
      );
      final url = emulator.verifyAppUrl(eventId: 'e');
      expect(url.toString(), startsWith('http://127.0.0.1:9099/emulator/auth/handler?'));
      expect(url.queryParameters['authType'], 'verifyApp');
      expect(url.queryParameters['ibi'], 'firebase_auth_kit');
    });
  });

  group('callback parsing', () {
    test('iOS-style deep link with provider response', () {
      final response = Uri.parse('https://demo.firebaseapp.com/__/auth/handler')
          .replace(queryParameters: {'providerId': 'google.com', 'id_token': 'tok'});
      final callbackPage = Uri.parse('https://demo.firebaseapp.com/__/auth/callback').replace(
          queryParameters: {'authType': 'signInWithRedirect', 'link': response.toString()});
      final deepLink = Uri.parse('app-1-123-ios-abc://firebaseauth/link')
          .replace(queryParameters: {'deep_link_id': callbackPage.toString()});
      expect(isFirebaseCallbackUrl(deepLink), isTrue);
      expect(isFirebaseCallbackUrl(Uri.parse('https://demo.firebaseapp.com/x')), isFalse);
      final result = parseFirebaseCallback(deepLink);
      expect(result.link, response.toString());
      expect(result.error, isNull);
      expect(result.recaptchaToken, isNull);
    });

    test('the handler page carrying the provider response is itself the callback', () {
      // What a web view that only reports page loads sees after Google
      // redirects back to Firebase's handler (before the custom-scheme hop).
      final handler = Uri.parse('https://demo.firebaseapp.com/__/auth/handler').replace(
          queryParameters: {'state': 'AMbd…', 'code': '4/0AX…', 'scope': 'email profile'});
      expect(isFirebaseCallbackUrl(handler), isTrue);
      final result = parseFirebaseCallback(handler);
      expect(result.link, handler.toString());
      expect(result.error, isNull);

      // The initial handler request (no response yet) is not a callback.
      final initial = Uri.parse('https://demo.firebaseapp.com/__/auth/handler').replace(
          queryParameters: {'apiKey': 'k', 'authType': 'signInWithRedirect', 'providerId': 'google.com'});
      expect(isFirebaseCallbackUrl(initial), isFalse);
      // Neither is the provider's own login page.
      expect(isFirebaseCallbackUrl(Uri.parse('https://accounts.google.com/o/oauth2/auth?client_id=x&state=y')), isFalse);

      // Errors reported on the handler page.
      final failed = Uri.parse('https://demo.firebaseapp.com/__/auth/handler').replace(
          queryParameters: {'firebaseError': jsonEncode({'code': 'auth/unauthorized-domain', 'message': 'nope'})});
      expect(isFirebaseCallbackUrl(failed), isTrue);
      expect(parseFirebaseCallback(failed).error?.code, 'unauthorized-domain');

      // Emulator handler with the fake IdP response.
      final emulator = Uri.parse('http://127.0.0.1:9099/emulator/auth/handler').replace(
          queryParameters: {'providerId': 'google.com', 'id_token': '{"sub":"1"}'});
      expect(isFirebaseCallbackUrl(emulator), isTrue);
      expect(parseFirebaseCallback(emulator).link, emulator.toString());
    });

    test('Android intent URL', () {
      const response = 'https://demo.firebaseapp.com/__/auth/handler?providerId=github.com&access_token=t';
      final intent = Uri.parse('intent://firebase.auth/#Intent;scheme=genericidp;package=com.x;'
          'S.authType=signInWithRedirect;S.link=${Uri.encodeComponent(response)};'
          'B.encryptionEnabled=false;end;');
      final result = parseFirebaseCallback(intent);
      expect(result.link, response);
    });

    test('reCAPTCHA token and firebaseError', () {
      final callbackPage = Uri.parse('https://demo.firebaseapp.com/__/auth/callback').replace(
          queryParameters: {
        'authType': 'verifyApp',
        'link': 'https://demo.firebaseapp.com/__/auth/handler?recaptchaToken=03AF-token',
      });
      final deepLink = Uri.parse('app-1-123-ios-abc://firebaseauth/link')
          .replace(queryParameters: {'deep_link_id': callbackPage.toString()});
      expect(parseFirebaseCallback(deepLink).recaptchaToken, '03AF-token');

      final failed = Uri.parse('app-1-123-ios-abc://firebaseauth/link').replace(queryParameters: {
        'deep_link_id': Uri.parse('https://demo.firebaseapp.com/__/auth/callback').replace(
          queryParameters: {
            'firebaseError': jsonEncode({'code': 'auth/user-cancelled', 'message': 'Cancelled'}),
          },
        ).toString(),
      });
      final error = parseFirebaseCallback(failed).error;
      expect(error, isNotNull);
      expect(error!.code, 'user-cancelled');
      expect(error.message, 'Cancelled');
    });
  });

  group('helpers', () {
    test('sha256Hex and randomToken', () {
      expect(sha256Hex('abc'),
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
      expect(randomToken().length, 32);
      expect(randomToken(), isNot(randomToken()));
    });

    test('providerOptions reads scopes and parameters from every provider type', () {
      final github = GithubAuthProvider()
        ..addScope('repo')
        ..setCustomParameters({'allow_signup': 'false'});
      expect(providerOptions(github).scopes, ['repo']);
      expect(providerOptions(github).parameters, {'allow_signup': 'false'});
      final google = GoogleAuthProvider()
        ..addScope('email')
        ..setCustomParameters({'prompt': 'select_account'});
      expect(providerOptions(google).parameters, {'prompt': 'select_account'});
      final generic = OAuthProvider('microsoft.com')..setScopes(['mail.read']);
      expect(providerOptions(generic).scopes, ['mail.read']);
      expect(providerOptions(SAMLAuthProvider('saml.corp')).scopes, isEmpty);
    });

    test('runWebFlow without a presenter explains itself', () async {
      FirebaseAuthKit.reset();
      await expectLater(
        runWebFlow(Uri.parse('https://x'), operation: 'signInWithProvider()'),
        throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code',
            'operation-not-supported-in-this-environment')),
      );
      FirebaseAuthKit.webFlowPresenter = (url, {required isCallback}) async => null;
      await expectLater(
        runWebFlow(Uri.parse('https://x'), operation: 'x'),
        throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', 'user-cancelled')),
      );
      FirebaseAuthKit.reset();
    });
  });
}

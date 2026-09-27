import 'package:firebase_auth_kit/src/rest/auth_error_codes.dart';
import 'package:firebase_auth_kit/src/rest/identity_toolkit_client.dart';
import 'package:firebase_auth_kit/src/rest/jwt.dart';
import 'package:firebase_auth_kit/src/rest/user_mapper.dart';
import 'package:test/test.dart';

void main() {
  group('server error mapping', () {
    test('splits "CODE : detail" messages', () {
      final split = splitServerMessage(
          'TOO_MANY_ATTEMPTS_TRY_LATER : Access to this account has been temporarily disabled.');
      expect(split.serverCode, 'TOO_MANY_ATTEMPTS_TRY_LATER');
      expect(split.detail, startsWith('Access to this account'));
      expect(splitServerMessage('EMAIL_EXISTS').serverCode, 'EMAIL_EXISTS');
      expect(splitServerMessage('EMAIL_EXISTS').detail, isNull);
    });

    test('maps to FlutterFire codes', () {
      expect(authErrorCodeFor('EMAIL_EXISTS'), 'email-already-in-use');
      expect(authErrorCodeFor('INVALID_LOGIN_CREDENTIALS'), 'invalid-credential');
      expect(authErrorCodeFor('INVALID_PASSWORD'), 'wrong-password');
      expect(authErrorCodeFor('EMAIL_NOT_FOUND'), 'user-not-found');
      expect(authErrorCodeFor('TOKEN_EXPIRED'), 'user-token-expired');
      expect(authErrorCodeFor('CREDENTIAL_TOO_OLD_LOGIN_AGAIN'), 'requires-recent-login');
      expect(authErrorCodeFor('SOMETHING_NEW'), 'something-new');
    });

    test('builds exceptions from error bodies', () {
      final e = IdentityToolkitClient.exceptionFromErrorResponse(400, {
        'error': {'code': 400, 'message': 'WEAK_PASSWORD : Password should be at least 6 characters'}
      });
      expect(e.code, 'weak-password');
      expect(e.message, 'Password should be at least 6 characters');
      final noBody = IdentityToolkitClient.exceptionFromErrorResponse(403, null);
      expect(noBody.code, 'invalid-api-key');
      final defaultMessage = IdentityToolkitClient.exceptionFromErrorResponse(400, {
        'error': {'message': 'EMAIL_EXISTS'}
      });
      expect(defaultMessage.message, contains('already in use'));
    });
  });

  group('jwt', () {
    test('decodes payload and expiry', () {
      const token =
          'eyJhbGciOiJub25lIn0.eyJzdWIiOiJ1aWQxIiwiZXhwIjoxNzAwMDAwMDAwLCJmaXJlYmFzZSI6eyJzaWduX2luX3Byb3ZpZGVyIjoicGFzc3dvcmQifX0.sig';
      final payload = decodeJwtPayload(token);
      expect(payload?['sub'], 'uid1');
      expect(jwtExpiration(token),
          DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000, isUtc: true));
      final result = idTokenResultFrom(token);
      expect(result.signInProvider, 'password');
      expect(result.expirationTimestamp, 1700000000 * 1000);
      expect(decodeJwtPayload('not-a-jwt'), isNull);
    });
  });

  group('email links', () {
    test('extracts oobCode from direct and wrapped links', () {
      expect(
        oobCodeFromEmailLink(
            'https://p.firebaseapp.com/__/auth/action?mode=signIn&oobCode=ABC&apiKey=k'),
        'ABC',
      );
      final wrapped = Uri.parse('https://p.page.link/x').replace(queryParameters: {
        'link': 'https://p.firebaseapp.com/__/auth/action?mode=signIn&oobCode=XYZ',
      });
      expect(oobCodeFromEmailLink(wrapped.toString()), 'XYZ');
      expect(oobCodeFromEmailLink('https://example.com'), isNull);
    });
  });
}

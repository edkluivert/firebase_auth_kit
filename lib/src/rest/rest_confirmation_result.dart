import '../platform_interface.dart';
import 'rest_firebase_auth.dart';

/// Completes a phone sign-in / link started with `signInWithPhoneNumber` or
/// `linkWithPhoneNumber` once the user has typed the SMS code.
class RestConfirmationResult extends ConfirmationResultPlatform {
  RestConfirmationResult(this._auth, String verificationId, {this.linkToCurrentUser = false})
      : super(verificationId);

  final RestFirebaseAuth _auth;

  /// Whether [confirm] links the phone number to the signed-in user instead
  /// of signing in.
  final bool linkToCurrentUser;

  @override
  Future<UserCredentialPlatform> confirm(String verificationCode) {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: verificationCode,
    );
    if (linkToCurrentUser) {
      final user = _auth.currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'no-current-user',
          message: 'No user currently signed in.',
        );
      }
      return user.linkWithCredential(credential);
    }
    return _auth.signInWithCredential(credential);
  }
}

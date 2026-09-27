import '../platform_interface.dart';

/// The [UserCredentialPlatform] produced by the REST implementation.
class RestUserCredential extends UserCredentialPlatform {
  RestUserCredential({
    required super.auth,
    super.additionalUserInfo,
    super.credential,
    super.user,
  });
}

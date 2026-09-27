import 'dart:async';

import 'auth_persistence.dart';

/// Keeps the session in a secure key-value store such as
/// `dartnative_secure_storage`'s `SecureStorage` (Keychain on iOS,
/// EncryptedSharedPreferences on Android) or `flutter_secure_storage`'s
/// `FlutterSecureStorage`.
///
/// Those stores share the same method shape —
/// `read({required String key})`, `write({required String key, required
/// String? value})`, `delete({required String key})` — so the adapter accepts
/// any object that provides it and firebase_auth_kit does not have to depend
/// on either plugin (which would tie the package to the DartNative runtime and
/// break plain Dart use).
///
/// ```dart
/// FirebaseAuthKit.persistence = SecureStorageAuthPersistence(SecureStorage());
/// await FirebaseAuth.instance.authStateReady();
/// ```
///
/// or, equivalently, `await installSecureAuthPersistence(SecureStorage());`.
class SecureStorageAuthPersistence extends AuthPersistence {
  /// Wraps [storage], which must expose `read`, `write` and `delete` with the
  /// named `key` / `value` parameters described above. Any other object fails
  /// with [ArgumentError] on first use.
  SecureStorageAuthPersistence(Object storage) : _storage = storage;

  final dynamic _storage;

  Never _unsupported(Object error) {
    throw ArgumentError.value(
      _storage,
      'storage',
      'must expose read({key}), write({key, value}) and delete({key}) like '
          'dartnative_secure_storage\'s SecureStorage ($error)',
    );
  }

  @override
  Future<String?> read(String key) async {
    try {
      // ignore: avoid_dynamic_calls
      return await (_storage.read(key: key) as Future<Object?>) as String?;
    } on NoSuchMethodError catch (e) {
      _unsupported(e);
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      // ignore: avoid_dynamic_calls
      await (_storage.write(key: key, value: value) as Future<Object?>);
    } on NoSuchMethodError catch (e) {
      _unsupported(e);
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      // ignore: avoid_dynamic_calls
      await (_storage.delete(key: key) as Future<Object?>);
    } on NoSuchMethodError catch (e) {
      _unsupported(e);
    }
  }
}

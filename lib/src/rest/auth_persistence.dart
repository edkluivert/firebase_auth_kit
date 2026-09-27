import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../firebase_auth_kit_config.dart';

/// Stores the signed-in user between launches, the way the native SDKs keep
/// the session in the Keychain / SharedPreferences.
///
/// Values are opaque JSON strings; [key] identifies the app instance.
/// Implement this to keep the session behind an encrypted store:
///
/// ```dart
/// class SecureStoragePersistence implements AuthPersistence {
///   final _storage = SecureStorage(); // dartnative_secure_storage
///   @override
///   Future<String?> read(String key) => _storage.read(key: key);
///   @override
///   Future<void> write(String key, String value) => _storage.write(key: key, value: value);
///   @override
///   Future<void> delete(String key) => _storage.delete(key: key);
/// }
/// ```
abstract class AuthPersistence {
  const AuthPersistence();

  /// Returns the value stored under [key], or `null`.
  Future<String?> read(String key);

  /// Stores [value] under [key], replacing any previous value.
  Future<void> write(String key, String value);

  /// Removes [key].
  Future<void> delete(String key);
}

/// An [AuthPersistence] that can also be read synchronously, so that
/// `FirebaseAuth.instance.currentUser` is populated before the first `await`.
abstract class SyncReadableAuthPersistence extends AuthPersistence {
  const SyncReadableAuthPersistence();

  /// Synchronous counterpart of [read].
  String? readSync(String key);
}

/// Keeps the session in memory only; the user is signed out when the process
/// exits. This is what `setPersistence(Persistence.NONE)` switches to.
class InMemoryAuthPersistence extends SyncReadableAuthPersistence {
  InMemoryAuthPersistence();

  final Map<String, String> _values = {};

  @override
  String? readSync(String key) => _values[key];

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

/// Stores each key as a JSON file under [directory] (mode 0600 where the
/// platform supports it).
///
/// On iOS and Android the directory lives inside the app sandbox, which other
/// apps cannot read. The native Firebase SDKs additionally encrypt the session
/// (Keychain / EncryptedSharedPreferences); plug in `dartnative_secure_storage`
/// through [AuthPersistence] if you want the same.
class FileAuthPersistence extends SyncReadableAuthPersistence {
  FileAuthPersistence(this.directory);

  /// Uses [FirebaseAuthKit.storageDirectory] or [defaultDirectory].
  factory FileAuthPersistence.defaults() =>
      FileAuthPersistence(FirebaseAuthKit.storageDirectory ?? defaultDirectory());

  final Directory directory;

  /// The platform's private application-support directory.
  ///
  /// - `FIREBASE_AUTH_KIT_DIR` environment variable, when set.
  /// - iOS / macOS: `$HOME/Library/Application Support/firebase_auth_kit`
  ///   (`$HOME` is the app container on iOS).
  /// - Android: `/data/user/0/<package>/files/firebase_auth_kit`, resolving
  ///   the package name from `/proc/self/cmdline`.
  /// - Linux: `$XDG_DATA_HOME` or `$HOME/.local/share`, then `firebase_auth_kit`.
  /// - Windows: `%APPDATA%\firebase_auth_kit`.
  /// - Otherwise `.firebase_auth_kit` in the current directory.
  static Directory defaultDirectory() {
    final env = Platform.environment;
    final override = env['FIREBASE_AUTH_KIT_DIR'];
    if (override != null && override.isNotEmpty) return Directory(override);

    const name = 'firebase_auth_kit';
    final sep = Platform.pathSeparator;
    if (Platform.isAndroid) {
      final package = _androidPackageName();
      if (package != null) {
        for (final base in ['/data/user/0/$package', '/data/data/$package']) {
          final files = Directory('$base/files');
          if (files.existsSync() || Directory(base).existsSync()) {
            return Directory('${files.path}/$name');
          }
        }
      }
    }
    final home = env['HOME'];
    if ((Platform.isIOS || Platform.isMacOS) && home != null && home.isNotEmpty) {
      return Directory('$home${sep}Library${sep}Application Support$sep$name');
    }
    if (Platform.isLinux) {
      final xdg = env['XDG_DATA_HOME'];
      if (xdg != null && xdg.isNotEmpty) return Directory('$xdg$sep$name');
      if (home != null && home.isNotEmpty) {
        return Directory('$home$sep.local${sep}share$sep$name');
      }
    }
    if (Platform.isWindows) {
      final appData = env['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return Directory('$appData$sep$name');
      }
    }
    return Directory('${Directory.current.path}$sep.$name');
  }

  static String? _androidPackageName() {
    try {
      final raw = File('/proc/self/cmdline').readAsStringSync();
      final name = raw.split('\u0000').first.split(':').first.trim();
      return name.isEmpty ? null : name;
    } on FileSystemException {
      return null;
    }
  }

  File _fileFor(String key) {
    final digest = sha256.convert(utf8.encode(key)).toString().substring(0, 24);
    return File('${directory.path}${Platform.pathSeparator}$digest.json');
  }

  @override
  String? readSync(String key) {
    final file = _fileFor(key);
    try {
      if (!file.existsSync()) return null;
      return file.readAsStringSync();
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<String?> read(String key) async => readSync(key);

  @override
  Future<void> write(String key, String value) async {
    final file = _fileFor(key);
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    final temp = File('${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');
    await temp.writeAsString(value, flush: true);
    if (Platform.isMacOS || Platform.isLinux) {
      // Mobile sandboxes already isolate the directory; desktop gets 0600.
      try {
        await Process.run('chmod', ['600', temp.path]);
      } catch (_) {
        // Best effort.
      }
    }
    await temp.rename(file.path);
  }

  @override
  Future<void> delete(String key) async {
    final file = _fileFor(key);
    try {
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // Already gone.
    }
  }
}

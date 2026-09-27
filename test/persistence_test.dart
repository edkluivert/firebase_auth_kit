import 'dart:io';

import 'package:firebase_auth_kit/firebase_auth_kit.dart';
import 'package:test/test.dart';

void main() {
  test('FileAuthPersistence round-trips and deletes', () async {
    final dir = Directory.systemTemp.createTempSync('fak-persist');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = FileAuthPersistence(dir);
    expect(store.readSync('k'), isNull);
    await store.write('k', '{"a":1}');
    expect(store.readSync('k'), '{"a":1}');
    expect(await store.read('k'), '{"a":1}');
    expect(dir.listSync().whereType<File>().length, 1);
    await store.write('k', '{"a":2}');
    expect(store.readSync('k'), '{"a":2}');
    await store.delete('k');
    expect(store.readSync('k'), isNull);
  });

  test('InMemoryAuthPersistence is per instance', () async {
    final a = InMemoryAuthPersistence();
    final b = InMemoryAuthPersistence();
    await a.write('k', 'v');
    expect(a.readSync('k'), 'v');
    expect(b.readSync('k'), isNull);
  });

  test('defaultDirectory honours FIREBASE_AUTH_KIT_DIR', () {
    final dir = FileAuthPersistence.defaultDirectory();
    expect(dir.path, isNotEmpty);
  });

  secureStorageTests();
}

class _FakeSecureStorage {
  final Map<String, String> values = {};
  Future<String?> read({required String key}) async => values[key];
  Future<void> write({required String key, required String? value}) async {
    values[key] = value!;
  }
  Future<void> delete({required String key}) async => values.remove(key);
}

void secureStorageTests() {
  test('SecureStorageAuthPersistence adapts a flutter_secure_storage-style object', () async {
    final storage = _FakeSecureStorage();
    final persistence = SecureStorageAuthPersistence(storage);
    await persistence.write('k', 'v');
    expect(storage.values['k'], 'v');
    expect(await persistence.read('k'), 'v');
    await persistence.delete('k');
    expect(await persistence.read('k'), isNull);
    expect(
      () => SecureStorageAuthPersistence(Object()).read('k'),
      throwsArgumentError,
    );
  });

  test('installSecureAuthPersistence configures the kit', () async {
    FirebaseAuthKit.reset();
    await installSecureAuthPersistence(_FakeSecureStorage(), restoreDefaultApp: false);
    expect(FirebaseAuthKit.persistence, isA<SecureStorageAuthPersistence>());
    FirebaseAuthKit.reset();
  });
}

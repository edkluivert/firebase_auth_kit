import 'dart:io';

import 'package:firebase_auth_kit/firebase_core.dart';
import 'package:test/test.dart';

void main() {
  group('FirebaseOptions discovery', () {
    test('parses google-services.json', () {
      final options = FirebaseOptions.fromGoogleServicesJson('''
{
  "project_info": {
    "project_number": "123456789",
    "project_id": "demo-project",
    "storage_bucket": "demo-project.appspot.com",
    "firebase_url": "https://demo-project.firebaseio.com"
  },
  "client": [{
    "client_info": {"mobilesdk_app_id": "1:123456789:android:abc", "android_client_info": {"package_name": "com.example.app"}},
    "oauth_client": [{"client_id": "123-android.apps.googleusercontent.com", "client_type": 1}],
    "api_key": [{"current_key": "AIzaTestKey"}]
  }]
}
''');
      expect(options.projectId, 'demo-project');
      expect(options.apiKey, 'AIzaTestKey');
      expect(options.appId, '1:123456789:android:abc');
      expect(options.messagingSenderId, '123456789');
      expect(options.storageBucket, 'demo-project.appspot.com');
      expect(options.databaseURL, 'https://demo-project.firebaseio.com');
      expect(options.androidClientId, '123-android.apps.googleusercontent.com');
      expect(options.authDomain, 'demo-project.firebaseapp.com');
      expect(options.source, 'google-services.json');
    });

    test('parses GoogleService-Info.plist', () {
      final options = FirebaseOptions.fromGoogleServiceInfoPlist('''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
  <key>API_KEY</key><string>AIzaPlistKey</string>
  <key>GCM_SENDER_ID</key><string>987</string>
  <key>PROJECT_ID</key><string>plist-project</string>
  <key>GOOGLE_APP_ID</key><string>1:987:ios:def</string>
  <key>CLIENT_ID</key><string>987-ios.apps.googleusercontent.com</string>
  <key>REVERSED_CLIENT_ID</key><string>com.googleusercontent.apps.987-ios</string>
  <key>BUNDLE_ID</key><string>com.example.app</string>
  <key>STORAGE_BUCKET</key><string>plist-project.appspot.com</string>
  <key>IS_ADS_ENABLED</key><false/>
</dict>
</plist>
''');
      expect(options.projectId, 'plist-project');
      expect(options.apiKey, 'AIzaPlistKey');
      expect(options.appId, '1:987:ios:def');
      expect(options.messagingSenderId, '987');
      expect(options.iosClientId, '987-ios.apps.googleusercontent.com');
      expect(options.iosBundleId, 'com.example.app');
      expect(options.deepLinkURLScheme, 'com.googleusercontent.apps.987-ios');
    });

    test('reads environment variables and requires an API key', () {
      expect(
        FirebaseOptions.fromEnvironment({'FIREBASE_PROJECT_ID': 'p'}),
        isNull,
        reason: 'production needs an API key',
      );
      final withEmulator = FirebaseOptions.fromEnvironment({
        'FIREBASE_PROJECT_ID': 'p',
        'FIREBASE_AUTH_EMULATOR_HOST': 'localhost:9099',
      });
      expect(withEmulator, isNotNull);
      expect(withEmulator!.apiKey, 'fake-api-key');
      final full = FirebaseOptions.fromEnvironment({
        'FIREBASE_CONFIG': '{"projectId":"cfg","storageBucket":"cfg.appspot.com"}',
        'FIREBASE_API_KEY': 'k',
        'FIREBASE_APP_ID': 'a',
      });
      expect(full!.projectId, 'cfg');
      expect(full.storageBucket, 'cfg.appspot.com');
      expect(full.appId, 'a');
      expect(full.source, 'environment');
    });

    test('finds config files under a directory', () {
      final dir = Directory.systemTemp.createTempSync('fak-options');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/google-services.json').writeAsStringSync(
        '{"project_info":{"project_id":"file-project","project_number":"1"},'
        '"client":[{"client_info":{"mobilesdk_app_id":"1:1:android:1"},'
        '"api_key":[{"current_key":"AIzaFile"}]}]}',
      );
      final options = FirebaseOptions.fromFiles(directory: dir);
      expect(options?.projectId, 'file-project');
      expect(options?.apiKey, 'AIzaFile');
      expect(options?.source, endsWith('google-services.json'));
    });

    test('equality ignores source', () {
      const a = FirebaseOptions(
          apiKey: 'k', appId: 'a', messagingSenderId: 'm', projectId: 'p');
      const b = FirebaseOptions(
          apiKey: 'k',
          appId: 'a',
          messagingSenderId: 'm',
          projectId: 'p',
          source: 'x');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });

  group('Firebase apps', () {
    const options = FirebaseOptions(
        apiKey: 'k', appId: 'a', messagingSenderId: 'm', projectId: 'p');

    test('initializeApp creates and caches named apps', () async {
      final app = await Firebase.initializeApp(name: 'named', options: options);
      expect(app.name, 'named');
      expect(Firebase.app('named'), same(app));
      expect(Firebase.apps, contains(app));
      expect(
        () => Firebase.initializeApp(
            name: 'named', options: options.copyWith(apiKey: 'other')),
        throwsA(isA<FirebaseException>()
            .having((e) => e.code, 'code', 'duplicate-app')),
      );
      await app.delete();
      expect(() => Firebase.app('named'),
          throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'no-app')));
    });

    test('secondary apps need options', () {
      expect(() => Firebase.initializeApp(name: 'no-options'),
          throwsA(isA<FirebaseException>()));
    });

    test('demoProjectId builds emulator options', () async {
      final app = await Firebase.initializeApp(demoProjectId: 'demo-x');
      expect(app.name, 'demo-x');
      expect(app.options.projectId, 'demo-x');
      await app.delete();
    });
  });
}

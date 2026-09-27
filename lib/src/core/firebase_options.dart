// ignore_for_file: require_trailing_commas
// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of 'firebase_core.dart';

/// The options used to configure a Firebase app.
///
/// ```dart
/// await Firebase.initializeApp(
///   name: 'SecondaryApp',
///   options: const FirebaseOptions(
///     apiKey: '...',
///     appId: '...',
///     messagingSenderId: '...',
///     projectId: '...',
///   )
/// );
/// ```
@immutable
class FirebaseOptions {
  /// The options used to configure a Firebase app.
  const FirebaseOptions({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
    this.authDomain,
    this.databaseURL,
    this.storageBucket,
    this.measurementId,
    this.recaptchaSiteKey,
    // ios specific
    this.trackingId,
    this.deepLinkURLScheme,
    this.androidClientId,
    this.iosClientId,
    this.iosBundleId,
    this.appGroupId,
    this.source,
  });

  /// Named constructor to create [FirebaseOptions] from a Map.
  ///
  /// This constructor is used when platforms cannot directly return a
  /// [FirebaseOptions] instance, for example when data is sent back from a
  /// [MethodChannel].
  FirebaseOptions.fromMap(Map<dynamic, dynamic> map)
      : assert(map['apiKey'] != null, "'apiKey' cannot be null."),
        assert(map['appId'] != null, "'appId' cannot be null."),
        assert(map['messagingSenderId'] != null,
            "'messagingSenderId' cannot be null."),
        assert(map['projectId'] != null, "'projectId' cannot be null."),
        apiKey = map['apiKey'] as String,
        appId = map['appId'] as String,
        messagingSenderId = map['messagingSenderId'] as String,
        projectId = map['projectId'] as String,
        authDomain = map['authDomain'] as String?,
        databaseURL = map['databaseURL'] as String?,
        storageBucket = map['storageBucket'] as String?,
        measurementId = map['measurementId'] as String?,
        recaptchaSiteKey = map['recaptchaSiteKey'] as String?,
        trackingId = map['trackingId'] as String?,
        deepLinkURLScheme = map['deepLinkURLScheme'] as String?,
        androidClientId = map['androidClientId'] as String?,
        iosClientId = map['iosClientId'] as String?,
        iosBundleId = map['iosBundleId'] as String?,
        appGroupId = map['appGroupId'] as String?,
        source = map['source'] as String?;

  /// Returns a copy of these options with the given fields replaced.
  FirebaseOptions copyWith({
    String? apiKey,
    String? appId,
    String? messagingSenderId,
    String? projectId,
    String? authDomain,
    String? databaseURL,
    String? storageBucket,
    String? measurementId,
    String? recaptchaSiteKey,
    String? trackingId,
    String? deepLinkURLScheme,
    String? androidClientId,
    String? iosClientId,
    String? iosBundleId,
    String? appGroupId,
    String? source,
  }) {
    return FirebaseOptions(
      apiKey: apiKey ?? this.apiKey,
      appId: appId ?? this.appId,
      messagingSenderId: messagingSenderId ?? this.messagingSenderId,
      projectId: projectId ?? this.projectId,
      authDomain: authDomain ?? this.authDomain,
      databaseURL: databaseURL ?? this.databaseURL,
      storageBucket: storageBucket ?? this.storageBucket,
      measurementId: measurementId ?? this.measurementId,
      recaptchaSiteKey: recaptchaSiteKey ?? this.recaptchaSiteKey,
      trackingId: trackingId ?? this.trackingId,
      deepLinkURLScheme: deepLinkURLScheme ?? this.deepLinkURLScheme,
      androidClientId: androidClientId ?? this.androidClientId,
      iosClientId: iosClientId ?? this.iosClientId,
      iosBundleId: iosBundleId ?? this.iosBundleId,
      appGroupId: appGroupId ?? this.appGroupId,
      source: source ?? this.source,
    );
  }

  /// An API key used for authenticating requests from your app to Google
  /// servers.
  final String apiKey;

  /// The Google App ID that is used to uniquely identify an instance of an app.
  final String appId;

  /// The unique sender ID value used in messaging to identify your app.
  final String messagingSenderId;

  /// The Project ID from the Firebase console, for example "my-awesome-app".
  final String projectId;

  /// The auth domain used to handle redirects from OAuth provides.
  final String? authDomain;

  /// The database root URL, for example "https://my-awesome-app.firebaseio.com".
  final String? databaseURL;

  /// The Google Cloud Storage bucket name, for example
  /// "my-awesome-app.appspot.com".
  final String? storageBucket;

  /// The project measurement ID value used on web platforms with analytics.
  final String? measurementId;

  /// The reCAPTCHA site key used with reCAPTCHA Enterprise app verification.
  final String? recaptchaSiteKey;

  /// The tracking ID for Google Analytics, for example "UA-12345678-1", used to
  /// configure Google Analytics.
  ///
  /// This property is used on iOS only.
  final String? trackingId;

  /// The URL scheme used by iOS secondary apps for Dynamic Links.
  final String? deepLinkURLScheme;

  /// The Android client ID from the Firebase Console, for example
  /// "12345.apps.googleusercontent.com."
  ///
  /// This value is used by iOS only.
  final String? androidClientId;

  /// The iOS client ID from the Firebase Console, for example
  /// "12345.apps.googleusercontent.com."
  ///
  /// This value is used by iOS only.
  final String? iosClientId;

  /// The iOS bundle ID for the application. Defaults to
  /// `[[NSBundle mainBundle] bundleID]` when not set manually or in a plist.
  ///
  /// This property is used on iOS only.
  final String? iosBundleId;

  /// The iOS App Group identifier to share data between the application and the
  /// application extensions.
  ///
  /// This property is used on iOS only.
  final String? appGroupId;

  /// Where these options came from, for diagnostics: `dart-define`,
  /// `environment`, a config file path, or `null` when passed explicitly.
  /// Ignored by [==].
  final String? source;

  /// The current instance as a [Map].
  Map<String, String?> get asMap {
    return <String, String?>{
      'apiKey': apiKey,
      'appId': appId,
      'messagingSenderId': messagingSenderId,
      'projectId': projectId,
      'authDomain': authDomain,
      'databaseURL': databaseURL,
      'storageBucket': storageBucket,
      'measurementId': measurementId,
      'recaptchaSiteKey': recaptchaSiteKey,
      'trackingId': trackingId,
      'deepLinkURLScheme': deepLinkURLScheme,
      'androidClientId': androidClientId,
      'iosClientId': iosClientId,
      'iosBundleId': iosBundleId,
      'appGroupId': appGroupId,
    };
  }

  // Required from `fromMap` comparison
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FirebaseOptions) return false;
    return const MapEquality<String, String?>().equals(asMap, other.asMap);
  }

  @override
  int get hashCode => const MapEquality<String, String?>().hash(asMap);

  @override
  String toString() => asMap.toString();

  // ---------------------------------------------------------------------------
  // Zero-config discovery (see the class doc of [FirebaseOptions]).
  // ---------------------------------------------------------------------------

  /// Dart-define / environment keys consulted by [discover].
  static const String keyApiKey = 'FIREBASE_API_KEY';
  static const String keyAppId = 'FIREBASE_APP_ID';
  static const String keyProjectId = 'FIREBASE_PROJECT_ID';
  static const String keyMessagingSenderId = 'FIREBASE_MESSAGING_SENDER_ID';
  static const String keyAuthDomain = 'FIREBASE_AUTH_DOMAIN';
  static const String keyStorageBucket = 'FIREBASE_STORAGE_BUCKET';
  static const String keyDatabaseUrl = 'FIREBASE_DATABASE_URL';

  /// The environment variable the Firebase CLI and Admin SDKs use to point
  /// clients at a local Auth emulator, e.g. `localhost:9099`.
  static const String keyAuthEmulatorHost = 'FIREBASE_AUTH_EMULATOR_HOST';

  static const String _definedApiKey = String.fromEnvironment(keyApiKey);
  static const String _definedAppId = String.fromEnvironment(keyAppId);
  static const String _definedProjectId = String.fromEnvironment(keyProjectId);
  static const String _definedSenderId =
      String.fromEnvironment(keyMessagingSenderId);
  static const String _definedAuthDomain =
      String.fromEnvironment(keyAuthDomain);
  static const String _definedStorageBucket =
      String.fromEnvironment(keyStorageBucket);
  static const String _definedDatabaseUrl =
      String.fromEnvironment(keyDatabaseUrl);

  /// Options from `--dart-define=FIREBASE_PROJECT_ID=...` and friends, or
  /// `null` when no project id was defined at compile time.
  static FirebaseOptions? get fromDartDefines {
    if (_definedProjectId.isEmpty) return null;
    return _build(
      projectId: _definedProjectId,
      apiKey: _nonEmpty(_definedApiKey),
      appId: _nonEmpty(_definedAppId),
      messagingSenderId: _nonEmpty(_definedSenderId),
      authDomain: _nonEmpty(_definedAuthDomain),
      storageBucket: _nonEmpty(_definedStorageBucket),
      databaseURL: _nonEmpty(_definedDatabaseUrl),
      source: 'dart-define',
    );
  }

  /// Options from process environment variables: `FIREBASE_PROJECT_ID`,
  /// `GOOGLE_CLOUD_PROJECT`, `GCLOUD_PROJECT`, or the JSON `FIREBASE_CONFIG`
  /// used by Cloud Functions / Cloud Run, plus `FIREBASE_API_KEY`,
  /// `FIREBASE_APP_ID` and the other keys listed on this extension.
  static FirebaseOptions? fromEnvironment([Map<String, String>? environment]) {
    final env = environment ?? Platform.environment;
    String? projectId = env[keyProjectId] ??
        env['GOOGLE_CLOUD_PROJECT'] ??
        env['GCLOUD_PROJECT'];
    String? storageBucket = env[keyStorageBucket];
    String? databaseURL = env[keyDatabaseUrl];

    final config = env['FIREBASE_CONFIG'];
    if (config != null && config.isNotEmpty) {
      try {
        final decoded = jsonDecode(config);
        if (decoded is Map) {
          projectId ??= decoded['projectId'] as String?;
          storageBucket ??= decoded['storageBucket'] as String?;
          databaseURL ??= decoded['databaseURL'] as String?;
        }
      } on FormatException {
        // Not JSON; ignore.
      }
    }

    if (projectId == null || projectId.isEmpty) return null;
    return _build(
      projectId: projectId,
      apiKey: _nonEmpty(env[keyApiKey]),
      appId: _nonEmpty(env[keyAppId]),
      messagingSenderId: _nonEmpty(env[keyMessagingSenderId]),
      authDomain: _nonEmpty(env[keyAuthDomain]),
      storageBucket: _nonEmpty(storageBucket),
      databaseURL: _nonEmpty(databaseURL),
      source: 'environment',
      emulatorConfigured: _nonEmpty(env[keyAuthEmulatorHost]) != null,
    );
  }

  /// Parses an Android `google-services.json` document.
  static FirebaseOptions fromGoogleServicesJson(
    String json, {
    String source = 'google-services.json',
  }) {
    final decoded = jsonDecode(json);
    if (decoded is! Map) {
      throw const FormatException('google-services.json is not a JSON object');
    }
    final info = decoded['project_info'];
    final projectId = info is Map ? info['project_id'] as String? : null;
    if (projectId == null || projectId.isEmpty) {
      throw const FormatException(
          'google-services.json is missing project_info.project_id');
    }
    final clients = decoded['client'];
    Map<dynamic, dynamic>? client;
    if (clients is List && clients.isNotEmpty && clients.first is Map) {
      client = clients.first as Map;
    }
    String? apiKey;
    String? appId;
    String? androidClientId;
    if (client != null) {
      final keys = client['api_key'];
      if (keys is List && keys.isNotEmpty && keys.first is Map) {
        apiKey = (keys.first as Map)['current_key'] as String?;
      }
      final clientInfo = client['client_info'];
      if (clientInfo is Map) {
        appId = clientInfo['mobilesdk_app_id'] as String?;
      }
      final oauth = client['oauth_client'];
      if (oauth is List) {
        for (final entry in oauth) {
          if (entry is Map && entry['client_type'] == 1) {
            androidClientId = entry['client_id'] as String?;
            break;
          }
        }
      }
    }
    return _build(
      projectId: projectId,
      apiKey: _nonEmpty(apiKey),
      appId: _nonEmpty(appId),
      messagingSenderId:
          _nonEmpty(info is Map ? info['project_number']?.toString() : null),
      storageBucket:
          _nonEmpty(info is Map ? info['storage_bucket'] as String? : null),
      databaseURL:
          _nonEmpty(info is Map ? info['firebase_url'] as String? : null),
      androidClientId: _nonEmpty(androidClientId),
      source: source,
    )!;
  }

  /// Parses an iOS/macOS `GoogleService-Info.plist` document (XML plist).
  static FirebaseOptions fromGoogleServiceInfoPlist(
    String plistXml, {
    String source = 'GoogleService-Info.plist',
  }) {
    return _fromPlistValues(xmlPlistStrings(plistXml), source: source);
  }

  /// Parses a `GoogleService-Info.plist` from its bytes, in either the XML
  /// form the Firebase console downloads or the binary form Xcode writes into
  /// the app bundle.
  static FirebaseOptions fromGoogleServiceInfoPlistBytes(
    Uint8List bytes, {
    String source = 'GoogleService-Info.plist',
  }) {
    return _fromPlistValues(plistStrings(bytes), source: source);
  }

  static FirebaseOptions _fromPlistValues(
    Map<String, String> values, {
    required String source,
  }) {
    final projectId = values['PROJECT_ID'];
    if (projectId == null || projectId.isEmpty) {
      throw const FormatException(
          'GoogleService-Info.plist is missing PROJECT_ID');
    }
    return _build(
      projectId: projectId,
      apiKey: _nonEmpty(values['API_KEY']),
      appId: _nonEmpty(values['GOOGLE_APP_ID']),
      messagingSenderId: _nonEmpty(values['GCM_SENDER_ID']),
      storageBucket: _nonEmpty(values['STORAGE_BUCKET']),
      databaseURL: _nonEmpty(values['DATABASE_URL']),
      iosClientId: _nonEmpty(values['CLIENT_ID']),
      iosBundleId: _nonEmpty(values['BUNDLE_ID']),
      androidClientId: _nonEmpty(values['ANDROID_CLIENT_ID']),
      deepLinkURLScheme: _nonEmpty(values['REVERSED_CLIENT_ID']),
      trackingId: _nonEmpty(values['TRACKING_ID']),
      source: source,
    )!;
  }

  /// Options from the string resources the Google Services Gradle plugin
  /// compiles into an Android app (`google_api_key`, `google_app_id`,
  /// `project_id`, `gcm_defaultSenderId`, `google_storage_bucket`,
  /// `firebase_database_url`).
  static FirebaseOptions? fromAndroidResources(
    Map<String, String> resources, {
    String source = 'resources.arsc',
  }) {
    final projectId = _nonEmpty(resources['project_id']);
    if (projectId == null) return null;
    return _build(
      projectId: projectId,
      apiKey: _nonEmpty(resources['google_api_key']),
      appId: _nonEmpty(resources['google_app_id']),
      messagingSenderId: _nonEmpty(resources['gcm_defaultSenderId']),
      storageBucket: _nonEmpty(resources['google_storage_bucket']),
      databaseURL: _nonEmpty(resources['firebase_database_url']),
      source: source,
    );
  }

  /// Options found inside the Android APK at [apkPath]: the resources written
  /// by the Google Services Gradle plugin, or a `google-services.json`
  /// bundled as an asset. `null` when the APK holds neither.
  static FirebaseOptions? fromApk(String apkPath) {
    final config = readApkFirebaseConfig(apkPath);
    if (config == null) return null;
    final resources = config.resources;
    if (resources != null) {
      final options = fromAndroidResources(resources, source: '$apkPath!resources.arsc');
      if (options != null) return options;
    }
    final json = config.googleServicesJson;
    if (json != null) {
      try {
        return fromGoogleServicesJson(json, source: '$apkPath!${config.assetPath}');
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  /// Options from the APK the current Android process runs from, or `null`
  /// when not on Android or when the APK carries no Firebase configuration.
  static FirebaseOptions? fromCurrentApk() {
    final path = currentApkPath();
    if (path == null) return null;
    try {
      return fromApk(path);
    } catch (_) {
      return null;
    }
  }

  /// Config files bundled as DartNative / Flutter assets, found by walking the
  /// `flutter_assets` directory an iOS or macOS app bundle ships next to the
  /// executable (`Frameworks/App.framework/flutter_assets` or
  /// `flutter_assets`).
  static FirebaseOptions? fromBundledAssets() {
    final exeDir = File(Platform.resolvedExecutable).parent;
    final sep = Platform.pathSeparator;
    final roots = <Directory>[
      Directory('${exeDir.path}${sep}Frameworks${sep}App.framework${sep}flutter_assets'),
      Directory('${exeDir.path}${sep}flutter_assets'),
      Directory('${exeDir.path}$sep..${sep}Resources${sep}flutter_assets'),
    ];
    for (final root in roots) {
      if (!root.existsSync()) continue;
      try {
        for (final entity in root.listSync(recursive: true, followLinks: false)) {
          if (entity is! File) continue;
          final name = entity.uri.pathSegments.last;
          if (name == 'GoogleService-Info.plist' || name == 'google-services.json') {
            try {
              return fromFile(entity);
            } on FormatException {
              continue;
            }
          }
        }
      } on FileSystemException {
        continue;
      }
    }
    return null;
  }

  /// Loads options from a `google-services.json` or `GoogleService-Info.plist`
  /// file, chosen by extension.
  static FirebaseOptions fromFile(File file) {
    final bytes = file.readAsBytesSync();
    if (file.path.toLowerCase().endsWith('.plist') || isBinaryPlist(bytes)) {
      return fromGoogleServiceInfoPlistBytes(bytes, source: file.path);
    }
    return fromGoogleServicesJson(utf8.decode(bytes), source: file.path);
  }

  /// Candidate config file locations, most specific first: next to the running
  /// executable (an iOS/macOS app bundle ships `GoogleService-Info.plist`
  /// there), then the usual project-layout paths relative to [directory]
  /// (defaults to the current directory).
  static List<File> candidateFiles({Directory? directory}) {
    final root = directory?.path ?? Directory.current.path;
    final sep = Platform.pathSeparator;
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final paths = <String>[
      '$exeDir${sep}GoogleService-Info.plist',
      '$exeDir$sep..${sep}Resources${sep}GoogleService-Info.plist',
      '$exeDir${sep}google-services.json',
      '$root${sep}GoogleService-Info.plist',
      '$root${sep}google-services.json',
      '$root${sep}ios${sep}Runner${sep}GoogleService-Info.plist',
      '$root${sep}ios${sep}GoogleService-Info.plist',
      '$root${sep}macos${sep}Runner${sep}GoogleService-Info.plist',
      '$root${sep}android${sep}app${sep}google-services.json',
    ];
    return paths.map(File.new).toList();
  }

  /// Finds the first readable config file among [candidateFiles].
  static FirebaseOptions? fromFiles({Directory? directory}) {
    for (final file in candidateFiles(directory: directory)) {
      if (!file.existsSync()) continue;
      try {
        return fromFile(file);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Discovers options automatically, in order: `--dart-define`s, environment
  /// variables, the config files next to the app (`GoogleService-Info.plist`
  /// in an iOS / macOS bundle, `google-services.json` in the working
  /// directory), the Android APK (Google Services Gradle plugin resources or a
  /// bundled asset), then config files bundled as assets. Returns `null` when
  /// nothing is found.
  static FirebaseOptions? discover({
    Map<String, String>? environment,
    Directory? directory,
  }) {
    return fromDartDefines ??
        fromEnvironment(environment) ??
        fromFiles(directory: directory) ??
        (Platform.isAndroid ? fromCurrentApk() : null) ??
        fromBundledAssets();
  }

  /// Fills in the fields `firebase_core` requires but a partial source may not
  /// provide. Auth needs a real [apiKey] against production; against the
  /// emulator any value works, so one is synthesised when
  /// `FIREBASE_AUTH_EMULATOR_HOST` is set.
  static FirebaseOptions? _build({
    required String projectId,
    String? apiKey,
    String? appId,
    String? messagingSenderId,
    String? authDomain,
    String? storageBucket,
    String? databaseURL,
    String? iosClientId,
    String? iosBundleId,
    String? androidClientId,
    String? deepLinkURLScheme,
    String? trackingId,
    required String source,
    bool emulatorConfigured = false,
  }) {
    final emulator = emulatorConfigured ||
        _nonEmpty(Platform.environment[keyAuthEmulatorHost]) != null;
    if (apiKey == null && !emulator) return null;
    return FirebaseOptions(
      apiKey: apiKey ?? 'fake-api-key',
      appId: appId ?? '1:0:dart:0',
      messagingSenderId: messagingSenderId ?? '',
      projectId: projectId,
      authDomain: authDomain ?? '$projectId.firebaseapp.com',
      storageBucket: storageBucket,
      databaseURL: databaseURL,
      iosClientId: iosClientId,
      iosBundleId: iosBundleId,
      androidClientId: androidClientId,
      deepLinkURLScheme: deepLinkURLScheme,
      trackingId: trackingId,
      source: source,
    );
  }

  static String? _nonEmpty(String? value) =>
      (value == null || value.isEmpty) ? null : value;

}

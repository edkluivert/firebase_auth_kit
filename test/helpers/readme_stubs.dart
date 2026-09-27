// Stand-ins for app code and third-party plugins used in README snippets,
// so the generated readme_snippets_test.dart compiles.
// ignore_for_file: avoid_print, non_constant_identifier_names, prefer_const_declarations

import 'dart:async';

import 'package:firebase_auth_kit/firebase_auth_kit.dart';

// --- app-side values -------------------------------------------------------
final String email = 'ada@example.com';
final String password = 'secret';
final String newPassword = 'secret2';
final String currentPassword = 'secret';
final String passwordFromUser = 'secret';
final String oobCodeFromLink = 'code';
final String smsCode = '123456';
final String codeFromApp = '000000';
final String link = 'https://example.com/?mode=signIn&oobCode=x';
final String savedEmail = 'ada@example.com';
final String idToken = 'id-token';
final String facebookAccessToken = 't';
final String githubAccessToken = 't';
final String msIdToken = 't';
final String msAccessToken = 't';
final String tokenFromYourServer = 't';
final String tokenFromWebView = 't';
final AuthCredential googleCredential = GoogleAuthProvider.credential(idToken: 't');
String? verificationId;

// --- app-side functions ------------------------------------------------------
void showError(String message) {}
void showFieldError(String message) {}
void showInlineError(String message) {}
void showRetry(String message) {}
void askToSignInAgain() {}
void showCodeEntryScreen() {}
void saveLocally(String value) {}
void log(String message) {}
void startSecondFactor(MultiFactorResolver resolver) {}
void reauthenticateThen(void Function() retry) {}
void retry() {}
String generateRandomNonce() => 'nonce';
String sha256Hex(String input) => 'hash';
Future<String> myWebViewOAuth(String providerId) async => 't';
void runApp(Object app) {}
void setUp(void Function() body) {}

class MyApp {
  const MyApp({bool startSignedIn = false});
}

class _Router {
  void go(String route) {}
}

final router = _Router();

class _Label {
  String text = '';
}

final nameLabel = _Label();

// --- package:http --------------------------------------------------------------
class _Http {
  Future<Object> get(Uri uri, {Map<String, String>? headers}) async => Object();
}

final http = _Http();

// --- dartnative -------------------------------------------------------------------
class DartNativePluginRegistrant {
  static void registerAll() {}
}

// --- dartnative_firebase (Firebase.initializeApp() only) ---------------------------
class DnFirebase {
  static Future<void> initializeApp() async {}
}

// --- dartnative_secure_storage ----------------------------------------------------
class SecureStorage {
  const SecureStorage();
  Future<String?> read({required String key}) async => null;
  Future<void> write({required String key, required String? value}) async {}
  Future<void> delete({required String key}) async {}
}

// --- dartnative_social_sign_in ----------------------------------------------------
class GoogleSignIn {
  GoogleSignIn({String? serverClientId});
  Future<GoogleSignInAccount?> signIn() async => null;
}

class GoogleSignInAccount {
  final authentication = GoogleSignInAuthentication();
}

class GoogleSignInAuthentication {
  String? idToken;
  String? accessToken;
}

enum AppleIDAuthorizationScopes { email, fullName }

class AuthorizationCredentialAppleID {
  String? identityToken;
  String? givenName;
  String? familyName;
}

class SignInWithApple {
  static Future<AuthorizationCredentialAppleID> getAppleIDCredential({
    required List<AppleIDAuthorizationScopes> scopes,
    String? nonce,
  }) async =>
      AuthorizationCredentialAppleID();
}

// --- firestore_kit -----------------------------------------------------------------
class FirebaseFirestore {
  static final instance = FirebaseFirestore();
  Future<String?> Function()? tokenProvider;
}

// --- dartnative widgets (only what the README web-view snippet touches) --------------
abstract class Widget {
  const Widget({Object? key});
}

abstract class StatefulWidget extends Widget {
  const StatefulWidget({super.key});
  State createState();
}

abstract class State<T extends StatefulWidget> {
  late T widget;
  late BuildContext context;
  void initState() {}
  Widget build(BuildContext context);
}

class BuildContext {}

class Text extends Widget {
  const Text(String data) : super();
}

class AppBar extends Widget {
  const AppBar({Widget? title}) : super();
}

class Scaffold extends Widget {
  const Scaffold({Widget? appBar, Widget? body}) : super();
}

class Route<T> {}

class PageRoute<T> extends Route<T> {
  PageRoute({required Widget Function(BuildContext) builder});
}

class Navigator {
  static Navigator of(BuildContext context) => Navigator();
  Future<T?> push<T>(Route<T> route) async => null;
  void pop<T>([T? result]) {}
}

// --- dartnative_webview ---------------------------------------------------------------
enum JavaScriptMode { disabled, unrestricted }

enum NavigationDecision { navigate, prevent }

class NavigationRequest {
  const NavigationRequest({required this.url});
  final String url;
}

class NavigationDelegate {
  const NavigationDelegate({
    FutureOr<NavigationDecision> Function(NavigationRequest)? onNavigationRequest,
    void Function(String url)? onPageStarted,
    void Function(String url)? onPageFinished,
  });
}

class WebViewController {
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  Future<void> setNavigationDelegate(NavigationDelegate delegate) async {}
  Future<void> loadRequest(Uri uri) async {}
}

class WebViewWidget extends Widget {
  const WebViewWidget({required WebViewController controller}) : super();
}

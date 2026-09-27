import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../platform_interface/firebase_auth_exception.dart';
import 'web_flow.dart';

/// Serves Firebase's phone-auth reCAPTCHA from a loopback HTTP server inside
/// the app, so that completing it is an ordinary `http://127.0.0.1` page load
/// that any web view reports, and the token also arrives at the server
/// directly. This is what the web SDK renders on the app's own origin; the
/// site key comes from the project's `recaptchaParams`.
class LocalRecaptchaPage {
  LocalRecaptchaPage._(this._server, this.siteKey, this._completer);

  final HttpServer _server;
  final String siteKey;
  final Completer<String> _completer;

  /// The page URL to show.
  Uri get url => Uri.parse('http://127.0.0.1:${_server.port}/');

  /// Completes with the reCAPTCHA token once the user solved it.
  Future<String> get token => _completer.future;

  /// Whether [candidate] is this page's completion URL.
  bool isCallback(Uri candidate) =>
      candidate.host == '127.0.0.1' &&
      candidate.port == _server.port &&
      candidate.path == '/done';

  /// Starts serving a page for [siteKey], localised with [languageCode].
  static Future<LocalRecaptchaPage> start(String siteKey, {String? languageCode}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final completer = Completer<String>();
    final page = LocalRecaptchaPage._(server, siteKey, completer);
    server.listen((request) async {
      final path = request.uri.path;
      if (path == '/done' || path == '/token') {
        final token = request.uri.queryParameters['token'];
        if (token != null && token.isNotEmpty && !completer.isCompleted) {
          completer.complete(token);
        }
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.html
          ..write('<!doctype html><meta charset="utf-8"><title>Verified</title>'
              '<p style="font-family:-apple-system,sans-serif;padding:24px">'
              'Verified. You can return to the app.</p>');
      } else {
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.html
          ..write(_html(siteKey, languageCode));
      }
      await request.response.close();
    });
    return page;
  }

  static String _html(String siteKey, String? languageCode) {
    final hl = languageCode == null ? '' : '&hl=${Uri.encodeQueryComponent(languageCode)}';
    return '''<!doctype html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
<title>Verify</title>
<style>
  body { margin: 0; font-family: -apple-system, system-ui, sans-serif; background: #fff; color: #16191f; }
  .wrap { padding: 32px 20px; display: flex; flex-direction: column; align-items: center; gap: 20px; }
  p { margin: 0; font-size: 15px; text-align: center; }
  #err { color: #b42318; display: none; }
</style>
<script>
  function onToken(token) {
    window.location.href = '/done?token=' + encodeURIComponent(token);
  }
  function onError() {
    document.getElementById('err').style.display = 'block';
  }
  function onLoad() {
    try {
      grecaptcha.render('captcha', {
        sitekey: ${jsonEncode(siteKey)},
        callback: onToken,
        'error-callback': onError,
        'expired-callback': function () { grecaptcha.reset(); }
      });
    } catch (e) { onError(); }
  }
</script>
<script src="https://www.google.com/recaptcha/api.js?onload=onLoad&render=explicit$hl" async defer></script>
</head><body>
<div class="wrap">
  <p>Confirm you are not a robot to receive the SMS code.</p>
  <div id="captcha"></div>
  <p id="err">The verification could not load. Check your connection and try again.</p>
</div>
</body></html>''';
  }

  /// Stops the server.
  Future<void> close() => _server.close(force: true);
}

/// Runs the local reCAPTCHA page through the presenter and returns the token.
Future<String> runLocalRecaptcha({
  required String siteKey,
  String? languageCode,
  required Future<Uri?> Function(Uri url, {required bool Function(Uri) isCallback}) present,
}) async {
  final page = await LocalRecaptchaPage.start(siteKey, languageCode: languageCode);
  try {
    final presented = present(page.url, isCallback: (u) => page.isCallback(u) || isFirebaseCallbackUrl(u));
    // Whichever comes first: the token hitting the server, or the page being
    // dismissed (null) / navigated to /done.
    final result = await Future.any<Object?>([
      page.token,
      presented,
    ]);
    if (result is String) return result;
    if (result is Uri) {
      final token = result.queryParameters['token'];
      if (token != null && token.isNotEmpty) return token;
      if (page._completer.isCompleted) return page.token;
    }
    if (page._completer.isCompleted) return page.token;
    throw FirebaseAuthException(
      code: 'user-cancelled',
      message: 'The verification page was closed before completing.',
    );
  } finally {
    // Give the /done page a moment to be served before shutting down.
    unawaited(Future<void>.delayed(const Duration(seconds: 2), page.close));
  }
}

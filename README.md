# firebase_auth_kit

Firebase Authentication for DartNative, in pure Dart.

Sign users up and in with email and password, Google, Apple, phone numbers, magic links or
anonymous guest accounts, keep them signed in between launches, and get an ID token your backend
can trust. It is the `firebase_auth` API you already know from FlutterFire (version 6.7.0), running
on Firebase's public HTTPS API instead of the native SDKs, so it works in DartNative apps, plain Dart
programs, servers, CLIs and tests alike.

```dart
import 'package:firebase_auth_kit/firebase_auth_kit.dart';

final auth = FirebaseAuth.instance;
await auth.createUserWithEmailAndPassword(email: 'ada@example.com', password: 'hunter22');
print('Hello ${auth.currentUser!.email}');
```

---

## Contents

1. [What this is](#1-what-this-is)
2. [Quick start (5 minutes)](#2-quick-start-5-minutes)
3. [The five things to know](#3-the-five-things-to-know)
4. [Guides](#4-guides)
   - [Email and password](#41-email-and-password)
   - [Stay signed in between launches](#42-stay-signed-in-between-launches)
   - [React to sign-in state](#43-react-to-sign-in-state)
   - [Guest (anonymous) accounts](#44-guest-anonymous-accounts)
   - [Google, Apple, Facebook, GitHub and other providers](#45-google-apple-facebook-github-and-other-providers)
   - [Phone number sign-in](#46-phone-number-sign-in)
   - [Passwordless email links](#47-passwordless-email-links)
   - [Two-step verification (multi-factor)](#48-two-step-verification-multi-factor)
   - [Use the ID token with your backend or Firestore](#49-use-the-id-token-with-your-backend-or-firestore)
   - [Manage the account](#410-manage-the-account)
   - [Handle errors](#411-handle-errors)
   - [Custom tokens from your own server](#412-custom-tokens-from-your-own-server)
   - [Several Firebase projects in one app](#413-several-firebase-projects-in-one-app)
   - [Local development with the emulator](#414-local-development-with-the-emulator)
   - [Logging and debugging](#415-logging-and-debugging)
   - [Testing your own code](#416-testing-your-own-code)
   - [The web-view screen: OAuth providers and phone auth in production](#417-the-web-view-screen-oauth-providers-and-phone-auth-in-production)
5. [Platform setup](#5-platform-setup)
6. [Using it with dartnative_firebase and firestore_kit](#6-using-it-with-dartnative_firebase-and-firestore_kit)
7. [API cheat sheet](#7-api-cheat-sheet)
8. [Configuration reference](#8-configuration-reference)
9. [Troubleshooting](#9-troubleshooting)
10. [What is not supported](#10-what-is-not-supported)
11. [Migrating from FlutterFire](#11-migrating-from-flutterfire)
12. [Example, tests, license](#12-example-tests-license)

---

## 1. What this is

**Firebase Authentication** is Google's hosted sign-in service. You enable the sign-in methods you
want in the Firebase console, and Firebase stores the accounts, checks passwords, sends the
verification emails and SMS codes, and issues signed **ID tokens** that prove who the user is to
your backend, Firestore security rules or Cloud Functions.

**firebase_auth_kit** is the client for it. It gives your Dart code:

- one object, `FirebaseAuth.instance`, with methods such as `signInWithEmailAndPassword`;
- a `User` object with the profile (`email`, `displayName`, `photoURL`, `uid`…) and `getIdToken()`;
- streams that tell your UI when the user signs in or out;
- a session that survives app restarts, with tokens refreshed for you.

**How it differs from the official plugin.** FlutterFire's `firebase_auth` is a Flutter plugin that
calls the native Firebase SDK through a platform channel. DartNative apps have no plugin registry for
that SDK, and do not need one: Firebase Auth is a documented HTTPS API, so this package talks to it
directly from Dart. Same API surface, no native code, no Gradle plugin, no CocoaPods dependency.

**Demo app.** [github.com/edkluivert/firebase_kits_demo) shows this package, `firestore_kit` and `dartnative_firebase` running together against a real project.

**What it is not.** It does not replace `dartnative_firebase` (Crashlytics and push notifications
need the native SDKs) or `firestore_kit` (the database). It pairs with both; see
[section 6](#6-using-it-with-dartnative_firebase-and-firestore_kit).

---

## 2. Quick start (5 minutes)

### Step 1 — Create a Firebase project and turn on Email/Password

1. Go to [console.firebase.google.com](https://console.firebase.google.com), create a project (or
   open an existing one).
2. In the left menu open **Build → Authentication**, click **Get started**.
3. Open the **Sign-in method** tab and enable **Email/Password**. (Enable other methods later as
   you need them.)

### Step 2 — Register your app and download its config

In **Project settings → Your apps**, add an iOS app (bundle id) and/or an Android app (package name).

- **iOS**: download `GoogleService-Info.plist` and add it to your app target in Xcode. If you use
  `dartnative_firebase` you have done this already.
- **Android**: download `google-services.json` into `android/app/`, and apply the Google
  Services Gradle plugin, the standard step of every Firebase Android setup (you have done it
  already if you use `dartnative_firebase`):

  ```kotlin
  // android/settings.gradle.kts
  plugins {
      id("com.google.gms.google-services") version "4.4.2" apply false
  }
  ```

  ```kotlin
  // android/app/build.gradle.kts
  plugins {
      id("com.google.gms.google-services")
  }
  ```

  The plugin compiles the JSON into the app; the kit reads those values back at runtime.

### Step 3 — Add the package

```yaml
# pubspec.yaml
dependencies:
  firebase_auth_kit: ^0.1.0
```

```sh
dn pub get        # DartNative app
dart pub get      # plain Dart
```

Nothing to register in `main()`, no native setup.

### Step 4 — Sign someone up

```dart
import 'package:firebase_auth_kit/firebase_auth_kit.dart';

Future<void> main() async {
  final auth = FirebaseAuth.instance;   // finds your Firebase config automatically

  // Tell the UI whenever the user signs in or out.
  auth.authStateChanges().listen((User? user) {
    print(user == null ? 'signed out' : 'signed in as ${user.email}');
  });

  try {
    await auth.createUserWithEmailAndPassword(
      email: 'ada@example.com',
      password: 'correct horse battery staple',
    );
  } on FirebaseAuthException catch (e) {
    print(e.userMessage);   // e.g. "An account already exists with that email address."
  }

  final idToken = await auth.currentUser?.getIdToken();
  print('send this to your backend: $idToken');
}
```

Run it:

```sh
dn run
```

That is all: the plist (iOS) or the compiled `google-services.json` (Android) is found
automatically.

### Step 5 (recommended) — Keep sessions in secure storage

The default keeps the session in a private file inside the app sandbox. For a shipped app, store
it in the iOS Keychain / Android EncryptedSharedPreferences instead. Add
[dartnative_secure_storage](https://dartpub.dev/plugins/dartnative_secure_storage) and call one
function before anything else uses `FirebaseAuth`:

```dart
import 'package:dartnative_secure_storage/dartnative_secure_storage.dart';
import 'package:firebase_auth_kit/firebase_auth_kit.dart';

void main() async {
  DartNativePluginRegistrant.registerAll();
  await installSecureAuthPersistence(SecureStorage());   // restores last session too
  runApp(const MyApp());
}
```

That is a complete setup. Everything below is detail.

### Plain Dart / server / CLI quick start

No config files needed. Either set environment variables

```sh
export FIREBASE_PROJECT_ID=my-project
export FIREBASE_APP_ID=1:123456789:web:abc123
export FIREBASE_API_KEY=AIzaSy...
dart run bin/tool.dart
```

or pass the options in code:

```dart
import 'package:firebase_auth_kit/firebase_auth_kit.dart';
import 'package:firebase_auth_kit/firebase_core.dart';

Future<void> main() async {
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSy...',
      appId: '1:123456789:web:abc123',
      messagingSenderId: '123456789',
      projectId: 'my-project',
    ),
  );
  final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
    email: 'ada@example.com',
    password: 'correct horse battery staple',
  );
  print(credential.user!.uid);
}
```

The API key is the **web API key** from Project settings. It is not a secret; it identifies the
project, and Firebase security comes from the ID tokens, not from hiding the key.

---

## 3. The five things to know

**`FirebaseAuth.instance`** is the entry point. It is created on first use and reads your config
from `GoogleService-Info.plist` (iOS), the compiled `google-services.json` (Android),
`--dart-define`s or environment variables. Nothing to initialize.

**`auth.currentUser`** is the signed-in `User` or `null`. It is a snapshot; read it when you need
the uid or email right now. It is already populated at startup from the saved session.

**`auth.authStateChanges()`** is the stream to drive your UI. Every listener gets the current
state immediately, then every sign-in and sign-out. There are two more streams:
`idTokenChanges()` also fires when the token refreshes, `userChanges()` also fires when the
profile changes (display name, email verified, linked providers).

**`UserCredential`** is what every sign-in method returns: the `user`, plus
`additionalUserInfo.isNewUser` (true on first sign-up) and, for Google and friends, the provider's
own tokens in `credential`.

**Tokens.** `await user.getIdToken()` gives a JWT that is valid for an hour; the kit refreshes it
automatically using the long-lived refresh token stored with the session, so just call it whenever
you make a request. Never store the ID token yourself.

---

## 4. Guides

Every snippet assumes:

```dart
import 'package:firebase_auth_kit/firebase_auth_kit.dart';

final auth = FirebaseAuth.instance;
```

### 4.1 Email and password

Enable **Email/Password** in the console first.

```dart
// Sign up (creates the account and signs in)
final signUp = await auth.createUserWithEmailAndPassword(
  email: email,
  password: password,
);
print('new uid: ${signUp.user!.uid}');

// Sign in
await auth.signInWithEmailAndPassword(email: email, password: password);

// Who is signed in?
final user = auth.currentUser;
print('${user?.email} verified=${user?.emailVerified}');

// Sign out
await auth.signOut();
```

**Ask the user to verify their email**

```dart
await auth.currentUser!.sendEmailVerification();
// Later, after they clicked the link in the mail:
await auth.currentUser!.reload();
print(auth.currentUser!.emailVerified);   // true
```

**Forgot password**

```dart
await auth.sendPasswordResetEmail(email: email);
// Firebase emails a link. With the default Firebase-hosted page the user sets a new password
// there and nothing else is needed. If you host your own page, finish it with:
await auth.confirmPasswordReset(code: oobCodeFromLink, newPassword: newPassword);
```

**Change the password of the signed-in user**

```dart
await auth.currentUser!.updatePassword(newPassword);
```

Sensitive operations (changing the password, deleting the account) fail with
`requires-recent-login` if the user signed in a while ago. Handle it by asking for the password
again:

```dart
try {
  await auth.currentUser!.updatePassword(newPassword);
} on FirebaseAuthException catch (e) {
  if (e.requiresRecentLogin) {
    await auth.currentUser!.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: currentPassword),
    );
    await auth.currentUser!.updatePassword(newPassword);
  }
}
```

**Localise the emails Firebase sends**

```dart
await auth.setLanguageCode('fr');
```

### 4.2 Stay signed in between launches

This happens by default: after `signIn…` succeeds the session is saved, and on the next launch
`FirebaseAuth.instance.currentUser` is already set before your first `await`. `signOut()` deletes
the saved session.

**Where it is saved.** By default in a file only your app can read (0600, inside the sandbox).
For production apps use the platform's secure store instead. It takes one call in `main()`,
before the first use of `FirebaseAuth`:

```dart
import 'package:dartnative_secure_storage/dartnative_secure_storage.dart';

void main() async {
  DartNativePluginRegistrant.registerAll();
  await installSecureAuthPersistence(SecureStorage());
  runApp(const MyApp());
}
```

`installSecureAuthPersistence` puts the session in the Keychain (iOS) or EncryptedSharedPreferences
(Android) and waits for the previous session to load, so `currentUser` is ready when `runApp` runs.
The kit does not depend on the plugin; it accepts any object with `read`, `write` and
`delete({key})` methods, which is also what `flutter_secure_storage` has.

**Any other store** is three methods:

```dart
class MyStore extends AuthPersistence {
  @override
  Future<String?> read(String key) async => /* fetch */ null;
  @override
  Future<void> write(String key, String value) async {/* save */}
  @override
  Future<void> delete(String key) async {/* remove */}
}

void main() async {
  FirebaseAuthKit.persistence = MyStore();
  await FirebaseAuth.instance.authStateReady();   // wait for the async store
  runApp(const MyApp());
}
```

**Do not remember the user** (shared devices):

```dart
await auth.setPersistence(Persistence.NONE);   // memory only, gone when the app exits
```

### 4.3 React to sign-in state

```dart
auth.authStateChanges().listen((User? user) {
  if (user == null) {
    router.go('/login');
  } else {
    router.go('/home');
  }
});
```

Use `userChanges()` when a screen shows profile fields, so it refreshes after
`updateProfile`, `reload` or linking a provider:

```dart
auth.userChanges().listen((user) => nameLabel.text = user?.displayName ?? '');
```

If your session store is asynchronous (secure storage), gate the first route:

```dart
await FirebaseAuth.instance.authStateReady();
runApp(MyApp(startSignedIn: FirebaseAuth.instance.currentUser != null));
```

### 4.4 Guest (anonymous) accounts

Enable **Anonymous** in the console. Guests get a real `uid` you can store data under, and can
upgrade to a full account later while keeping that `uid`:

```dart
await auth.signInAnonymously();
print(auth.currentUser!.isAnonymous);   // true

// Later: upgrade in place, same uid
await auth.currentUser!.linkWithCredential(
  EmailAuthProvider.credential(email: email, password: password),
);
print(auth.currentUser!.isAnonymous);   // false
```

Calling `signInAnonymously()` again while a guest is signed in returns the same guest.

### 4.5 Google, Apple, Facebook, GitHub and other providers

The pattern is always the same: get a token from the provider with the platform's own sign-in
sheet, then hand it to Firebase with `signInWithCredential`. For Google and Apple use
[dartnative_social_sign_in](https://dartpub.dev/plugins/dartnative_social_sign_in).

**Google** (enable *Google* in the console):

```dart
import 'package:dartnative_social_sign_in/social_sign_in.dart';

final account = await GoogleSignIn(serverClientId: 'YOUR-WEB-CLIENT-ID').signIn();
if (account != null) {
  final googleAuth = account.authentication;
  final result = await auth.signInWithCredential(
    GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    ),
  );
  print('${result.user!.displayName}, new: ${result.additionalUserInfo!.isNewUser}');
}
```

**Apple** (enable *Apple* in the console, add the *Sign in with Apple* capability in Xcode):

```dart
import 'package:dartnative_social_sign_in/social_sign_in.dart';

final rawNonce = generateRandomNonce();               // any 32+ random characters
final appleCredential = await SignInWithApple.getAppleIDCredential(
  scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
  nonce: sha256Hex(rawNonce),                         // Apple gets the hash…
);
await auth.signInWithCredential(
  AppleAuthProvider.credentialWithIDToken(
    appleCredential.identityToken!,
    rawNonce,                                         // …Firebase gets the raw value
    AppleFullPersonName(
      givenName: appleCredential.givenName,
      familyName: appleCredential.familyName,
    ),
  ),
);
```

Apple sends the name only on the very first sign-in; the kit stores it on the new account as
`displayName`, like the native SDKs.

**Facebook, GitHub, Twitter, Microsoft, Yahoo, anything OAuth**: obtain the token with the
provider's SDK or your own OAuth flow, then:

```dart
await auth.signInWithCredential(FacebookAuthProvider.credential(facebookAccessToken));
await auth.signInWithCredential(GithubAuthProvider.credential(githubAccessToken));
await auth.signInWithCredential(
  OAuthProvider('microsoft.com').credential(idToken: msIdToken, accessToken: msAccessToken),
);
```

**Link a second provider to the current account** (so the user can sign in either way):

```dart
await auth.currentUser!.linkWithCredential(GoogleAuthProvider.credential(idToken: idToken));
print(auth.currentUser!.providerData.map((p) => p.providerId));  // (password, google.com)
await auth.currentUser!.unlink('google.com');
```

**Same email, different provider.** If someone signed up with a password and later taps
"Continue with Google" using the same email, Firebase refuses to create a second account and the
exception tells you how to recover:

```dart
try {
  await auth.signInWithCredential(googleCredential);
} on FirebaseAuthException catch (e) {
  if (e.errorCode == FirebaseAuthErrorCode.accountExistsWithDifferentCredential) {
    // 1. sign in with the method the account already has (e.email tells you which user)
    await auth.signInWithEmailAndPassword(email: e.email!, password: passwordFromUser);
    // 2. attach Google to it so both work from now on
    await auth.currentUser!.linkWithCredential(e.credential!);
  }
}
```

**`signInWithProvider` for everything else (GitHub, Microsoft, Yahoo, Twitter, SAML, any
OAuth provider enabled in the console).** FlutterFire opens Firebase's hosted sign-in page and
comes back with the result. The kit does the same once you give it a way to show a web page,
which is one small screen built on `dartnative_webview`; see
[4.17](#417-the-web-view-screen-oauth-providers-and-phone-auth-in-production). With that in
place:

```dart
final result = await auth.signInWithProvider(
  GithubAuthProvider()..addScope('user:email'),
);
await auth.currentUser!.linkWithProvider(MicrosoftAuthProvider());
await auth.currentUser!.reauthenticateWithProvider(GithubAuthProvider());
```

Without the screen those three methods throw `operation-not-supported-in-this-environment`, and
the credential route above still works for every provider you can get a token from.


### 4.6 Phone number sign-in

Enable **Phone** in the console. The flow has two steps: Firebase sends an SMS, the user types
the code.

```dart
String? verificationId;

await auth.verifyPhoneNumber(
  phoneNumber: '+15555550123',                       // E.164: plus sign and country code
  codeSent: (id, resendToken) {
    verificationId = id;
    showCodeEntryScreen();
  },
  verificationCompleted: (credential) => auth.signInWithCredential(credential),
  verificationFailed: (e) => showError(e.userMessage),
  codeAutoRetrievalTimeout: (id) {},
);

// after the user typed the 6 digits:
await auth.signInWithCredential(
  PhoneAuthProvider.credential(verificationId: verificationId!, smsCode: smsCode),
);
```

The web-style shape works too and is shorter:

```dart
final confirmation = await auth.signInWithPhoneNumber('+15555550123');
await confirmation.confirm(smsCode);
```

To add a phone number to an existing account use `auth.currentUser!.linkWithPhoneNumber(...)` and
`confirm` the result, or `linkWithCredential` with a `PhoneAuthProvider.credential`.

**App verification, read this once.** Firebase refuses to send an SMS unless the request proves it
comes from a real app, to stop bots burning your SMS quota. The native SDKs do that silently via
APNs (iOS) or Play Integrity (Android). There is no way to do that from pure Dart, so this package
supports the other two mechanisms Firebase offers:

| Situation | What to do |
| --- | --- |
| Developing against the emulator | Nothing. No verification needed; codes are listed at `GET http://127.0.0.1:9099/emulator/v1/projects/<project>/verificationCodes`. |
| Developing / QA against the real project | In the console add **test phone numbers** (Authentication → Sign-in method → Phone → *Phone numbers for testing*). Then `await auth.setSettings(appVerificationDisabledForTesting: true);` — no SMS is sent, the fixed code you configured works. |
| Production | Set up the web-view screen from [4.17](#417-the-web-view-screen-oauth-providers-and-phone-auth-in-production). The kit then shows Firebase's hosted reCAPTCHA page and sends its token, exactly like the iOS SDK's fallback. (Have your own reCAPTCHA? `FirebaseAuthKit.recaptchaTokenProvider = (auth) async => token;`) |

Without one of the three, phone requests fail with `missing-app-credential` and a message that says
exactly this.

### 4.7 Passwordless email links

Enable **Email/Password → Email link (passwordless sign-in)** in the console and add your app's
domain to *Authorized domains*.

```dart
// 1. send the link
await auth.sendSignInLinkToEmail(
  email: email,
  actionCodeSettings: ActionCodeSettings(
    url: 'https://myapp.example.com/finish-sign-in',   // where the link lands
    handleCodeInApp: true,                             // required for email links
    iOSBundleId: 'com.example.myapp',
    androidPackageName: 'com.example.myapp',
    androidInstallApp: true,
  ),
);
saveLocally(email);   // you need it again in step 2

// 2. when the app is opened from the link (app_links_kit gives you the URL):
if (auth.isSignInWithEmailLink(link)) {
  await auth.signInWithEmailLink(email: savedEmail, emailLink: link);
}
```

### 4.8 Two-step verification (multi-factor)

Requires **Identity Platform** upgrade on the project (free tier available) and *SMS multi-factor*
or *TOTP* enabled under Authentication → Sign-in method → Advanced. The user's email must be
verified before enrolling.

**Enrol an authenticator app (TOTP)**

```dart
final user = auth.currentUser!;
final session = await user.multiFactor.getSession();
final secret = await TotpMultiFactorGenerator.generateSecret(session);

// Show this as a QR code, or let them copy secret.secretKey
final qrUrl = await secret.generateQrCodeUrl(accountName: user.email, issuer: 'My App');

// The user types the 6-digit code from the authenticator app:
final assertion = await TotpMultiFactorGenerator.getAssertionForEnrollment(secret, codeFromApp);
await user.multiFactor.enroll(assertion, displayName: 'Authenticator app');
```

**Enrol a phone**

```dart
final session = await auth.currentUser!.multiFactor.getSession();
String? enrolmentVerificationId;
await auth.verifyPhoneNumber(
  phoneNumber: '+15555550123',
  multiFactorSession: session,
  codeSent: (id, _) => enrolmentVerificationId = id,
  verificationCompleted: (_) {},
  verificationFailed: (e) => showError(e.userMessage),
  codeAutoRetrievalTimeout: (_) {},
);
// after the SMS code arrives:
await auth.currentUser!.multiFactor.enroll(
  PhoneMultiFactorGenerator.getAssertion(
    PhoneAuthProvider.credential(verificationId: enrolmentVerificationId!, smsCode: smsCode),
  ),
  displayName: 'My phone',
);
```

**Sign in when a second factor is required**

```dart
try {
  await auth.signInWithEmailAndPassword(email: email, password: password);
} on FirebaseAuthMultiFactorException catch (e) {
  final resolver = e.resolver;
  final hint = resolver.hints.first;                 // the factors the user enrolled

  if (hint is TotpMultiFactorInfo) {
    final assertion = await TotpMultiFactorGenerator.getAssertionForSignIn(hint.uid, codeFromApp);
    await resolver.resolveSignIn(assertion);
  } else if (hint is PhoneMultiFactorInfo) {
    String? verificationId;
    await auth.verifyPhoneNumber(
      multiFactorInfo: hint,
      multiFactorSession: resolver.session,
      codeSent: (id, _) => verificationId = id,
      verificationCompleted: (_) {},
      verificationFailed: (e) => showError(e.userMessage),
      codeAutoRetrievalTimeout: (_) {},
    );
    // after the SMS code arrives:
    await resolver.resolveSignIn(
      PhoneMultiFactorGenerator.getAssertion(
        PhoneAuthProvider.credential(verificationId: verificationId!, smsCode: smsCode),
      ),
    );
  }
}
```

`FirebaseAuthMultiFactorException` extends `FirebaseAuthException`, so catch it **before** the
general one. List and remove factors with `user.multiFactor.getEnrolledFactors()` and
`user.multiFactor.unenroll(factorUid: ...)`.

### 4.9 Use the ID token with your backend or Firestore

```dart
final token = await auth.currentUser!.getIdToken();
final response = await http.get(
  Uri.parse('https://api.example.com/me'),
  headers: {'Authorization': 'Bearer $token'},
);
```

Your server verifies the token with the Firebase Admin SDK (`verifyIdToken`). Call `getIdToken()`
each time; it returns the cached token while valid and refreshes it when it is about to expire.
`getIdToken(true)` forces a refresh, for example after your server changed the user's custom
claims.

Read the claims on the client:

```dart
final result = await auth.currentUser!.getIdTokenResult();
print(result.claims?['admin']);          // custom claims set by your backend
print(result.signInProvider);            // 'password', 'google.com', 'phone', …
print(result.expirationTime);
```

With **firestore_kit**, so security rules see the user:

```dart
FirebaseFirestore.instance.tokenProvider =
    () async => await FirebaseAuth.instance.currentUser?.getIdToken();
```

### 4.10 Manage the account

```dart
final user = auth.currentUser!;

await user.updateProfile(displayName: 'Ada Lovelace', photoURL: 'https://…/ada.png');
await user.updateDisplayName(null);            // remove it
await user.verifyBeforeUpdateEmail('new@example.com');   // emails a confirmation link first
await user.updatePassword(newPassword);
await user.reload();                            // pull the latest server state
await user.delete();                            // signs out too
```

Profile fields on a `User` object update in place, so widgets holding an older `User` reference
see the new values after `reload()` or `updateProfile()`.

Metadata: `user.metadata.creationTime`, `user.metadata.lastSignInTime`,
`user.providerData` (one `UserInfo` per linked provider), `user.phoneNumber`, `user.tenantId`.

### 4.11 Handle errors

Every failure is a `FirebaseAuthException`. It has the FlutterFire string `code`
(`invalid-credential`, `email-already-in-use`, …) **and** a typed layer so you do not have to
compare strings or invent messages:

```dart
try {
  await auth.signInWithEmailAndPassword(email: email, password: password);
} on FirebaseAuthMultiFactorException catch (e) {
  startSecondFactor(e.resolver);
} on FirebaseAuthException catch (e) {
  if (e.isInvalidCredentials) {
    showFieldError(e.userMessage);      // wrong email/password, whichever code the project returns
  } else if (e.isRetryable) {
    showRetry(e.userMessage);           // offline, timeout, rate limited
  } else if (e.requiresRecentLogin) {
    askToSignInAgain();
  } else if (e.isDeveloperError) {
    log('Auth misconfigured: ${e.code} ${e.message}');   // e.g. provider not enabled
    showError(e.userMessage);
  } else {
    showError(e.userMessage);
  }
}
```

| On the exception | What it gives you |
| --- | --- |
| `e.code` | The FlutterFire string, e.g. `'invalid-credential'` |
| `e.errorCode` | The same as a `FirebaseAuthErrorCode` enum value (autocomplete, exhaustive `switch`) |
| `e.category` | `invalidCredentials`, `accountConflict`, `accountUnavailable`, `validation`, `verificationCode`, `actionCode`, `reauthenticationRequired`, `sessionExpired`, `multiFactor`, `rateLimited`, `network`, `cancelled`, `configuration`, `unknown` |
| `e.userMessage` | A short sentence safe to display ("The email or password is incorrect.") |
| `e.isInvalidCredentials` | Wrong email / password / token, including the old `user-not-found` and `wrong-password` codes |
| `e.isUserInputError` | Bad email format, weak password, wrong SMS code, expired link… fix the form |
| `e.isAccountConflict` | Email already in use, credential already linked, account exists with another provider |
| `e.isNetworkError`, `e.isRateLimited`, `e.isRetryable` | Try again (later) |
| `e.requiresRecentLogin` | Re-authenticate, then retry |
| `e.isSessionExpired` | The saved session is invalid; the user has been signed out |
| `e.isMultiFactorError` | Second factor required or MFA step failed |
| `e.isDeveloperError` | Project / app misconfiguration; nothing the user can fix |
| `e.email`, `e.credential` | Populated for `account-exists-with-different-credential` |

**Common codes and what to do**

| Code | Meaning | Do this |
| --- | --- | --- |
| `invalid-credential` | Wrong email or password (projects with email enumeration protection, the default) | Show "email or password is incorrect" |
| `wrong-password`, `user-not-found` | Same, on older projects and the emulator | Same; `isInvalidCredentials` covers all three |
| `email-already-in-use` | Sign-up with an existing email | Offer "sign in instead" |
| `weak-password` | Fewer than 6 characters (or below your password policy) | Show the rule |
| `invalid-email` | Not an email address | Validate the field |
| `user-disabled` | Disabled in the console | Tell the user to contact support |
| `too-many-requests` | Rate limited | Ask to wait a minute |
| `network-request-failed` | Offline / DNS / timeout | Retry |
| `requires-recent-login` | Sensitive operation with an old session | Re-authenticate, retry |
| `account-exists-with-different-credential` | Same email, other provider | Sign in with the existing provider, then `linkWithCredential(e.credential!)` |
| `credential-already-in-use` | Linking a provider already on another account | Tell the user; offer sign-in with it instead |
| `invalid-verification-code`, `code-expired` | Wrong / old SMS code | Ask again / resend |
| `expired-action-code`, `invalid-action-code` | Old or used email link | Send a new email |
| `second-factor-required` | MFA enrolled | Catch `FirebaseAuthMultiFactorException` |
| `operation-not-allowed` | Provider not enabled in the console | Developer: enable it |
| `invalid-api-key` | Wrong API key in the config | Developer: check the config source |
| `missing-app-credential` | Phone auth without app verification | Developer: see [4.6](#46-phone-number-sign-in) |

**Translate or reword the messages** once, for the whole app:

```dart
FirebaseAuthKit.errorMessages = {
  FirebaseAuthErrorCode.invalidCredential: 'E-mail ou mot de passe incorrect.',
  FirebaseAuthErrorCode.networkRequestFailed: 'Pas de connexion internet.',
};
```

**Catch-all** for any error object (including socket and timeout errors):

```dart
} catch (error) {
  showError(FirebaseAuthKit.describeError(error));
}
```

### 4.12 Custom tokens from your own server

If you already have your own login system, your server can mint a Firebase custom token with the
Admin SDK and the app exchanges it:

```dart
final result = await auth.signInWithCustomToken(tokenFromYourServer);
print(result.user!.uid);   // the uid your server put in the token
final claims = (await result.user!.getIdTokenResult()).claims;   // your custom claims
```

### 4.13 Several Firebase projects in one app

```dart
import 'package:firebase_auth_kit/firebase_core.dart';

final staging = await Firebase.initializeApp(
  name: 'staging',
  options: const FirebaseOptions(
    apiKey: 'AIza…', appId: '1:…', messagingSenderId: '…', projectId: 'my-staging',
  ),
);
final stagingAuth = FirebaseAuth.instanceFor(app: staging);
```

Each app has its own users, streams and saved session. `Firebase.app()` is the default app,
`Firebase.apps` lists them, `app.delete()` disposes one. Use `auth.tenantId = '…'` for
Identity Platform tenants.

### 4.14 Local development with the emulator

```sh
npm install -g firebase-tools
firebase emulators:start --only auth --project demo-my-app
```

Then either

```dart
await auth.useAuthEmulator('localhost', 9099);   // 'localhost' becomes 10.0.2.2 on Android emulators
```

or set `FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099` in the environment, which every new
`FirebaseAuth` picks up. With the emulator configured only a project id is required in the config;
any API key works. Emails and SMS are not sent; read the codes at
`http://127.0.0.1:9099/emulator/v1/projects/demo-my-app/oobCodes` and `…/verificationCodes`.
The emulator accepts unsigned custom tokens and unsigned Google ID tokens, handy for testing
`signInWithCredential` without a real Google account.

### 4.15 Logging and debugging

```dart
FirebaseAuthKit.logger = print;
// [firebase_auth_kit] POST /v1/accounts:signInWithPassword 200
// [firebase_auth_kit] POST /v1/securetoken.googleapis.com/v1/token 200
```

One line per request with method, endpoint and HTTP status. API keys are redacted; tokens,
passwords and request bodies are never logged. Set `FirebaseAuthKit.httpClient` to your own
`package:http` client to add proxies, retries or request tracing.

### 4.16 Testing your own code

In unit tests keep everything in memory and point the kit at an in-process fake server, or at the
emulator:

```dart
setUp(() {
  FirebaseAuthKit.reset();
  FirebaseAuthKit.persistence = InMemoryAuthPersistence();
  FirebaseAuthKit.emulatorHost = 'http://127.0.0.1:9099';   // or your fake server's origin
});
```

`test/helpers/fake_identity_toolkit.dart` in this repository is a 600-line fake of the Firebase
Auth API (accounts, tokens, OOB codes, phone, MFA) you can copy into your project. Alternatively
implement `FirebaseAuthPlatform` and set `FirebaseAuthPlatform.instance` to mock the whole layer.

### 4.17 The web-view screen: OAuth providers and phone auth in production

Two things in Firebase Auth happen on a web page hosted by Firebase at
`https://<project>.firebaseapp.com/__/auth/handler`: signing in with an OAuth provider that has no
native SDK, and the reCAPTCHA check that protects phone sign-in. The native Firebase SDKs open that
page in an in-app browser and catch the redirect back. The kit does the same; it only needs you to
show the page, because a pure-Dart package cannot draw UI. That is one screen, written once:

```dart
import 'package:dartnative/dartnative.dart';
import 'package:dartnative_webview/dartnative_webview.dart';
import 'package:firebase_auth_kit/firebase_auth_kit.dart';

/// Shows a Firebase auth page and completes with the redirect the kit expects.
class AuthWebPage extends StatefulWidget {
  const AuthWebPage({super.key, required this.url, required this.isCallback});
  final Uri url;
  final bool Function(Uri) isCallback;

  @override
  State<AuthWebPage> createState() => _AuthWebPageState();
}

class _AuthWebPageState extends State<AuthWebPage> {
  final controller = WebViewController();
  bool done = false;

  @override
  void initState() {
    super.initState();
    controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    controller.setNavigationDelegate(NavigationDelegate(
      onNavigationRequest: (request) {
        if (_finish(request.url)) return NavigationDecision.prevent;
        return NavigationDecision.navigate;
      },
      // The redirect normally arrives above (dartnative_webview 1.0.1+); page
      // loads are checked too, so the screen also works with web views that
      // only report those.
      onPageStarted: _finish,
      onPageFinished: _finish,
    ));
    controller.loadRequest(widget.url);
  }

  bool _finish(String url) {
    final target = Uri.tryParse(url);
    if (target != null && widget.isCallback(target) && !done) {
      done = true;
      Navigator.of(context).pop(target);           // hand the result back
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: WebViewWidget(controller: controller),
    );
  }
}

/// Register it once, where you have a navigator (a global key works too).
void installAuthWebFlow(BuildContext context) {
  FirebaseAuthKit.webFlowPresenter = (url, {required isCallback}) {
    return Navigator.of(context).push<Uri?>(
      PageRoute(builder: (_) => AuthWebPage(url: url, isCallback: isCallback)),
    );
  };
}
```

After that, `signInWithProvider(GithubAuthProvider())` opens the provider's login inside your app,
and `verifyPhoneNumber` against a production project shows the reCAPTCHA and continues on its own.
If the user closes the screen (the future completes with `null`), the call fails with
`user-cancelled`.

**How it works, for the curious.** The kit builds the same handler URL the iOS Firebase SDK builds
(`authType=signInWithRedirect` or `verifyApp`, your app id, a hashed session id). Firebase finishes
by redirecting to a custom-scheme URL such as `app-1-123-ios-abc://firebaseauth/link?deep_link_id=…`;
the screen intercepts it, the kit parses it, and exchanges the provider response with
`signInWithIdp` (`requestUri` + `sessionId`) or sends the `recaptchaToken` with the SMS request.
Your iOS bundle id / Android package must be registered in the Firebase project, as for any
Firebase app.

**Verified** against the Auth emulator in the test suite and against a production project on the
iOS simulator: Google sign-in through the hosted page completed end to end with the screen above.
The phone reCAPTCHA page is served from inside the app and its completion is a plain http load, so
it does not depend on the web view reporting custom-scheme navigations at all. For the provider
flows use `dartnative_webview` 1.0.1 or newer: it hands the custom-scheme redirect to
`onNavigationRequest` (verified on the iOS simulator). 1.0.0 never did, and the kit then completes
from the handler page load instead, which also works but shows the page a moment longer.

---

## 5. Platform setup

### iOS / macOS

Add `GoogleService-Info.plist` to the app target (Xcode → drag into the Runner target, "Copy items
if needed"). The kit reads `API_KEY`, `GOOGLE_APP_ID`, `GCM_SENDER_ID` and `PROJECT_ID` from it at
runtime. No CocoaPods dependency, no URL scheme, no entitlement needed for this package.
Sign in with Apple and Google Sign-In have their own setup, documented by
`dartnative_social_sign_in`.

### Android

Put `google-services.json` in `android/app/` and apply the Google Services Gradle plugin (two
lines, shown in the [quick start](#step-2--register-your-app-and-download-its-config)). The plugin
compiles the file into the app's resources; the kit reads `project_id`, `google_api_key`,
`google_app_id`, `gcm_defaultSenderId`, `google_storage_bucket` and `firebase_database_url` back
out of the installed APK at start-up. `dartnative_firebase` requires the same plugin, so apps that
use both need nothing extra.

Prefer not to touch Gradle? List the file as an asset instead and the kit finds it inside the APK:

```yaml
dartnative:
  assets:
    - android/app/google-services.json
```

Other options, for CI or unusual setups: `--dart-define=FIREBASE_PROJECT_ID=… FIREBASE_APP_ID=…
FIREBASE_API_KEY=…`, or `Firebase.initializeApp(options: FirebaseOptions(...))` in code.
`localhost` is mapped to `10.0.2.2` by `useAuthEmulator` so the Android emulator reaches your
machine.

### Servers, CLIs, CI

Environment variables (`FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_PROJECT_ID`, or
`GOOGLE_CLOUD_PROJECT` / `FIREBASE_CONFIG` as used by Cloud Functions and Cloud Run), a
`google-services.json` / `GoogleService-Info.plist` in the working directory, or explicit
`FirebaseOptions`.

### Where sessions are stored

`FileAuthPersistence.defaultDirectory()` picks, in order: `$FIREBASE_AUTH_KIT_DIR`; the app
container's `Library/Application Support/firebase_auth_kit` on iOS and macOS;
`/data/user/0/<package>/files/firebase_auth_kit` on Android; `$XDG_DATA_HOME` or
`~/.local/share/firebase_auth_kit` on Linux; `%APPDATA%\firebase_auth_kit` on Windows; otherwise
`.firebase_auth_kit` in the working directory. Override with `FirebaseAuthKit.storageDirectory`.

The file holds the refresh token with mode 0600 inside the sandbox. That matches the Android
Firebase SDK (plain SharedPreferences) but, unlike the iOS SDK's Keychain, it is included in device
backups. Production apps should call `installSecureAuthPersistence(SecureStorage())`
([4.2](#42-stay-signed-in-between-launches)).

---

## 6. Using it with dartnative_firebase and firestore_kit

**dartnative_firebase** boots the native Firebase Core, Crashlytics and Messaging SDKs. Its Dart API
exposes `Firebase.initializeApp()` only; it does not hand `FirebaseApp`, options or the API key to
Dart, so `firebase_auth_kit` reads the same GoogleService config itself. Keep calling their
`initializeApp()` first as usual. The two packages export no clashing names:

```dart
import 'package:dartnative_firebase/dartnative_firebase.dart';
import 'package:firebase_auth_kit/firebase_auth_kit.dart';

void main() async {
  DartNativePluginRegistrant.registerAll();
  await Firebase.initializeApp();        // dartnative_firebase (native SDKs)
  final auth = FirebaseAuth.instance;    // firebase_auth_kit — same project, discovered
  runApp(const MyApp());
}
```

Only when you need this package's `Firebase.initializeApp(options:)` / `FirebaseApp` in a file
that also imports `dartnative_firebase`, import `package:firebase_auth_kit/firebase_core.dart` with
a prefix (`as auth_core`) to keep the two `Firebase` classes apart.

**firestore_kit** needs the ID token for security rules; one line connects them
([4.9](#49-use-the-id-token-with-your-backend-or-firestore)).

---

## 7. API cheat sheet

**`FirebaseAuth`**

| Method | Purpose |
| --- | --- |
| `FirebaseAuth.instance`, `instanceFor(app:)` | Get the auth object |
| `currentUser` | Signed-in `User` or `null` |
| `authStateChanges()`, `idTokenChanges()`, `userChanges()` | Streams of `User?` |
| `authStateReady()` | Completes when the saved session is restored |
| `createUserWithEmailAndPassword(email:, password:)` | Sign up |
| `signInWithEmailAndPassword(email:, password:)` | Sign in |
| `signInAnonymously()` | Guest account |
| `signInWithCredential(credential)` | Google, Apple, phone, email-link, OAuth credentials |
| `signInWithCustomToken(token)` | Token minted by your server |
| `signInWithEmailLink(email:, emailLink:)`, `isSignInWithEmailLink(link)` | Passwordless |
| `signInWithPhoneNumber(number)` → `ConfirmationResult.confirm(code)` | Phone, web-style |
| `verifyPhoneNumber(...)` | Phone with callbacks, also for MFA |
| `signInWithProvider(provider)` | Needs `FirebaseAuthKit.oauthFlowHandler` |
| `signOut()` | Sign out and forget the session |
| `sendPasswordResetEmail(email:)`, `confirmPasswordReset(code:, newPassword:)`, `verifyPasswordResetCode(code)` | Password reset |
| `sendSignInLinkToEmail(email:, actionCodeSettings:)` | Send a magic link |
| `checkActionCode(code)`, `applyActionCode(code)` | Handle links from Firebase emails |
| `setLanguageCode(code)`, `languageCode` | Language of emails and SMS |
| `setSettings(appVerificationDisabledForTesting:, phoneNumber:, smsCode:)` | Phone testing |
| `setPersistence(Persistence.NONE)` | Do not remember the user |
| `useAuthEmulator(host, port)` | Local emulator |
| `tenantId`, `customAuthDomain` | Identity Platform tenants / custom domain |
| `validatePassword(auth, password)` | Check against the project's password policy |
| `revokeTokenWithAuthorizationCode(code)` | Apple token revocation |

**`User`**

| Member | Purpose |
| --- | --- |
| `uid`, `email`, `emailVerified`, `displayName`, `photoURL`, `phoneNumber`, `isAnonymous`, `tenantId` | Profile |
| `metadata.creationTime`, `metadata.lastSignInTime` | Timestamps |
| `providerData` | Linked providers (`UserInfo` each) |
| `getIdToken([forceRefresh])`, `getIdTokenResult([forceRefresh])` | Token / decoded claims |
| `updateProfile(displayName:, photoURL:)`, `updateDisplayName`, `updatePhotoURL` | Profile |
| `updatePassword(new)`, `verifyBeforeUpdateEmail(new)`, `updatePhoneNumber(credential)` | Credentials |
| `sendEmailVerification()` | Verification mail |
| `linkWithCredential`, `unlink(providerId)`, `linkWithPhoneNumber`, `linkWithProvider` | Providers |
| `reauthenticateWithCredential`, `reauthenticateWithProvider` | Before sensitive operations |
| `reload()`, `delete()` | Refresh / remove the account |
| `multiFactor` | `getSession`, `enroll`, `unenroll`, `getEnrolledFactors` |

**Providers and credentials**

`EmailAuthProvider.credential(email:, password:)`, `EmailAuthProvider.credentialWithLink(email:,
emailLink:)`, `PhoneAuthProvider.credential(verificationId:, smsCode:)`,
`GoogleAuthProvider.credential(idToken:, accessToken:)`, `AppleAuthProvider.credential(token)` /
`credentialWithIDToken(idToken, rawNonce, fullName)`, `FacebookAuthProvider.credential(token)`,
`GithubAuthProvider.credential(token)`, `TwitterAuthProvider.credential(accessToken:, secret:)`,
`OAuthProvider(id).credential(idToken:, accessToken:, rawNonce:)`; `MicrosoftAuthProvider`,
`YahooAuthProvider`, `SAMLAuthProvider`, `GameCenterAuthProvider`, `PlayGamesAuthProvider` for
`signInWithProvider` where applicable.

**Multi-factor**

`TotpMultiFactorGenerator.generateSecret(session)`, `.getAssertionForEnrollment(secret, code)`,
`.getAssertionForSignIn(enrollmentId, code)`; `PhoneMultiFactorGenerator.getAssertion(credential)`;
`MultiFactorResolver.hints`, `.session`, `.resolveSignIn(assertion)`; `TotpSecret.generateQrCodeUrl`,
`.openInOtpApp` (needs `FirebaseAuthKit.urlLauncher`).

**Errors**

`FirebaseAuthException` (`code`, `message`, `email`, `credential`, `errorCode`, `category`,
`userMessage`, predicates), `FirebaseAuthMultiFactorException` (`resolver`),
`FirebaseAuthErrorCode`, `FirebaseAuthErrorCategory`, `describeAuthError(error)`.

---

## 8. Configuration reference

**Where the project configuration comes from** (first match wins):

| Source | Keys |
| --- | --- |
| `--dart-define` | `FIREBASE_PROJECT_ID` (required), `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_STORAGE_BUCKET`, `FIREBASE_DATABASE_URL` |
| Environment variables | the same names, plus `GOOGLE_CLOUD_PROJECT`, `GCLOUD_PROJECT`, `FIREBASE_CONFIG` (JSON) |
| Files | `GoogleService-Info.plist` next to the executable or in `Resources/`; `google-services.json` / `GoogleService-Info.plist` in the working directory or the usual `ios/Runner`, `android/app` paths |
| Android APK | the `google_*` string resources compiled by the Google Services Gradle plugin, or a `google-services.json` bundled as an asset |
| Bundled assets | `GoogleService-Info.plist` / `google-services.json` listed under `dartnative: assets:` (found in the iOS bundle's `flutter_assets`) |
| Code | `Firebase.initializeApp(options: FirebaseOptions(...))` from `package:firebase_auth_kit/firebase_core.dart` |

The API key is required against production. With `FIREBASE_AUTH_EMULATOR_HOST` set, a project id
alone is enough.

**`FirebaseAuthKit` settings** (set before the first `FirebaseAuth` use):

| Setting | Default | Purpose |
| --- | --- | --- |
| `persistence` | `FileAuthPersistence` | Where sessions are stored; see `installSecureAuthPersistence` |
| `storageDirectory` | platform app-support dir | Directory for the default file store |
| `httpClient` | shared `http.Client` | Your own client for proxies / retries |
| `logger` | `null` | One redacted line per request |
| `emulatorHost` | `$FIREBASE_AUTH_EMULATOR_HOST` | `host:port` of the Auth emulator |
| `webFlowPresenter` | `null` | Shows Firebase's hosted pages; enables `signInWithProvider` and production phone auth ([4.17](#417-the-web-view-screen-oauth-providers-and-phone-auth-in-production)) |
| `recaptchaTokenProvider` | `null` | Your own reCAPTCHA token source, instead of the hosted page |
| `oauthFlowHandler` | `null` | Your own OAuth implementation, instead of the hosted page |
| `urlLauncher` | `null` | Opens URLs for `TotpSecret.openInOtpApp` |
| `errorMessages` | `{}` | Overrides for `userMessage` |
| `tokenRefreshThreshold` | 30 s | Refresh ID tokens this long before expiry |
| `reset()` | | Back to defaults (tests) |

**Environment variables honoured at runtime:** `FIREBASE_AUTH_EMULATOR_HOST`,
`FIREBASE_AUTH_KIT_DIR`, and the configuration keys above.

---

## 9. Troubleshooting

**`[core/no-options] The [DEFAULT] app cannot be initialized: no Firebase configuration was found`**
The kit could not find any configuration. On Android check that `google-services.json` is in
`android/app/` **and** the Google Services Gradle plugin is applied (or list the file as an asset);
on iOS make sure the plist is in the app target (Build Phases → Copy Bundle Resources); on a server
set the environment variables or call `Firebase.initializeApp(options:)`.

**`[firebase_auth/invalid-api-key]`** The API key does not belong to the project, or you are using
the placeholder key against production. Copy the *Web API key* from Project settings.

**`[firebase_auth/operation-not-allowed]`** The sign-in method is not enabled: console →
Authentication → Sign-in method.

**`[firebase_auth/network-request-failed]` on the Android emulator with `useAuthEmulator`**
Use `localhost` (the kit maps it to `10.0.2.2`) or the LAN IP of your machine, and make sure the
emulator was started with `"host": "0.0.0.0"` or `127.0.0.1` as needed.

**`[firebase_auth/missing-app-credential]` when sending an SMS** Phone auth needs app verification;
see [4.6](#46-phone-number-sign-in). In production add the web-view screen from
[4.17](#417-the-web-view-screen-oauth-providers-and-phone-auth-in-production); during development
use the emulator or test phone numbers with `setSettings(appVerificationDisabledForTesting: true)`.

**`currentUser` is `null` right after startup although the user signed in last time** You are
using an asynchronous store (secure storage or your own). Await
`installSecureAuthPersistence(...)` or `FirebaseAuth.instance.authStateReady()` before reading it.

**`[firebase_auth/unverified-email]` when enrolling a second factor** Firebase requires a verified
email first: `sendEmailVerification()`, then `reload()`.

**The name `Firebase` is ambiguous** You imported both `dartnative_firebase` and
`package:firebase_auth_kit/firebase_core.dart` in one file. Prefix the latter:
`import 'package:firebase_auth_kit/firebase_core.dart' as auth_core;`.

**Wrong password gives `invalid-credential` on production but `wrong-password` on the emulator**
Expected: production projects hide whether the email exists. Use `e.isInvalidCredentials`, which
covers both.

**`signInWithProvider` throws `operation-not-supported-in-this-environment`** Add the web-view
screen from [4.17](#417-the-web-view-screen-oauth-providers-and-phone-auth-in-production), or use
`signInWithCredential` with a token obtained natively.

**The hosted page shows "App not found" or an unauthorized-domain error** The bundle id / package
name and app id the kit sends come from your `GoogleService-Info.plist` / `google-services.json`;
make sure that app is registered in the Firebase project and that `<project>.firebaseapp.com` is in
*Authorized domains*.

**I want to see what is sent** `FirebaseAuthKit.logger = print;` — endpoints and statuses only,
credentials are redacted.

---

## 10. What is not supported

- `signInWithPopup`, `signInWithRedirect`, `getRedirectResult`: web only; they throw
  `UnimplementedError`, exactly as FlutterFire does on mobile.
- `signInWithProvider` / `linkWithProvider` / `reauthenticateWithProvider` and production phone
  auth without the web-view screen from [4.17](#417-the-web-view-screen-oauth-providers-and-phone-auth-in-production)
  (a pure-Dart package cannot show a web page by itself).
- `GameCenterAuthProvider` and `PlayGamesAuthProvider` credentials (verified by the native SDKs).
- Silent phone app verification via APNs / Play Integrity (the hosted reCAPTCHA page is used
  instead, as the iOS SDK does when APNs is unavailable), and SMS auto-retrieval on Android
  (`verificationCompleted` fires only for test numbers configured with `setSettings`).
- `setSettings(userAccessGroup:)` Keychain sharing between apps.
- TOTP multi-factor is verified against the in-process fake only; the Firebase Auth emulator
  (firebase-tools 14.26) rejects TOTP enrolment, and it was not tested against a production
  Identity Platform project.

---

## 11. Migrating from FlutterFire

1. In `pubspec.yaml` replace `firebase_auth` (and `firebase_core`, if Auth was its only consumer)
   with `firebase_auth_kit`.
2. Replace `import 'package:firebase_auth/firebase_auth.dart';` with
   `import 'package:firebase_auth_kit/firebase_auth_kit.dart';`.
3. Where you imported `firebase_core` for `Firebase.initializeApp(options:)`, import
   `package:firebase_auth_kit/firebase_core.dart` instead, or delete the call and let
   `FirebaseAuth.instance` discover the configuration.
4. `signInWithProvider(...)` → `signInWithCredential(...)` with a token from
   `dartnative_social_sign_in`, or set `FirebaseAuthKit.oauthFlowHandler`.
5. Phone auth in production: provide `FirebaseAuthKit.recaptchaTokenProvider` or use test numbers.
6. Optional: replace your string `switch (e.code)` blocks with `e.errorCode` / the predicates.

`currentUser`, the streams, `UserCredential`, providers, error codes and `MultiFactor` are the same
API.

---

## 12. Example, tests, license

**Demo app.** [github.com/edkluivert/firebase_auth_kit_demo](https://github.com/edkluivert/firebase_auth_kit_demo)
is a complete DartNative app that runs `firebase_auth_kit`, `firestore_kit` and `dartnative_firebase`
together against a real Firebase project: email/password, anonymous, Google through the hosted
page, phone with a test number, Firestore with rules, Crashlytics, and the web-view screen from
[4.17](#417-the-web-view-screen-oauth-providers-and-phone-auth-in-production). Every step is
logged, so it doubles as a checklist for your own setup.

**Example.** `example/main.dart` signs up, updates the profile, inspects the ID token, handles a
wrong password and starts a phone verification against the emulator:

```sh
firebase emulators:start --only auth --project demo-firebase-auth-kit
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 dart run example/main.dart
```

**Tests.**

```sh
dart test                                    # unit tests against an in-process fake of the API
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 dart test --tags live   # against the emulator
```

The live suite covers email/password, anonymous + link, action codes (password reset, email
verification, email link), phone sign-in, Google IdP credentials, custom tokens and phone
second-factor enrolment / sign-in.

**Credits and license.** MIT. The public API layer is copied from FlutterFire's `firebase_auth`,
`firebase_auth_platform_interface` and `firebase_core` (BSD-3-Clause, see `NOTICES`); the REST
implementation is original. Not affiliated with or endorsed by Google.

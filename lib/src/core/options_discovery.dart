part of 'firebase_core.dart';


/// Maps `localhost` to the address the Android emulator uses for the host
/// machine, so `useAuthEmulator('localhost', 9099)` works from an emulator.
String getMappedHost(String host) {
  if (Platform.isAndroid && (host == 'localhost' || host == '127.0.0.1')) {
    return '10.0.2.2';
  }
  return host;
}

import 'dart:convert';

/// Decodes the payload (claims) of a JWT without verifying its signature.
///
/// Firebase ID tokens are verified by the backend on every request; the client
/// only needs the claims to populate `IdTokenResult` and to know when the
/// token expires. Returns `null` when [token] is not a three-part JWT with a
/// JSON payload.
Map<String, Object?>? decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final normalized = base64Url.normalize(parts[1]);
    final decoded = jsonDecode(utf8.decode(base64Url.decode(normalized)));
    if (decoded is Map) return Map<String, Object?>.from(decoded);
  } on FormatException {
    return null;
  }
  return null;
}

/// The `exp` claim of [token] as a UTC [DateTime], or `null`.
DateTime? jwtExpiration(String token) {
  final exp = decodeJwtPayload(token)?['exp'];
  if (exp is num) {
    return DateTime.fromMillisecondsSinceEpoch((exp * 1000).round(),
        isUtc: true);
  }
  return null;
}

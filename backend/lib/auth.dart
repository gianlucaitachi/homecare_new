import 'package:bcrypt/bcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

String hashPassword(String password) {
  return BCrypt.hashpw(password, BCrypt.gensalt());
}

bool verifyPassword(String password, String passwordHash) {
  return BCrypt.checkpw(password, passwordHash);
}

String generateToken(
  Map<String, dynamic> payload,
  String secret, {
  Duration expiresIn = const Duration(hours: 1),
}) {
  final jwt = JWT(payload);
  return jwt.sign(SecretKey(secret), expiresIn: expiresIn);
}

Map<String, dynamic> verifyToken(String token, String secret) {
  try {
    final jwt = JWT.verify(token, SecretKey(secret));
    final payload = jwt.payload;
    if (payload is Map<String, dynamic>) {
      return Map<String, dynamic>.from(payload);
    }
    throw JwtException.invalidToken;
  } on JwtException {
    rethrow;
  } catch (_) {
    throw JwtException.invalidToken;
  }
}

class JwtException {
  static var invalidToken;
}

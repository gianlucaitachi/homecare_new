import 'package:backend/auth.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:test/test.dart';

void main() {
  group('Password hashing', () {
    test('hashPassword produces a verifiable hash', () {
      const password = 'super-secret';

      final hash = hashPassword(password);

      expect(hash, isNot(equals(password)));
      expect(verifyPassword(password, hash), isTrue);
    });

    test('verifyPassword fails for incorrect password', () {
      const password = 'correct-horse';
      const wrongPassword = 'battery-staple';

      final hash = hashPassword(password);

      expect(verifyPassword(wrongPassword, hash), isFalse);
    });
  });

  group('JWT utilities', () {
    test('generateToken encodes payload and verifyToken decodes it', () {
      const secret = 'test-secret';
      final token = generateToken({'sub': '123', 'email': 'test@example.com'}, secret);

      final payload = verifyToken(token, secret);

      expect(payload['sub'], equals('123'));
      expect(payload['email'], equals('test@example.com'));
    });

    test('verifyToken throws for invalid signature', () {
      const secret = 'test-secret';
      final token = generateToken({'sub': '123'}, secret);

      expect(() => verifyToken(token, 'other-secret'), throwsA(isA<JWTError>()));
    });
  });
}

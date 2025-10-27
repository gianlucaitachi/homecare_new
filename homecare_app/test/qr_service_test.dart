import 'package:flutter_test/flutter_test.dart';

import 'package:homecare_app/Services/qr_service.dart';

void main() {
  const service = QrService();

  group('QrService.parse', () {
    test('parses payload with taskId and verificationCode', () {
      const qrData = '{"data":"uuid","matrix":[[1,0],[0,1]]}';
      const raw = '{"taskId":"task-123","verificationCode":"$qrData"}';

      final payload = service.parse(raw);

      expect(payload.taskId, 'task-123');
      expect(payload.verificationCode, qrData);
    });

    test('parses payload nested under task key', () {
      const raw = '{"task":{"id":"abc","code":"verification"}}';

      final payload = service.parse(raw);

      expect(payload.taskId, 'abc');
      expect(payload.verificationCode, 'verification');
    });

    test('throws when payload is empty', () {
      expect(
        () => service.parse('  '),
        throwsA(
          isA<FormatException>()
              .having((e) => e.message, 'message', 'QR payload is empty.'),
        ),
      );
    });

    test('throws when payload is not valid json', () {
      expect(
        () => service.parse('not-json'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'QR payload is not valid JSON.',
          ),
        ),
      );
    });

    test('throws when payload is not an object', () {
      expect(
        () => service.parse('[]'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'QR payload must decode to an object.',
          ),
        ),
      );
    });

    test('throws when task id is missing', () {
      const raw = '{"verificationCode":"code-only"}';

      expect(
        () => service.parse(raw),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'QR payload is missing a task id.',
          ),
        ),
      );
    });

    test('throws when verification code is missing', () {
      const raw = '{"taskId":"task-only"}';

      expect(
        () => service.parse(raw),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'QR payload is missing a verification code.',
          ),
        ),
      );
    });

    test('throws when fields are blank', () {
      const raw = '{"taskId":"  ","verificationCode":""}';

      expect(
        () => service.parse(raw),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'QR payload is missing a task id.',
          ),
        ),
      );
    });
  });
}

import 'dart:convert';

class QrPayload {
  const QrPayload({required this.taskId, required this.verificationCode});

  final String taskId;
  final String verificationCode;

  String get qrCode => verificationCode;
}

class QrService {
  const QrService();

  QrPayload parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('QR payload is empty.');
    }

    Map<String, dynamic> decoded;
    try {
      final dynamic value = jsonDecode(trimmed);
      if (value is Map<String, dynamic>) {
        decoded = value;
      } else if (value is Map) {
        decoded = Map<String, dynamic>.from(value);
      } else {
        throw const FormatException('QR payload must decode to an object.');
      }
    } on FormatException catch (error) {
      if (error.message == 'QR payload must decode to an object.') {
        rethrow;
      }
      throw const FormatException('QR payload is not valid JSON.');
    } catch (_) {
      throw const FormatException('QR payload is not valid JSON.');
    }

    final candidates = <Map<String, dynamic>>[decoded];
    final taskNode = decoded['task'];
    if (taskNode is Map<String, dynamic>) {
      candidates.insert(0, taskNode);
    } else if (taskNode is Map) {
      candidates.insert(0, Map<String, dynamic>.from(taskNode));
    }

    String? taskId;
    String? verificationCode;

    for (final candidate in candidates) {
      taskId ??= _stringValue(candidate, 'taskId');
      taskId ??= _stringValue(candidate, 'id');
      verificationCode ??= _stringValue(candidate, 'verificationCode');
      verificationCode ??= _stringValue(candidate, 'code');
      if (taskId != null && verificationCode != null) {
        break;
      }
    }

    if (taskId == null) {
      throw const FormatException('QR payload is missing a task id.');
    }
    if (verificationCode == null) {
      throw const FormatException('QR payload is missing a verification code.');
    }

    return QrPayload(taskId: taskId, verificationCode: verificationCode);
  }

  String? _stringValue(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }
}

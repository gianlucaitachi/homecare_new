import 'dart:convert';

class QrPayload {
  const QrPayload({required this.taskId, required this.qrCode});

  final String taskId;
  final String qrCode;
}

class QrService {
  const QrService();

  QrPayload? parse(String? rawValue) {
    if (rawValue == null) {
      return null;
    }

    final normalized = rawValue.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final jsonPayload = _tryDecodeJson(normalized);
    if (jsonPayload != null) {
      final taskId = _readString(jsonPayload, const ['taskId', 'task_id', 'id']);
      final qrCode = _readString(
        jsonPayload,
        const ['qrCode', 'qr_code', 'qr', 'code', 'data'],
        allowJsonEncoding: true,
      );

      if (taskId != null && qrCode != null) {
        return QrPayload(taskId: taskId, qrCode: qrCode);
      }

      if (jsonPayload['task'] is Map) {
        final nested = Map<String, dynamic>.from(jsonPayload['task'] as Map);
        final nestedTaskId =
            _readString(nested, const ['taskId', 'task_id', 'id']);
        final nestedQrCode = qrCode ??
            _readString(
              nested,
              const ['qrCode', 'qr_code', 'qr', 'code', 'data'],
              allowJsonEncoding: true,
            );
        if (nestedTaskId != null && nestedQrCode != null) {
          return QrPayload(taskId: nestedTaskId, qrCode: nestedQrCode);
        }
      }

      if (jsonPayload['payload'] is Map) {
        final nested = Map<String, dynamic>.from(jsonPayload['payload'] as Map);
        final nestedTaskId =
            _readString(nested, const ['taskId', 'task_id', 'id']);
        final nestedQrCode = qrCode ??
            _readString(
              nested,
              const ['qrCode', 'qr_code', 'qr', 'code', 'data'],
              allowJsonEncoding: true,
            );
        if (nestedTaskId != null && nestedQrCode != null) {
          return QrPayload(taskId: nestedTaskId, qrCode: nestedQrCode);
        }
      }
    }

    final fallback = _parseDelimited(normalized);
    if (fallback != null) {
      return fallback;
    }

    return null;
  }

  Map<String, dynamic>? _tryDecodeJson(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded as Map);
      }
      if (decoded is String) {
        return _tryDecodeJson(decoded);
      }
    } catch (_) {}
    return null;
  }

  QrPayload? _parseDelimited(String value) {
    final parts = value.split(RegExp(r'[|;,]'));
    if (parts.length < 2) {
      return null;
    }

    final taskId = parts[0].trim();
    final qrCode = parts[1].trim();
    if (taskId.isEmpty || qrCode.isEmpty) {
      return null;
    }

    return QrPayload(taskId: taskId, qrCode: qrCode);
  }

  String? _readString(
    Map<String, dynamic> map,
    List<String> keys, {
    bool allowJsonEncoding = false,
  }) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (allowJsonEncoding && (value is Map || value is Iterable)) {
        final encoded = jsonEncode(value);
        if (encoded.isNotEmpty) {
          return encoded;
        }
      }
    }
    return null;
  }
}

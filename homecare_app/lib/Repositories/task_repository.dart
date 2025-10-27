import 'package:dio/dio.dart';

import '../Services/auth_service.dart';

class TaskException implements Exception {
  const TaskException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TaskRepository {
  TaskRepository({AuthService? authService})
      : _authService = authService ?? AuthService();

  final AuthService _authService;

  Future<Map<String, dynamic>> completeByQr({
    required String taskId,
    required String qrCode,
  }) async {
    try {
      final response = await _authService.post<dynamic>(
        '/api/tasks/$taskId/complete-qr',
        data: {'qr_code': qrCode},
      );

      final body = response.data;
      if (body is! Map) {
        throw const FormatException('Invalid response payload.');
      }

      final json = Map<String, dynamic>.from(body as Map);
      final task = json['task'];
      if (task is! Map) {
        throw const FormatException('Invalid task payload.');
      }

      return Map<String, dynamic>.from(task as Map);
    } on DioException catch (error) {
      throw TaskException(_errorMessageFromDio(error));
    } on FormatException {
      throw const TaskException('Unexpected response from the server.');
    } catch (_) {
      throw const TaskException('Failed to complete task. Please try again.');
    }
  }

  String _errorMessageFromDio(DioException error) {
    final response = error.response;
    if (response?.data is Map) {
      final map = Map<String, dynamic>.from(response!.data as Map);
      final message = map['error'] ?? map['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Connection timed out. Please check your network and retry.';
    }

    return 'Failed to complete task. Please try again.';
  }
}

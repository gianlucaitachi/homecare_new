import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../env.dart';

class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final Map<String, dynamic> user;
}

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository({required Dio dio, required SharedPreferences preferences})
      : _dio = dio,
        _preferences = preferences;

  static const _tokenKey = 'auth_token';

  final Dio _dio;
  final SharedPreferences _preferences;

  Future<AuthResult> login(String email, String password) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      final data = response.data ?? <String, dynamic>{};
      final token = data['token'];
      if (token is! String || token.isEmpty) {
        throw AuthException('Invalid response from server.');
      }
      await _preferences.setString(_tokenKey, token);

      final user = data['user'];
      return AuthResult(
        token: token,
        user: user is Map<String, dynamic>
            ? Map<String, dynamic>.from(user)
            : <String, dynamic>{},
      );
    } on DioException catch (error) {
      final message = _errorMessageFromDio(error);
      throw AuthException(message);
    } catch (_) {
      throw AuthException('Unexpected error, please try again.');
    }
  }

  String? getStoredToken() => _preferences.getString(_tokenKey);

  Future<void> clearToken() => _preferences.remove(_tokenKey);

  String _errorMessageFromDio(DioException error) {
    if (error.response?.data is Map<String, dynamic>) {
      final data = error.response!.data as Map<String, dynamic>;
      final message = data['error'] ?? data['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Connection timed out. Please check your internet connection.';
    }
    return 'Failed to login. Please try again.';
  }
}

Dio createDio() {
  return Dio(
    BaseOptions(
      baseUrl: Env.backendBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );
}

Future<AuthRepository> createAuthRepository() async {
  final dio = createDio();
  final preferences = await SharedPreferences.getInstance();
  return AuthRepository(dio: dio, preferences: preferences);
}

import 'package:dio/dio.dart';

import '../Models/auth_response.dart';
import '../Services/auth_service.dart';
import '../Services/token_storage.dart';

class AuthRepository {
  AuthRepository({AuthService? authService, TokenStorage? tokenStorage})
      : _authService = authService ?? AuthService(),
        _tokenStorage = tokenStorage ?? TokenStorage.instance;

  final AuthService _authService;
  final TokenStorage _tokenStorage;

  Future<AuthResponse> register(Map<String, dynamic> payload) {
    return _authenticate('/api/auth/register', payload);
  }

  Future<AuthResponse> login(Map<String, dynamic> payload) {
    return _authenticate('/api/auth/login', payload);
  }

  Future<AuthResponse> _authenticate(String path, Map<String, dynamic> payload) async {
    late Response response;
    try {
      response = await _authService.post<dynamic>(path, data: payload);
    } on DioException catch (error) {
      if (error.response != null) {
        throw error;
      }
      rethrow;
    }

    final body = response.data;
    if (body is! Map) {
      throw const FormatException('Invalid authentication response payload');
    }

    final json = Map<String, dynamic>.from(body as Map);
    final authResponse = AuthResponse.fromJson(json);
    await _tokenStorage.saveToken(authResponse.token);
    return authResponse;
  }
}

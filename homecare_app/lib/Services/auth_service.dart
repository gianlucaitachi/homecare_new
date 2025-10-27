import 'package:dio/dio.dart';

import '../env.dart';
import 'token_storage.dart';

class AuthService {
  factory AuthService({TokenStorage? tokenStorage}) {
    return _instance ??= AuthService._internal(tokenStorage ?? TokenStorage.instance);
  }

  AuthService._internal(this._tokenStorage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: Env.backendBaseUrl,
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_shouldAttachToken(options)) {
            final token = await _tokenStorage.getToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            } else {
              options.headers.remove('Authorization');
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final statusCode = error.response?.statusCode;
          if (statusCode == 401) {
            await _tokenStorage.clearToken();
          }
          handler.next(error);
        },
      ),
    );
  }

  static AuthService? _instance;

  late final Dio _dio;
  final TokenStorage _tokenStorage;

  Dio get client => _dio;

  bool _shouldAttachToken(RequestOptions options) {
    final path = options.path;
    if (path.startsWith('/api/')) {
      return true;
    }
    final uriPath = options.uri.path;
    return uriPath.startsWith('/api/');
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }
}

import 'dart:io';

import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:postgres/postgres.dart';

PostgreSQLConnection? _connection;

Future<PostgreSQLConnection> pg() async {
  if (_connection != null && !_connection!.isClosed) {
    return _connection!;
  }

  _loadEnvIfNeeded();
  final databaseUrl = _resolveDatabaseUrl();
  if (databaseUrl == null || databaseUrl.isEmpty) {
    throw StateError('DATABASE_URL is not configured.');
  }

  final _DatabaseConfig config = _DatabaseConfig.fromUrl(databaseUrl);
  final connection = PostgreSQLConnection(
    config.host,
    config.port,
    config.database,
    username: config.username,
    password: config.password,
    useSSL: config.useSSL,
  );

  await connection.open();
  _connection = connection;
  return connection;
}

Future<void> closePg() async {
  if (_connection != null) {
    final conn = _connection!;
    _connection = null;
    if (!conn.isClosed) {
      await conn.close();
    }
  }
}

void _loadEnvIfNeeded() {
  try {
    if (!dotenv.isInitialized) {
      dotenv.load();
    }
  } on FileSystemException {
    // Ignore missing .env file; rely on process environment instead.
  }
}

String? _resolveDatabaseUrl() {
  final fromEnv = Platform.environment['DATABASE_URL'];
  if (fromEnv != null && fromEnv.isNotEmpty) {
    return fromEnv;
  }
  return dotenv.isInitialized ? dotenv.env['DATABASE_URL'] : null;
}

class _DatabaseConfig {
  _DatabaseConfig({
    required this.host,
    required this.port,
    required this.database,
    this.username,
    this.password,
    required this.useSSL,
  });

  factory _DatabaseConfig.fromUrl(String url) {
    final uri = Uri.parse(url);
    if (uri.scheme != 'postgres' && uri.scheme != 'postgresql') {
      throw ArgumentError.value(url, 'url', 'Unsupported database URL scheme.');
    }

    final userInfo = uri.userInfo.split(':');
    final username = userInfo.isNotEmpty && userInfo.first.isNotEmpty
        ? Uri.decodeComponent(userInfo.first)
        : null;
    final password = userInfo.length > 1 && userInfo[1].isNotEmpty
        ? Uri.decodeComponent(userInfo[1])
        : null;

    final database = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : uri.path.replaceFirst('/', '');
    final port = uri.hasPort ? uri.port : 5432;

    final sslMode = uri.queryParameters['sslmode']?.toLowerCase();
    final useSSL = sslMode == 'require' || sslMode == 'verify-ca' || sslMode == 'verify-full';

    return _DatabaseConfig(
      host: uri.host,
      port: port,
      database: database,
      username: username,
      password: password,
      useSSL: useSSL,
    );
  }

  final String host;
  final int port;
  final String database;
  final String? username;
  final String? password;
  final bool useSSL;
}

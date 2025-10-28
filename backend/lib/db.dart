import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:postgres/postgres.dart';

Connection? _connection;

Future<Connection> pg() async {
  if (_connection != null && _connection!.isOpen) {
    return _connection!;
  }

  final env = DotEnv(includePlatformEnvironment: true)..load();
  final databaseUrl = env['DATABASE_URL'];

  if (databaseUrl == null || databaseUrl.isEmpty) {
    throw StateError('DATABASE_URL is not configured.');
  }

  final uri = Uri.parse(databaseUrl);
  final endpoint = Endpoint(
    host: uri.host,
    port: uri.port,
    database: uri.pathSegments.first,
    username: uri.userInfo.split(':').first,
    password: uri.userInfo.split(':').last,
  );

  final connection = await Connection.open(
    endpoint,
    settings: ConnectionSettings(
      sslMode: uri.queryParameters['sslmode'] == 'require'
          ? SslMode.require
          : SslMode.disable,
    ),
  );

  _connection = connection;
  return connection;
}

Future<void> closePg() async {
  if (_connection != null) {
    await _connection!.close();
    _connection = null;
  }
}

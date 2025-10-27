import 'dart:convert';
import 'dart:io';

import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

Future<void> main(List<String> arguments) async {
  _loadEnvironment();

  final port = _resolvePort();
  final router = Router()
    ..get('/health', _healthHandler);

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler(router);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('Server listening on port ${server.port}');
}

Response _healthHandler(Request request) {
  final body = jsonEncode({'status': 'ok'});
  return Response.ok(body, headers: {
    HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
  });
}

void _loadEnvironment() {
  try {
    dotenv.load();
  } on FileSystemException {
    // Ignore missing .env files so the server can still start with defaults.
  }
}

int _resolvePort() {
  final fromPlatform = Platform.environment['PORT'];
  final fromDotEnv = dotenv.env['PORT'];
  final portString = fromPlatform ?? fromDotEnv ?? '8080';
  final parsed = int.tryParse(portString);
  if (parsed == null) {
    stderr.writeln(
      'Invalid PORT "$portString". Falling back to default 8080.',
    );
    return 8080;
  }
  return parsed;
}

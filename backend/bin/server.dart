import 'dart:convert';
import 'dart:io';

import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

Future<void> main(List<String> arguments) async {
  dotenv.load();

  final envPort = dotenv.env['PORT'] ?? Platform.environment['PORT'];
  final port = int.tryParse(envPort ?? '') ?? 8080;

  final router = Router()
    ..get('/health', (Request request) {
      final body = jsonEncode({'status': 'ok'});
      return Response.ok(
        body,
        headers: {
          HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
        },
      );
    });

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler(router);

  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  print('Server listening on port ${server.port}');
}

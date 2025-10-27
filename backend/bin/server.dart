import 'dart:convert';
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import 'package:backend/auth.dart';

final _uuid = Uuid();

Future<void> main(List<String> args) async {
  final jwtSecret = Platform.environment['JWT_SECRET'];
  if (jwtSecret == null || jwtSecret.isEmpty) {
    stderr.writeln('JWT_SECRET environment variable is required.');
    exit(1);
  }

  await _ensureUserStore();

  final router = Router()
    ..post('/api/auth/register', (Request request) async {
      Map<String, dynamic> payload;
      try {
        payload = await _parseJson(request);
      } on FormatException {
        return _jsonResponse(400, {'error': 'Invalid JSON payload.'});
      }
      final email = _parseString(payload['email']).toLowerCase();
      final password = _parseString(payload['password']);
      final name = _parseOptionalString(payload['name']);

      if (email.isEmpty || password.isEmpty) {
        return _jsonResponse(
          400,
          {'error': 'Email and password are required.'},
        );
      }

      final users = await _readUsers();
      if (users.any((user) => user['email'] == email)) {
        return _jsonResponse(409, {'error': 'User already exists.'});
      }

      final hashed = hashPassword(password);
      final now = DateTime.now().toUtc().toIso8601String();
      final user = {
        'id': _uuid.v4(),
        'email': email,
        'name': name,
        'passwordHash': hashed,
        'createdAt': now,
      };
      users.add(user);
      await _writeUsers(users);

      final token = generateToken({'sub': user['id'], 'email': email}, jwtSecret);
      return _jsonResponse(201, {
        'token': token,
        'user': _publicUser(user),
      });
    })
    ..post('/api/auth/login', (Request request) async {
      Map<String, dynamic> payload;
      try {
        payload = await _parseJson(request);
      } on FormatException {
        return _jsonResponse(400, {'error': 'Invalid JSON payload.'});
      }
      final email = _parseString(payload['email']).toLowerCase();
      final password = _parseString(payload['password']);

      if (email.isEmpty || password.isEmpty) {
        return _jsonResponse(
          400,
          {'error': 'Email and password are required.'},
        );
      }

      final users = await _readUsers();
      Map<String, dynamic>? user;
      for (final candidate in users) {
        if (candidate['email'] == email) {
          user = candidate;
          break;
        }
      }
      if (user == null) {
        return _jsonResponse(401, {'error': 'Invalid credentials.'});
      }

      if (!verifyPassword(password, user['passwordHash'] as String)) {
        return _jsonResponse(401, {'error': 'Invalid credentials.'});
      }

      final token = generateToken({'sub': user['id'], 'email': email}, jwtSecret);
      return _jsonResponse(200, {
        'token': token,
        'user': _publicUser(user),
      });
    })
    ..get('/api/protected', (Request request) async {
      final user = request.context['user'] as Map<String, dynamic>?;
      return _jsonResponse(200, {
        'message': 'Protected resource accessed.',
        'user': user,
      });
    });

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_authGuard(jwtSecret))
      .addHandler(router);

  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('Server listening on port ${server.port}');
}

Middleware _authGuard(String jwtSecret) {
  return (Handler innerHandler) {
    return (Request request) async {
      final path = request.requestedUri.path;
      final isApiRoute = path.startsWith('/api/');
      final isAuthRoute = path.startsWith('/api/auth/');

      if (isApiRoute && !isAuthRoute) {
        final authHeader = request.headers['Authorization'];
        if (authHeader == null || !authHeader.startsWith('Bearer ')) {
          return _jsonResponse(401, {'error': 'Missing or invalid Authorization header.'});
        }

        final token = authHeader.substring('Bearer '.length).trim();
        try {
          final payload = verifyToken(token, jwtSecret);
          final updatedRequest = request.change(context: {
            ...request.context,
            'user': payload,
          });
          return await innerHandler(updatedRequest);
        } on JWTError {
          return _jsonResponse(401, {'error': 'Invalid or expired token.'});
        } catch (_) {
          return _jsonResponse(500, {'error': 'Failed to validate token.'});
        }
      }

      return innerHandler(request);
    };
  };
}

Future<Map<String, dynamic>> _parseJson(Request request) async {
  final body = await request.readAsString();
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
  } catch (_) {}
  throw const FormatException('Invalid JSON payload.');
}

String _parseString(Object? value) {
  return value is String ? value.trim() : '';
}

String? _parseOptionalString(Object? value) {
  final parsed = _parseString(value);
  return parsed.isEmpty ? null : parsed;
}

Map<String, dynamic> _publicUser(Map<String, dynamic> user) {
  return {
    'id': user['id'],
    'email': user['email'],
    if (user['name'] != null) 'name': user['name'],
    'createdAt': user['createdAt'],
  };
}

Future<void> _ensureUserStore() async {
  final dataDir = Directory(p.join('data'));
  if (!await dataDir.exists()) {
    await dataDir.create(recursive: true);
  }

  final file = File(p.join(dataDir.path, 'users.json'));
  if (!await file.exists()) {
    await file.writeAsString(jsonEncode(<Map<String, dynamic>>[]));
  }
}

Future<List<Map<String, dynamic>>> _readUsers() async {
  final file = File(p.join('data', 'users.json'));
  if (!await file.exists()) {
    return <Map<String, dynamic>>[];
  }

  final contents = await file.readAsString();
  if (contents.trim().isEmpty) {
    return <Map<String, dynamic>>[];
  }

  final data = jsonDecode(contents);
  if (data is List) {
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
  throw const FormatException('Users store is corrupt.');
}

Future<void> _writeUsers(List<Map<String, dynamic>> users) async {
  final file = File(p.join('data', 'users.json'));
  final jsonString = const JsonEncoder.withIndent('  ').convert(users);
  await file.writeAsString(jsonString);
}

Response _jsonResponse(int statusCode, Map<String, dynamic> body) {
  return Response(
    statusCode,
    body: jsonEncode(body),
    headers: {'Content-Type': 'application/json'},
  );
}

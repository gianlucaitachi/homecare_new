import 'dart:convert';
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:qr/qr.dart';

import 'package:backend/auth.dart';

final _uuid = Uuid();
String _dataDirectory = 'data';
final _webSocketClients = <WebSocketChannel>{};

Future<void> main(List<String> args) async {
  final jwtSecret = Platform.environment['JWT_SECRET'];
  if (jwtSecret == null || jwtSecret.isEmpty) {
    stderr.writeln('JWT_SECRET environment variable is required.');
    exit(1);
  }

  await _ensureUserStore();
  await ensureTaskStore();

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
    })
    ..get('/api/tasks', (Request request) async {
      final tasks = await loadTasks();
      return _jsonResponse(200, {'tasks': tasks});
    })
    ..post('/api/tasks', (Request request) async {
      Map<String, dynamic> payload;
      try {
        payload = await _parseJson(request);
      } on FormatException {
        return _jsonResponse(400, {'error': 'Invalid JSON payload.'});
      }

      final title = _parseString(payload['title']);
      final assignee = _parseString(payload['assignee']);
      final dueDate = _parseString(payload['dueDate']);
      final statusValue = _parseString(payload['status']);

      if (title.isEmpty || assignee.isEmpty || dueDate.isEmpty) {
        return _jsonResponse(
          400,
          {'error': 'Title, assignee, and dueDate are required.'},
        );
      }

      final tasks = await loadTasks();
      final task = {
        'id': _uuid.v4(),
        'title': title,
        'assignee': assignee,
        'dueDate': dueDate,
        'status': statusValue.isEmpty ? 'pending' : statusValue,
        'qr_code': generateTaskQrCode(),
      };

      tasks.add(task);
      await saveTasks(tasks);
      broadcastTaskEvent('created', task);

      return _jsonResponse(201, {'task': task});
    })
    ..put('/api/tasks/<id>', (Request request, String id) async {
      Map<String, dynamic> payload;
      try {
        payload = await _parseJson(request);
      } on FormatException {
        return _jsonResponse(400, {'error': 'Invalid JSON payload.'});
      }

      final tasks = await loadTasks();
      final index = tasks.indexWhere((task) => task['id'] == id);
      if (index == -1) {
        return _jsonResponse(404, {'error': 'Task not found.'});
      }

      final existing = tasks[index];
      final updated = Map<String, dynamic>.from(existing);

      if (payload.containsKey('title')) {
        final title = _parseString(payload['title']);
        if (title.isEmpty) {
          return _jsonResponse(400, {'error': 'Title cannot be empty.'});
        }
        updated['title'] = title;
      }
      if (payload.containsKey('assignee')) {
        final assignee = _parseString(payload['assignee']);
        if (assignee.isEmpty) {
          return _jsonResponse(400, {'error': 'Assignee cannot be empty.'});
        }
        updated['assignee'] = assignee;
      }
      if (payload.containsKey('dueDate')) {
        final dueDate = _parseString(payload['dueDate']);
        if (dueDate.isEmpty) {
          return _jsonResponse(400, {'error': 'dueDate cannot be empty.'});
        }
        updated['dueDate'] = dueDate;
      }
      if (payload.containsKey('status')) {
        final status = _parseString(payload['status']);
        if (status.isEmpty) {
          return _jsonResponse(400, {'error': 'status cannot be empty.'});
        }
        updated['status'] = status;
      }

      tasks[index] = updated;
      await saveTasks(tasks);
      broadcastTaskEvent('updated', updated);

      return _jsonResponse(200, {'task': updated});
    })
    ..delete('/api/tasks/<id>', (Request request, String id) async {
      final tasks = await loadTasks();
      final index = tasks.indexWhere((task) => task['id'] == id);
      if (index == -1) {
        return _jsonResponse(404, {'error': 'Task not found.'});
      }

      final removed = tasks.removeAt(index);
      await saveTasks(tasks);
      broadcastTaskEvent('deleted', removed);

      return _jsonResponse(200, {'status': 'deleted'});
    })
    ..post('/api/tasks/<id>/complete-qr', (Request request, String id) async {
      Map<String, dynamic> payload;
      try {
        payload = await _parseJson(request);
      } on FormatException {
        return _jsonResponse(400, {'error': 'Invalid JSON payload.'});
      }

      final submittedQr = _parseString(payload['qr_code']);
      if (submittedQr.isEmpty) {
        return _jsonResponse(400, {'error': 'qr_code is required.'});
      }

      final tasks = await loadTasks();
      final index = tasks.indexWhere((task) => task['id'] == id);
      if (index == -1) {
        return _jsonResponse(404, {'error': 'Task not found.'});
      }

      final existing = tasks[index];
      if (!isQrCodeValid(existing['qr_code'] as String? ?? '', submittedQr)) {
        return _jsonResponse(400, {'error': 'Invalid QR code for task.'});
      }

      final updated = Map<String, dynamic>.from(existing);
      updated['status'] = 'done';
      tasks[index] = updated;
      await saveTasks(tasks);
      broadcastTaskEvent('completed', updated);

      return _jsonResponse(200, {'task': updated});
    })
    ..get('/ws', webSocketHandler((WebSocketChannel channel) {
      registerWebSocketClient(channel);
      channel.stream.listen(
        (_) {},
        onDone: () => unregisterWebSocketClient(channel),
        onError: (_) => unregisterWebSocketClient(channel),
      );
    }));

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_authGuard(jwtSecret))
      .addHandler(router);

  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('Server listening on port ${server.port}');
}

void configureDataDirectory(String directory) {
  _dataDirectory = directory;
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
  await _ensureDataDirectory();

  final file = File(p.join(_dataDirectory, 'users.json'));
  if (!await file.exists()) {
    await file.writeAsString(jsonEncode(<Map<String, dynamic>>[]));
  }
}

Future<List<Map<String, dynamic>>> _readUsers() async {
  final file = File(p.join(_dataDirectory, 'users.json'));
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
  final file = File(p.join(_dataDirectory, 'users.json'));
  final jsonString = const JsonEncoder.withIndent('  ').convert(users);
  await file.writeAsString(jsonString);
}

Future<void> _ensureDataDirectory() async {
  final dataDir = Directory(p.join(_dataDirectory));
  if (!await dataDir.exists()) {
    await dataDir.create(recursive: true);
  }
}

Future<void> ensureTaskStore() async {
  await _ensureDataDirectory();
  final file = File(p.join(_dataDirectory, 'tasks.json'));
  if (!await file.exists()) {
    await file.writeAsString(jsonEncode(<Map<String, dynamic>>[]));
  }
}

Future<List<Map<String, dynamic>>> loadTasks() async {
  final file = File(p.join(_dataDirectory, 'tasks.json'));
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
  throw const FormatException('Tasks store is corrupt.');
}

Future<void> saveTasks(List<Map<String, dynamic>> tasks) async {
  final file = File(p.join(_dataDirectory, 'tasks.json'));
  final jsonString = const JsonEncoder.withIndent('  ').convert(tasks);
  await file.writeAsString(jsonString);
}

String generateTaskQrCode() {
  final qrData = _uuid.v4();
  final qrCode = QrCode.fromData(
    data: qrData,
    errorCorrectLevel: QrErrorCorrectLevel.medium,
  );

  final matrix = <List<int>>[];
  for (var y = 0; y < qrCode.moduleCount; y++) {
    final row = <int>[];
    for (var x = 0; x < qrCode.moduleCount; x++) {
      row.add(qrCode.isDark(y, x) ? 1 : 0);
    }
    matrix.add(row);
  }

  return jsonEncode({'data': qrData, 'matrix': matrix});
}

bool isQrCodeValid(String stored, String provided) {
  return stored.isNotEmpty && stored == provided;
}

void registerWebSocketClient(WebSocketChannel channel) {
  _webSocketClients.add(channel);
}

void unregisterWebSocketClient(WebSocketChannel channel) {
  _webSocketClients.remove(channel);
}

void broadcastTaskEvent(String action, Map<String, dynamic> task) {
  if (_webSocketClients.isEmpty) {
    return;
  }

  final payload = jsonEncode({
    'event': 'task:updated',
    'action': action,
    'task': task,
  });

  final disconnected = <WebSocketChannel>[];
  for (final client in _webSocketClients) {
    try {
      client.sink.add(payload);
    } catch (_) {
      disconnected.add(client);
    }
  }

  for (final client in disconnected) {
    unregisterWebSocketClient(client);
    try {
      client.sink.close();
    } catch (_) {}
  }
}

Response _jsonResponse(int statusCode, Map<String, dynamic> body) {
  return Response(
    statusCode,
    body: jsonEncode(body),
    headers: {'Content-Type': 'application/json'},
  );
}

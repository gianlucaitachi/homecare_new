import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:backend/bin/server.dart' as server;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _TestWebSocketChannel implements WebSocketChannel {
  _TestWebSocketChannel() {
    _outboundController.stream.listen((message) {
      sentMessages.add(message);
    });
  }

  final _inboundController = StreamController<dynamic>();
  final _outboundController = StreamController<dynamic>();

  final List<dynamic> sentMessages = [];

  @override
  Stream<dynamic> get stream => _inboundController.stream;

  @override
  StreamSink<dynamic> get sink => _outboundController.sink;

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    await _inboundController.close();
    await _outboundController.close();
  }

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tasks_test');
    server.configureDataDirectory(p.join(tempDir.path, 'data'));
    await server.ensureTaskStore();
  });

  tearDown(() async {
    server.configureDataDirectory('data');
    await tempDir.delete(recursive: true);
  });

  test('loadTasks returns persisted data', () async {
    final initial = await server.loadTasks();
    expect(initial, isEmpty);

    final task = {
      'id': 'test-id',
      'title': 'Medication reminder',
      'assignee': 'Nurse Joy',
      'dueDate': '2024-05-01',
      'status': 'pending',
      'qr_code': server.generateTaskQrCode(),
    };

    await server.saveTasks([task]);
    final loaded = await server.loadTasks();

    expect(loaded, hasLength(1));
    expect(loaded.first['title'], equals('Medication reminder'));
    expect(loaded.first['qr_code'], equals(task['qr_code']));
  });

  test('isQrCodeValid validates equality', () {
    final qr = server.generateTaskQrCode();
    final mismatched = jsonEncode({'data': 'other', 'matrix': []});

    expect(server.isQrCodeValid(qr, qr), isTrue);
    expect(server.isQrCodeValid(qr, mismatched), isFalse);
  });

  test('broadcastTaskEvent notifies websocket clients', () async {
    final channel = _TestWebSocketChannel();
    server.registerWebSocketClient(channel);

    final task = {
      'id': 'notify-id',
      'title': 'Follow-up visit',
      'assignee': 'Dr. Smith',
      'dueDate': '2024-06-10',
      'status': 'pending',
      'qr_code': server.generateTaskQrCode(),
    };

    server.broadcastTaskEvent('created', task);

    expect(channel.sentMessages, hasLength(1));
    final payload = jsonDecode(channel.sentMessages.first as String)
        as Map<String, dynamic>;
    expect(payload['event'], equals('task:updated'));
    expect(payload['action'], equals('created'));
    expect(payload['task']['id'], equals('notify-id'));

    server.unregisterWebSocketClient(channel);
    await channel.close();
  });
}

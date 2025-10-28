import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:backend/tasks.dart' as tasks;
import 'package:path/path.dart' as p;
import 'package:stream_channel/stream_channel.dart';
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
  WebSocketSink get sink => throw UnimplementedError();

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    await _inboundController.close();
    await _outboundController.close();
  }

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => Future.value();

  @override
  StreamChannel<S> cast<S>() {
    return StreamChannel.withCloseGuarantee(stream, sink).cast<S>();
  }

  @override
  StreamChannel<T> transform<T>(
    StreamChannelTransformer<T, dynamic> transformer,
  ) {
    return StreamChannel.withCloseGuarantee(stream, sink).transform(transformer);
  }

  @override
  StreamChannel changeSink(StreamSink Function(StreamSink p1) change) {
    throw UnimplementedError();
  }

  @override
  StreamChannel changeStream(Stream Function(Stream p1) change) {
    throw UnimplementedError();
  }

  @override
  void pipe(StreamChannel other) {}

  @override
  StreamChannel transformSink(StreamSinkTransformer transformer) {
    throw UnimplementedError();
  }

  @override
  StreamChannel transformStream(StreamTransformer transformer) {
    throw UnimplementedError();
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tasks_test');
    tasks.configureDataDirectory(p.join(tempDir.path, 'data'));
    await tasks.ensureTaskStore();
  });

  tearDown(() async {
    tasks.configureDataDirectory('data');
    await tempDir.delete(recursive: true);
  });

  test('loadTasks returns persisted data', () async {
    final initial = await tasks.loadTasks();
    expect(initial, isEmpty);

    final task = {
      'id': 'test-id',
      'title': 'Medication reminder',
      'assignee': 'Nurse Joy',
      'dueDate': '2024-05-01',
      'status': 'pending',
      'qr_code': tasks.generateTaskQrCode(),
    };
    await tasks.saveTasks([task]);
    final loaded = await tasks.loadTasks();

    expect(loaded, hasLength(1));
    expect(loaded.first['title'], equals('Medication reminder'));
    expect(loaded.first['qr_code'], equals(task['qr_code']));
  });
  test('isQrCodeValid validates equality', () {
    final qr = tasks.generateTaskQrCode();
    final mismatched = jsonEncode({'data': 'other', 'matrix': []});

    expect(tasks.isQrCodeValid(qr, qr), isTrue);
    expect(tasks.isQrCodeValid(qr, mismatched), isFalse);
  });
}

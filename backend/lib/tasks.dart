import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:qr/qr.dart';

final _uuid = Uuid();
String _dataDirectory = 'data';

void configureDataDirectory(String directory) {
  _dataDirectory = directory;
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
        .map((e) => Map<String, dynamic>.from(e))
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
    errorCorrectLevel: QrErrorCorrectLevel.M,
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

Future<void> _ensureDataDirectory() async {
  final dataDir = Directory(p.join(_dataDirectory));
  if (!await dataDir.exists()) {
    await dataDir.create(recursive: true);
  }
}

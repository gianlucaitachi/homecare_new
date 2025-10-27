class Task {
  const Task({
    required this.id,
    required this.title,
    required this.assignee,
    required this.dueDate,
    required this.status,
    required this.qrCode,
  });

  final String id;
  final String title;
  final String assignee;
  final String dueDate;
  final String status;
  final String qrCode;

  factory Task.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final assignee = json['assignee'];
    final dueDate = json['dueDate'];
    final status = json['status'];
    final qrCode = json['qr_code'] ?? json['qrCode'];

    if (id is! String || id.isEmpty) {
      throw const FormatException('Task id is missing');
    }
    if (title is! String || title.isEmpty) {
      throw const FormatException('Task title is missing');
    }
    if (assignee is! String || assignee.isEmpty) {
      throw const FormatException('Task assignee is missing');
    }
    if (dueDate is! String || dueDate.isEmpty) {
      throw const FormatException('Task dueDate is missing');
    }
    if (status is! String || status.isEmpty) {
      throw const FormatException('Task status is missing');
    }
    if (qrCode is! String || qrCode.isEmpty) {
      throw const FormatException('Task qr_code is missing');
    }

    return Task(
      id: id,
      title: title,
      assignee: assignee,
      dueDate: dueDate,
      status: status,
      qrCode: qrCode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'assignee': assignee,
      'dueDate': dueDate,
      'status': status,
      'qr_code': qrCode,
    };
  }

  Task copyWith({
    String? id,
    String? title,
    String? assignee,
    String? dueDate,
    String? status,
    String? qrCode,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      assignee: assignee ?? this.assignee,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      qrCode: qrCode ?? this.qrCode,
    );
  }
}

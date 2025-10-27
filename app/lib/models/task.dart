class Task {
  const Task({
    required this.id,
    required this.title,
    required this.assignee,
    required this.dueDate,
    required this.status,
    required this.qrCode,
    this.description,
  });

  final String id;
  final String title;
  final String assignee;
  final DateTime? dueDate;
  final String status;
  final String qrCode;
  final String? description;

  static const Object _unset = Object();

  factory Task.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final assignee = json['assignee'];
    final status = json['status'];
    final qrCode = json['qr_code'] ?? json['qrCode'];
    final description = json['description'];
    final rawDueDate = json['dueDate'] ?? json['due_date'];
    DateTime? dueDate;

    if (id is! String || id.isEmpty) {
      throw const FormatException('Task id is missing');
    }
    if (title is! String || title.isEmpty) {
      throw const FormatException('Task title is missing');
    }
    if (assignee is! String || assignee.isEmpty) {
      throw const FormatException('Task assignee is missing');
    }
    if (status is! String || status.isEmpty) {
      throw const FormatException('Task status is missing');
    }
    if (qrCode is! String || qrCode.isEmpty) {
      throw const FormatException('Task qr_code is missing');
    }
    if (description != null && description is! String) {
      throw const FormatException('Task description must be a string');
    }

    if (rawDueDate == null || (rawDueDate is String && rawDueDate.trim().isEmpty)) {
      dueDate = null;
    } else if (rawDueDate is String) {
      dueDate = DateTime.tryParse(rawDueDate);
      if (dueDate == null) {
        throw const FormatException('Task dueDate has an invalid format');
      }
    } else if (rawDueDate is DateTime) {
      dueDate = rawDueDate;
    } else {
      throw const FormatException('Task dueDate must be a string or null');
    }

    return Task(
      id: id,
      title: title,
      assignee: assignee,
      dueDate: dueDate,
      status: status,
      qrCode: qrCode,
      description: description as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'assignee': assignee,
      'dueDate': dueDate?.toUtc().toIso8601String(),
      'status': status,
      'qr_code': qrCode,
      'description': description,
    };
  }

  Task copyWith({
    String? id,
    String? title,
    String? assignee,
    Object? dueDate = _unset,
    String? status,
    String? qrCode,
    Object? description = _unset,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      assignee: assignee ?? this.assignee,
      dueDate:
          identical(dueDate, _unset) ? this.dueDate : dueDate as DateTime?,
      status: status ?? this.status,
      qrCode: qrCode ?? this.qrCode,
      description: identical(description, _unset)
          ? this.description
          : description as String?,
    );
  }
}

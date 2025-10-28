import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:homecare_app/repository/task_repository.dart';
import 'package:homecare_app/services/notification_service.dart';
import 'package:homecare_app/services/task_service.dart';
import 'package:homecare_app/services/task_storage.dart';

class FakeTaskService extends TaskService {
  FakeTaskService() : super(dio: Dio());

  Response<Map<String, dynamic>>? createResponse;
  Response<Map<String, dynamic>>? updateResponse;
  Response<Map<String, dynamic>>? completeResponse;

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    if (path.endsWith('/complete-qr')) {
      final response = completeResponse;
      if (response == null) {
        throw StateError('completeResponse not set');
      }
      return response as Response<T>;
    }

    final response = createResponse;
    if (response == null) {
      throw StateError('createResponse not set');
    }
    return response as Response<T>;
  }

  @override
  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final response = updateResponse;
    if (response == null) {
      throw StateError('updateResponse not set');
    }
    return response as Response<T>;
  }

  @override
  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return Response<T>(requestOptions: RequestOptions(path: path));
  }
}

class RecordedNotification {
  const RecordedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledDate,
    required this.payload,
  });

  final int id;
  final String title;
  final String body;
  final DateTime? scheduledDate;
  final String? payload;
}

class RecordingNotificationService extends NotificationService {
  final List<RecordedNotification> scheduled = <RecordedNotification>[];
  final List<int> cancelled = <int>[];

  @override
  Future<void> init() async {}

  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    DateTime? scheduledDate,
    String? payload,
  }) async {
    scheduled.add(
      RecordedNotification(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        payload: payload,
      ),
    );
  }

  @override
  Future<void> cancelNotification(int id) async {
    cancelled.add(id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TaskRepository notifications', () {
    late FakeTaskService taskService;
    late RecordingNotificationService notificationService;
    late TaskRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      taskService = FakeTaskService();
      notificationService = RecordingNotificationService();
      repository = TaskRepository(
        taskService: taskService,
        taskStorage: TaskStorage.instance,
        notificationService: notificationService,
      );
    });

    test('createTask schedules notifications for future due dates', () async {
      final dueDate =
          DateTime.now().add(const Duration(days: 1)).toUtc().toIso8601String();
      const description = 'Visit patient at home';
      final taskJson = <String, dynamic>{
        'id': '1',
        'title': 'Visit patient',
        'assignee': 'Nurse Joy',
        'dueDate': dueDate,
        'status': 'pending',
        'qr_code': 'abc123',
        'description': description,
      };
      taskService.createResponse = Response<Map<String, dynamic>>(
        data: <String, dynamic>{'task': taskJson},
        requestOptions: RequestOptions(path: '/api/tasks'),
      );

      final task = await repository.createTask(<String, dynamic>{});

      expect(task.id, '1');
      expect(task.dueDate?.toUtc(), DateTime.parse(dueDate).toUtc());
      expect(task.description, description);
      expect(notificationService.scheduled, hasLength(1));
      expect(
        notificationService.scheduled.first.id,
        repository.scheduledNotificationIds[task.id],
      );
      expect(
        repository.scheduledNotificationIds[task.id],
        equals(notificationService.scheduled.first.id),
      );
      expect(
        notificationService.scheduled.first.scheduledDate,
        task.dueDate?.toLocal(),
      );
    });

    test('updateTask re-schedules notifications for future due dates', () async {
      final initialDue =
          DateTime.now().add(const Duration(days: 2)).toUtc().toIso8601String();
      final initialTask = <String, dynamic>{
        'id': '2',
        'title': 'Collect samples',
        'assignee': 'Nurse Dan',
        'dueDate': initialDue,
        'status': 'pending',
        'qr_code': 'qr-initial',
        'description': 'Collect blood samples',
      };
      taskService.createResponse = Response<Map<String, dynamic>>(
        data: <String, dynamic>{'task': initialTask},
        requestOptions: RequestOptions(path: '/api/tasks'),
      );
      await repository.createTask(<String, dynamic>{});

      final newDue =
          DateTime.now().add(const Duration(days: 3)).toUtc().toIso8601String();
      final updatedTask = Map<String, dynamic>.from(initialTask)
        ..['dueDate'] = newDue
        ..['description'] = 'Collect updated samples';
      taskService.updateResponse = Response<Map<String, dynamic>>(
        data: <String, dynamic>{'task': updatedTask},
        requestOptions: RequestOptions(path: '/api/tasks/2'),
      );

      final task = await repository.updateTask('2', <String, dynamic>{});

      expect(task.dueDate?.toUtc(), DateTime.parse(newDue).toUtc());
      expect(task.description, 'Collect updated samples');
      expect(notificationService.scheduled, hasLength(2));
      expect(
        notificationService.scheduled.last.id,
        repository.scheduledNotificationIds[task.id],
      );
    });

    test('deleteTask cancels scheduled notifications', () async {
      final dueDate =
          DateTime.now().add(const Duration(days: 1)).toUtc().toIso8601String();
      final taskJson = <String, dynamic>{
        'id': '3',
        'title': 'Deliver medicine',
        'assignee': 'Nurse Ana',
        'dueDate': dueDate,
        'status': 'pending',
        'qr_code': 'qr-delete',
        'description': 'Deliver medicine to patient',
      };
      taskService.createResponse = Response<Map<String, dynamic>>(
        data: <String, dynamic>{'task': taskJson},
        requestOptions: RequestOptions(path: '/api/tasks'),
      );
      final task = await repository.createTask(<String, dynamic>{});

      await repository.deleteTask(task.id);

      final scheduledId = notificationService.scheduled.first.id;
      expect(notificationService.cancelled, contains(scheduledId));
      expect(repository.scheduledNotificationIds.containsKey(task.id), isFalse);
    });

    test('completeByQr cancels scheduled notifications', () async {
      final dueDate =
          DateTime.now().add(const Duration(days: 1)).toUtc().toIso8601String();
      final taskJson = <String, dynamic>{
        'id': '4',
        'title': 'Check vitals',
        'assignee': 'Nurse Lee',
        'dueDate': dueDate,
        'status': 'pending',
        'qr_code': 'qr-complete',
        'description': null,
      };
      taskService.createResponse = Response<Map<String, dynamic>>(
        data: <String, dynamic>{'task': taskJson},
        requestOptions: RequestOptions(path: '/api/tasks'),
      );
      await repository.createTask(<String, dynamic>{});

      final completedTask = Map<String, dynamic>.from(taskJson)
        ..['status'] = 'completed';
      taskService.completeResponse = Response<Map<String, dynamic>>(
        data: <String, dynamic>{'task': completedTask},
        requestOptions: RequestOptions(path: '/api/tasks/4/complete-qr'),
      );

      await repository.completeByQr(id: '4', code: 'qr-complete');

      final scheduledId = notificationService.scheduled.first.id;
      expect(notificationService.cancelled, contains(scheduledId));
      expect(repository.scheduledNotificationIds.containsKey('4'), isFalse);
    });

    test('createTask does not schedule notifications without due date', () async {
      final taskJson = <String, dynamic>{
        'id': '5',
        'title': 'General follow-up',
        'assignee': 'Nurse Sam',
        'dueDate': null,
        'status': 'pending',
        'qr_code': 'qr-nodue',
        'description': null,
      };
      taskService.createResponse = Response<Map<String, dynamic>>(
        data: <String, dynamic>{'task': taskJson},
        requestOptions: RequestOptions(path: '/api/tasks'),
      );

      final task = await repository.createTask(<String, dynamic>{});

      expect(task.dueDate, isNull);
      expect(task.description, isNull);
      expect(notificationService.scheduled, isEmpty);
      expect(repository.scheduledNotificationIds.containsKey(task.id), isFalse);
    });
  });
}

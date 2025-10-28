import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:homecare_app/models/task.dart';
import 'package:homecare_app/repository/task_repository.dart';
import 'package:homecare_app/views/task_form_view.dart';

class MockTaskRepository extends Mock implements TaskRepository {}

class MockNavigatorObserver extends Mock implements NavigatorObserver {}

class FakeRoute<T> extends Fake implements Route<T> {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRoute<dynamic>());
  });

  testWidgets('shows validation errors when required fields are missing',
      (tester) async {
    final repository = MockTaskRepository();

    await tester.pumpWidget(
      Provider<TaskRepository>.value(
        value: repository,
        child: const MaterialApp(
          home: TaskFormView(baseUrl: 'http://localhost'),
        ),
      ),
    );

    await tester.tap(find.text('Create Task'));
    await tester.pump();

    expect(find.text('Title is required.'), findsOneWidget);
    expect(find.text('Description is required.'), findsOneWidget);
    expect(find.text('Assignee is required.'), findsOneWidget);
    expect(find.text('Due date is required.'), findsOneWidget);
    verifyNever(() => repository.createTask(any()));
  });

  testWidgets('submits form data and notifies repository', (tester) async {
    final repository = MockTaskRepository();
    final navigatorObserver = MockNavigatorObserver();
    final completer = Completer<Task>();
    final createdTask = Task(
      id: '123',
      title: 'Created Task',
      assignee: 'Assignee',
      dueDate: DateTime.parse('2025-01-01'),
      status: 'in_progress',
      qrCode: 'qr',
    );

    when(() => repository.createTask(any())).thenAnswer((_) => completer.future);
    when(() => repository.fetchTasks(forceRefresh: true))
        .thenAnswer((_) async => <Task>[]);

    when(() => navigatorObserver.didPush(any(), any())).thenAnswer((_) {});
    when(() => navigatorObserver.didPop(any(), any())).thenAnswer((_) {});

    await tester.pumpWidget(
      Provider<TaskRepository>.value(
        value: repository,
        child: MaterialApp(
          home: const TaskFormView(baseUrl: 'http://localhost'),
          navigatorObservers: [navigatorObserver],
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('taskForm_titleField')),
      'My Task',
    );
    await tester.enterText(
      find.byKey(const ValueKey('taskForm_descriptionField')),
      'A description',
    );
    await tester.enterText(
      find.byKey(const ValueKey('taskForm_assigneeField')),
      'Alex',
    );
    await tester.enterText(
      find.byKey(const ValueKey('taskForm_dueDateField')),
      '2025-01-01',
    );

    await tester.tap(find.byKey(const ValueKey('taskForm_statusField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('IN PROGRESS').last);
    await tester.pump();

    await tester.tap(find.text('Create Task'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(createdTask);
    await tester.pumpAndSettle();

    final capturedPayload = verify(
      () => repository.createTask(captureAny()),
    ).captured.single as Map<String, dynamic>;

    expect(capturedPayload['title'], 'My Task');
    expect(capturedPayload['description'], 'A description');
    expect(capturedPayload['assignee'], 'Alex');
    expect(capturedPayload['dueDate'], '2025-01-01');
    expect(capturedPayload['status'], 'in_progress');

    verify(() => repository.fetchTasks(forceRefresh: true)).called(1);
    verify(() => navigatorObserver.didPop(any(), any())).called(1);
  });
}

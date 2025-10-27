import '../Models/task.dart';

class NotificationService {
  const NotificationService();

  Future<String?> scheduleNotification(Task task) async {
    return task.id;
  }

  Future<void> cancelNotification(String notificationId) async {}
}

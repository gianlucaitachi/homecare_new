import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._internal();

  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionDenied = false;

  bool get isInitialized => _initialized;

  bool get permissionDenied => _permissionDenied;

  Future<bool> initialize() async {
    if (_initialized) {
      return !_permissionDenied;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    bool? permissionGranted;

    if (Platform.isIOS) {
      permissionGranted = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      final androidPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null && _isAndroidTOrAbove()) {
        permissionGranted = await androidPlugin.requestPermission();
      }
    }

    _permissionDenied = permissionGranted == false;
    _initialized = true;

    return !_permissionDenied;
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    if (_permissionDenied) {
      return;
    }

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'homecare_default_channel',
        'Homecare Notifications',
        channelDescription: 'General notifications for the Homecare app.',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    final scheduleDate = scheduledDate.isBefore(DateTime.now())
        ? DateTime.now().add(const Duration(seconds: 1))
        : scheduledDate;

    await _flutterLocalNotificationsPlugin.schedule(
      id,
      title,
      body,
      scheduleDate,
      notificationDetails,
      payload: payload,
      androidAllowWhileIdle: true,
    );
  }

  Future<void> cancelNotification(int id) {
    return _flutterLocalNotificationsPlugin.cancel(id);
  }

  bool _isAndroidTOrAbove() {
    final version = Platform.operatingSystemVersion;
    final match = RegExp(r'Android\s*(\d+)').firstMatch(version);
    final sdkString = match?.group(1);
    if (sdkString == null) {
      return false;
    }

    final sdkVersion = int.tryParse(sdkString);
    if (sdkVersion == null) {
      return false;
    }

    return sdkVersion >= 13;
  }
}

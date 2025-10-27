import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionGranted = true;

  bool get isInitialized => _initialized;

  bool get permissionGranted => _permissionGranted;

  bool get permissionDenied => !_permissionGranted;

  Future<void> init() async {
    if (_initialized) {
      return;
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

    await _initializeTimezones();
    await _requestPermissions();

    _initialized = true;
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    DateTime? scheduledDate,
    String? payload,
  }) async {
    if (!_initialized) {
      await init();
    }

    if (!_permissionGranted) {
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

    final now = DateTime.now();
    final targetDate = scheduledDate ?? now;
    final safeDate =
        targetDate.isBefore(now) ? now.add(const Duration(seconds: 1)) : targetDate;
    final tzDate = tz.TZDateTime.from(safeDate, tz.local);

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      notificationDetails,
      payload: payload,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelNotification(int id) {
    return _flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> _initializeTimezones() async {
    tz.initializeTimeZones();
    final timeZoneName = DateTime.now().timeZoneName;
    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  Future<void> _requestPermissions() async {
    bool permissionGranted = true;

    if (Platform.isIOS || Platform.isMacOS) {
      final iosImplementation = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final macImplementation = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>();
      final iosGranted = await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      final macGranted = await macImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      permissionGranted = (iosGranted ?? macGranted ?? true) == true;
    } else if (Platform.isAndroid && _isAndroidTOrAbove()) {
      final androidImplementation = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final androidGranted = await androidImplementation?.requestPermission();
      permissionGranted = androidGranted ?? true;
    }

    _permissionGranted = permissionGranted;
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

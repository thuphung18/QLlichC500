import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/schedule_item.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (kIsWeb) return;
    // Khởi tạo timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh')); // Setup timezone Vietnam

    // Config cho Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );

    // Xin quyền trên Android 13+
    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
          
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();
    }
  }

  Future<void> scheduleScheduleNotification(ScheduleItem item) async {
    if (kIsWeb) return;
    final startDateTime = item.startDateTime;
    if (startDateTime == null) return;

    // Hẹn trước 5 phút
    DateTime notificationTime = startDateTime.subtract(const Duration(minutes: 5));
    
    // Nếu thời gian hẹn trước 5 phút đã qua (vd: tạo lịch sát giờ)
    if (notificationTime.isBefore(DateTime.now())) {
      // Nếu sự kiện vẫn chưa bắt đầu, thì thông báo luôn sau 5 giây
      if (startDateTime.isAfter(DateTime.now())) {
        notificationTime = DateTime.now().add(const Duration(seconds: 5));
      } else {
        // Sự kiện đã bắt đầu (trong quá khứ) thì không thông báo nữa
        return;
      }
    }

    final int notificationId = item.id.hashCode;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: notificationId,
      title: 'Sắp có sự kiện: ${item.title}',
      body: 'Sự kiện sẽ bắt đầu vào lúc ${item.startTime} tại ${item.room}.',
      scheduledDate: tz.TZDateTime.from(notificationTime, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'schedule_reminders_high_priority_v1',
          'Nhắc nhở lịch công tác (Khẩn cấp)',
          channelDescription: 'Kênh thông báo nhắc nhở lịch công tác trước 5 phút',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
          styleInformation: BigTextStyleInformation(''),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> showNotification({required int id, required String title, required String body}) async {
    if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'schedule_reminders_high_priority_v1',
          'Nhắc nhở lịch công tác (Khẩn cấp)',
          channelDescription: 'Kênh thông báo nhắc nhở lịch công tác',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
          styleInformation: BigTextStyleInformation(''),
        ),
      ),
    );
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}

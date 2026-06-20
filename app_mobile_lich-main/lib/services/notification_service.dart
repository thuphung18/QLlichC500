import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:shared_preferences/shared_preferences.dart';
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

  Future<void> scheduleScheduleNotification(ScheduleItem item, {int? customMinutes}) async {
    if (kIsWeb) return;
    final startDateTime = item.startDateTime;
    if (startDateTime == null) return;

    int minutesBefore = customMinutes ?? 5;
    if (customMinutes == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        minutesBefore = prefs.getInt('reminder_minutes') ?? 5;
      } catch (_) {}
    }

    // Hẹn trước X phút
    DateTime notificationTime = startDateTime.subtract(Duration(minutes: minutesBefore));
    
    // Nếu thời gian hẹn trước X phút đã qua (vd: tạo lịch sát giờ)
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
      body: 'Sự kiện sẽ bắt đầu vào lúc ${item.startTime} tại ${item.room} (báo trước $minutesBefore phút).',
      scheduledDate: tz.TZDateTime.from(notificationTime, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'schedule_reminders_high_priority_v1',
          'Nhắc nhở lịch công tác (Khẩn cấp)',
          channelDescription: 'Kênh thông báo nhắc nhở lịch công tác trước $minutesBefore phút',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
          styleInformation: const BigTextStyleInformation(''),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> scheduleTomorrowDigest(List<ScheduleItem> mySchedules) async {
    if (kIsWeb) return;
    
    // Group schedules by date label (e.g. "23/06")
    final Map<String, List<ScheduleItem>> grouped = {};
    for (final item in mySchedules) {
      if (item.dateLabel.isEmpty) continue;
      grouped.putIfAbsent(item.dateLabel, () => []).add(item);
    }
    
    for (final dateLabel in grouped.keys) {
      final schedules = grouped[dateLabel]!;
      if (schedules.isEmpty) continue;
      
      // Parse the date
      final RegExp dateRegex = RegExp(r'(\d{1,2})/(\d{1,2})');
      final match = dateRegex.firstMatch(dateLabel);
      if (match == null) continue;
      
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      
      final now = DateTime.now();
      final scheduleDate = DateTime(now.year, month, day);
      
      // Notification date: Day before (D - 1) at 20:00 (8 PM)
      final notificationTime = DateTime(scheduleDate.year, scheduleDate.month, scheduleDate.day - 1, 20, 0);
      
      // If notification time is in the future, schedule it
      if (notificationTime.isAfter(now)) {
        final int notificationId = dateLabel.hashCode + 99999; // Ensure unique ID
        
        final titles = schedules.map((s) => '• ${s.startTime}: ${s.title}').join('\n');
        final String body = 'Bạn có ${schedules.length} lịch diễn ra vào ngày mai:\n$titles';
        
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id: notificationId,
          title: 'Lịch công tác ngày mai (${dateLabel})',
          body: body,
          scheduledDate: tz.TZDateTime.from(notificationTime, tz.local),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'tomorrow_schedule_digest_v1',
              'Tóm tắt lịch ngày mai',
              channelDescription: 'Kênh thông báo tóm tắt các lịch công tác diễn ra vào ngày mai',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              styleInformation: BigTextStyleInformation(''),
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }
    }
  }

  Future<void> updateScheduledNotifications(List<ScheduleItem> mySchedules) async {
    if (kIsWeb) return;
    
    // Clear all scheduled notifications
    await cancelAll();
    
    final prefs = await SharedPreferences.getInstance();
    final bool notifyUpcoming = prefs.getBool('notify_upcoming') ?? true;
    final bool notifyTomorrow = prefs.getBool('notify_tomorrow') ?? true;
    final int reminderMinutes = prefs.getInt('reminder_minutes') ?? 5;
    
    if (notifyUpcoming) {
      for (final item in mySchedules) {
        if (!item.isPassed) {
          await scheduleScheduleNotification(item, customMinutes: reminderMinutes);
        }
      }
    }
    
    if (notifyTomorrow) {
      await scheduleTomorrowDigest(mySchedules);
    }
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

import 'calendar_export_stub.dart'
    if (dart.library.html) 'calendar_export_web.dart'
    if (dart.library.io) 'calendar_export_mobile.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/schedule_item.dart';

class CalendarExportHelper {
  static String _formatDateTimeForGoogle(DateTime dt) {
    final utc = dt.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}'
        '${utc.month.toString().padLeft(2, '0')}'
        '${utc.day.toString().padLeft(2, '0')}T'
        '${utc.hour.toString().padLeft(2, '0')}'
        '${utc.minute.toString().padLeft(2, '0')}'
        '${utc.second.toString().padLeft(2, '0')}Z';
  }

  static Future<void> launchGoogleCalendar(ScheduleItem item) async {
    final start = item.startDateTime;
    if (start == null) {
      throw 'Không thể xác định thời gian bắt đầu của sự kiện.';
    }
    
    DateTime end = start.add(const Duration(hours: 1));

    final startStr = _formatDateTimeForGoogle(start);
    final endStr = _formatDateTimeForGoogle(end);

    final title = Uri.encodeComponent(item.title);
    final details = Uri.encodeComponent(
        'Người chủ trì/Giảng viên: ${item.teacher}\nĐơn vị: ${item.unit}\nPhòng ban: ${item.departmentName}\nGhi chú: ${item.note}'
    );
    final location = Uri.encodeComponent(item.room);

    final url = 'https://www.google.com/calendar/render?action=TEMPLATE'
        '&text=$title'
        '&dates=$startStr/$endStr'
        '&details=$details'
        '&location=$location';

    final uri = Uri.parse(url);
    try {
      // Thử mở bằng ứng dụng ngoài (hoặc app Google Calendar nếu có cài đặt)
      final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!success) {
        // Fallback mở bằng trình duyệt mặc định
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      // Fallback mở bằng trình duyệt mặc định khi gọi mode externalApplication bị lỗi
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  static String generateIcsContent(List<ScheduleItem> items) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//QL Lich App//VN');
    buffer.writeln('CALSCALE:GREGORIAN');
    buffer.writeln('METHOD:PUBLISH');

    for (final item in items) {
      final start = item.startDateTime;
      if (start == null) continue;
      
      DateTime end = start.add(const Duration(hours: 1));

      final startStr = _formatDateTimeForGoogle(start);
      final endStr = _formatDateTimeForGoogle(end);
      final stampStr = _formatDateTimeForGoogle(DateTime.now());

      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln('UID:event-${item.id.hashCode}-${start.millisecondsSinceEpoch}@qllichapp.vn');
      buffer.writeln('DTSTAMP:$stampStr');
      buffer.writeln('DTSTART:$startStr');
      buffer.writeln('DTEND:$endStr');
      buffer.writeln('SUMMARY:${item.title}');
      buffer.writeln('LOCATION:${item.room}');
      
      final desc = 'Người chủ trì/Giảng viên: ${item.teacher}\\nĐơn vị: ${item.unit}\\nPhòng ban: ${item.departmentName}\\nGhi chú: ${item.note}';
      buffer.writeln('DESCRIPTION:$desc');
      buffer.writeln('STATUS:CONFIRMED');
      buffer.writeln('SEQUENCE:0');
      buffer.writeln('END:VEVENT');
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  static Future<void> exportToIcs(List<ScheduleItem> items, String fileName) async {
    final content = generateIcsContent(items);
    await saveAndShareIcs(content, fileName);
  }
}

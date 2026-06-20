import 'package:flutter/material.dart';
import '../models/schedule_item.dart';
import '../utils/calendar_export_helper.dart';

// ScheduleDetailScreen là màn hình chi tiết lịch.
// Khi bấm vào một lịch, màn này sẽ hiển thị toàn cảnh lịch đó.
class ScheduleDetailScreen extends StatelessWidget {
  final ScheduleItem item;
  final Color accentColor;
  final bool isAdmin;
  final VoidCallback? onDelete;

  const ScheduleDetailScreen({
    super.key,
    required this.item,
    required this.accentColor,
    this.isAdmin = false,
    this.onDelete,
  });

  Future<void> _handleDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: Text(
            isAdmin
                ? 'Bạn đang xóa lịch này với tư cách Quản trị viên. Lịch sẽ bị ẩn với tất cả mọi người. Bạn có chắc chắn?'
                : 'Bạn đang xóa lịch này khỏi danh sách cá nhân. Lịch sẽ không còn hiển thị với bạn nữa. Bạn có chắc chắn?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && onDelete != null) {
      onDelete!();
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Chi tiết lịch',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _handleDelete(context),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _HeaderCard(
            item: item,
            accentColor: accentColor,
          ),

          const SizedBox(height: 18),

          _SectionTitle(
            title: 'Toàn cảnh lịch',
            accentColor: accentColor,
          ),

          const SizedBox(height: 12),

          _InfoBox(
            children: [
              _InfoRow(
                icon: Icons.event,
                label: 'Ngày',
                value: item.dateLabel,
                accentColor: accentColor,
              ),
              _InfoRow(
                icon: Icons.access_time_filled,
                label: 'Thời gian',
                value: item.timeRange,
                accentColor: accentColor,
              ),
              _InfoRow(
                icon: Icons.wb_sunny,
                label: 'Buổi',
                value: _getSessionName(item.session),
                accentColor: accentColor,
              ),
            ],
          ),

          const SizedBox(height: 18),

          _SectionTitle(
            title: 'Thông tin công việc',
            accentColor: accentColor,
          ),

          const SizedBox(height: 12),

          _InfoBox(
            children: [
              _InfoRow(
                icon: Icons.person,
                label: 'Người phụ trách / Giảng viên',
                value: item.teacher,
                accentColor: accentColor,
              ),
              _InfoRow(
                icon: Icons.location_on,
                label: 'Địa điểm',
                value: item.room,
                accentColor: accentColor,
              ),
              _InfoRow(
                icon: Icons.business,
                label: 'Đơn vị',
                value: item.unit,
                accentColor: accentColor,
              ),
              _InfoRow(
                icon: Icons.apartment,
                label: 'Khoa / Phòng ban',
                value: item.departmentName,
                accentColor: accentColor,
              ),
              _InfoRow(
                icon: Icons.groups,
                label: 'Thành phần',
                value: item.participants.isEmpty
                    ? 'Chưa có thành phần'
                    : item.participants.join(', '),
                accentColor: accentColor,
              ),
            ],
          ),

          const SizedBox(height: 18),

          _SectionTitle(
            title: 'Ghi chú',
            accentColor: accentColor,
          ),

          const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            child: Text(
              item.note,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF334155),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                await CalendarExportHelper.launchGoogleCalendar(item);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Không thể mở Google Calendar: $e')),
                );
              }
            },
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            label: const Text(
              'Thêm vào Google Calendar',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4285F4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                final dateClean = item.dateLabel.replaceAll('/', '_');
                await CalendarExportHelper.exportToIcs([item], 'lich_$dateClean.ics');
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lỗi xuất file .ics: $e')),
                );
              }
            },
            icon: Icon(Icons.file_download, color: accentColor),
            label: Text(
              'Xuất file lịch (.ics)',
              style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: accentColor, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSessionName(String session) {
    switch (session) {
      case 'morning':
        return 'Buổi sáng';
      case 'afternoon':
        return 'Buổi chiều';
      case 'evening':
        return 'Buổi tối';
      default:
        return session;
    }
  }
}

class _HeaderCard extends StatelessWidget {
  final ScheduleItem item;
  final Color accentColor;

  const _HeaderCard({
    required this.item,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor,
            accentColor.withAlpha(210),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: accentColor.withAlpha(55),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.event_note,
            color: Colors.white,
            size: 38,
          ),
          const SizedBox(height: 18),
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            item.category,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color accentColor;

  const _SectionTitle({
    required this.title,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 22,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  final List<Widget> children;

  const _InfoBox({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentColor.withAlpha(22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: accentColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodyMedium?.color ?? const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15.5,
                    color: Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
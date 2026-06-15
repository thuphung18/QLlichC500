import 'package:flutter/material.dart';

import '../models/schedule_item.dart';
import '../repositories/schedule_repository.dart';
import '../widgets/app_header.dart';
import '../widgets/day_selector.dart';
import '../widgets/empty_state.dart';
import '../widgets/schedule_summary_card.dart';
import '../widgets/session_section.dart';
import '../services/notification_service.dart';
import 'create_schedule_screen.dart';

// WeekScheduleScreen là màn hình "Lịch tuần".
// Chức năng:
// 1. Chọn thứ trong tuần.
// 2. Hiển thị tổng số lịch theo ngày.
// 3. Chia lịch thành sáng / chiều / tối.
// 4. Bấm vào từng lịch để xem chi tiết.
class WeekScheduleScreen extends StatefulWidget {
  final ScheduleRepository repository;
  final bool isAdmin;

  const WeekScheduleScreen({
    super.key,
    required this.repository,
    this.isAdmin = false,
  });

  @override
  State<WeekScheduleScreen> createState() => _WeekScheduleScreenState();
}

class _WeekScheduleScreenState extends State<WeekScheduleScreen> {
  // Mặc định đang chọn thứ 2.
  int _selectedDayIndex = 2;
  Future<List<ScheduleItem>>? _schedulesFuture;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  void _loadSchedules() {
    _schedulesFuture = widget.repository.getSchedulesByDay(_selectedDayIndex);
  }

  Future<void> _deleteSchedule(ScheduleItem item) async {
    final success = await widget.repository.deleteSchedule(item.id);
    if (!mounted) return;
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Xóa lịch thành công')),
      );
      setState(() {
        _loadSchedules();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Xóa lịch thất bại, vui lòng thử lại')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.repository.currentUser.role.toLowerCase() == 'quản trị viên' || 
                    widget.repository.currentUser.role.toLowerCase() == 'admin';

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isAdmin ? FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateScheduleScreen(repository: widget.repository),
            ),
          );
          if (result == true) {
            setState(() {
              _loadSchedules();
            });
            // Update local notifications for the newly created schedules
            widget.repository.getMySchedules().then((mySchedules) async {
              final notificationService = NotificationService();
              await notificationService.cancelAll();
              for (final item in mySchedules) {
                if (!item.isPassed) {
                  await notificationService.scheduleScheduleNotification(item);
                }
              }
            }).catchError((e) {
              print("Lỗi update notifications: $e");
            });
          }
        },
        backgroundColor: const Color(0xFF2563EB),
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
      body: FutureBuilder<List<ScheduleItem>>(
        future: _schedulesFuture,
        builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final schedules = snapshot.data ?? [];

        // Tách lịch theo buổi.
        final morningItems = _filterBySession(schedules, 'morning');
        final afternoonItems = _filterBySession(schedules, 'afternoon');
        final eveningItems = _filterBySession(schedules, 'evening');

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            AppHeader(
              title: widget.isAdmin ? 'LỊCH TOÀN TRƯỜNG' : 'LỊCH TUẦN',
              subtitle: 'Từ 08/6 - 14/6/2026',
              icon: Icons.calendar_month,
              accentColor: const Color(0xFF2563EB),
            ),

            const SizedBox(height: 16),

            DaySelector(
              selectedDayIndex: _selectedDayIndex,
              onChanged: (value) {
                setState(() {
                  _selectedDayIndex = value;
                  _loadSchedules();
                });
              },
            ),

            const SizedBox(height: 18),

            ScheduleSummaryCard(
              totalCount: schedules.length,
              morningCount: morningItems.length,
              afternoonCount: afternoonItems.length,
              eveningCount: eveningItems.length,
              accentColor: const Color(0xFF2563EB),
              title: 'Tổng quan lịch tuần',
              subtitle: 'Thống kê theo ngày đang chọn',
            ),

            const SizedBox(height: 18),

            if (schedules.isEmpty)
              const EmptyState(
                icon: Icons.event_busy,
                title: 'Không có lịch',
                message: 'Ngày này chưa có lịch công tác hoặc lịch giảng dạy.',
              )
            else ...[
              SessionSection(
                title: 'SÁNG',
                icon: Icons.wb_sunny,
                items: morningItems,
                accentColor: const Color(0xFF2563EB),
                isAdmin: widget.isAdmin,
                onDelete: _deleteSchedule,
              ),
              SessionSection(
                title: 'CHIỀU',
                icon: Icons.brightness_5,
                items: afternoonItems,
                accentColor: const Color(0xFFF97316),
                isAdmin: widget.isAdmin,
                onDelete: _deleteSchedule,
              ),
              SessionSection(
                title: 'TỐI',
                icon: Icons.nights_stay,
                items: eveningItems,
                accentColor: const Color(0xFF7C3AED),
                isAdmin: widget.isAdmin,
                onDelete: _deleteSchedule,
              ),
            ],
          ],
        );
      },
    ),
    );
  }

  List<ScheduleItem> _filterBySession(
      List<ScheduleItem> items,
      String session,
      ) {
    return items.where((item) => item.session == session).toList();
  }
}
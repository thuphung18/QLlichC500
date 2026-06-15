import 'package:flutter/material.dart';

import '../models/schedule_item.dart';
import '../repositories/schedule_repository.dart';
import '../widgets/app_header.dart';
import '../widgets/day_selector.dart';
import '../widgets/empty_state.dart';
import '../widgets/schedule_summary_card.dart';
import '../widgets/session_section.dart';

// MyScheduleScreen là màn hình "Lịch của tôi".
// Dữ liệu lấy từ repository.getMySchedules().
// Repository sẽ tự lọc lịch theo user đang đăng nhập.
class MyScheduleScreen extends StatefulWidget {
  final ScheduleRepository repository;

  const MyScheduleScreen({
    super.key,
    required this.repository,
  });

  @override
  State<MyScheduleScreen> createState() => _MyScheduleScreenState();
}

class _MyScheduleScreenState extends State<MyScheduleScreen> {
  int _selectedDayIndex = 2;
  Future<List<ScheduleItem>>? _schedulesFuture;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  void _loadSchedules() {
    // Gọi API một lần, sau đó filter theo thứ bên dưới build (để tránh gọi nhiều lần nếu API không hỗ trợ filter)
    // Hoặc có thể filter ngay khi nhận kết quả
    _schedulesFuture = widget.repository.getMySchedules().then(
          (schedules) => schedules.where((item) => item.dayIndex == _selectedDayIndex).toList(),
    );
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
    return FutureBuilder<List<ScheduleItem>>(
      future: _schedulesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final schedules = snapshot.data ?? [];

        final morningItems = _filterBySession(schedules, 'morning');
        final afternoonItems = _filterBySession(schedules, 'afternoon');
        final eveningItems = _filterBySession(schedules, 'evening');
        
        final isAdmin = widget.repository.currentUser.role.toLowerCase() == 'quản trị viên' || 
                        widget.repository.currentUser.role.toLowerCase() == 'admin';

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const AppHeader(
              title: 'LỊCH CỦA TÔI',
              subtitle: 'Các lịch có liên quan trực tiếp đến bạn',
              icon: Icons.person_pin_circle,
              accentColor: Color(0xFF2563EB),
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
              title: 'Tổng quan lịch của tôi',
              subtitle: 'Thống kê các lịch liên quan trực tiếp đến bạn',
            ),

            const SizedBox(height: 18),

            if (schedules.isEmpty)
              const EmptyState(
                icon: Icons.person_off,
                title: 'Bạn chưa có lịch',
                message: 'Ngày này chưa có lịch cá nhân nào.',
              )
            else ...[
              SessionSection(
                title: 'SÁNG',
                icon: Icons.wb_sunny,
                items: morningItems,
                accentColor: const Color(0xFF2563EB),
                isAdmin: isAdmin,
                onDelete: _deleteSchedule,
              ),
              SessionSection(
                title: 'CHIỀU',
                icon: Icons.brightness_5,
                items: afternoonItems,
                accentColor: const Color(0xFFF97316),
                isAdmin: isAdmin,
                onDelete: _deleteSchedule,
              ),
              SessionSection(
                title: 'TỐI',
                icon: Icons.nights_stay,
                items: eveningItems,
                accentColor: const Color(0xFF7C3AED),
                isAdmin: isAdmin,
                onDelete: _deleteSchedule,
              ),
            ],
          ],
        );
      },
    );
  }

  List<ScheduleItem> _filterBySession(
      List<ScheduleItem> items,
      String session,
      ) {
    return items.where((item) => item.session == session).toList();
  }
}
import 'package:flutter/material.dart';

import '../models/schedule_item.dart';
import '../repositories/schedule_repository.dart';
import '../widgets/app_header.dart';
import '../widgets/day_selector.dart';
import '../widgets/empty_state.dart';
import '../widgets/schedule_summary_card.dart';
import '../widgets/session_section.dart';
import 'create_schedule_screen.dart';

// DepartmentScheduleScreen là màn hình "Lịch khoa".
// Không fix cứng Khoa Công nghệ thông tin nữa.
// departmentName được truyền từ user đang đăng nhập.
class DepartmentScheduleScreen extends StatefulWidget {
  final ScheduleRepository repository;
  final String departmentName;

  const DepartmentScheduleScreen({
    super.key,
    required this.repository,
    required this.departmentName,
  });

  @override
  State<DepartmentScheduleScreen> createState() {
    return _DepartmentScheduleScreenState();
  }
}

class _DepartmentScheduleScreenState extends State<DepartmentScheduleScreen> {
  int _selectedDayIndex = 2;
  Future<List<ScheduleItem>>? _schedulesFuture;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  void _loadSchedules() {
    _schedulesFuture = widget.repository.getDepartmentSchedules().then(
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
          }
        },
        backgroundColor: const Color(0xFF0F766E),
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
      body: FutureBuilder<List<ScheduleItem>>(
        future: _schedulesFuture,
        builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final schedules = snapshot.data ?? [];

        final morningItems = _filterBySession(schedules, 'morning');
        final afternoonItems = _filterBySession(schedules, 'afternoon');
        final eveningItems = _filterBySession(schedules, 'evening');

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            AppHeader(
              title: 'LỊCH CỦA KHOA',
              subtitle: 'Lịch chung của ${widget.departmentName}',
              icon: Icons.business,
              accentColor: const Color(0xFF0F766E),
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
              accentColor: const Color(0xFF0F766E),
              title: 'Tổng quan lịch khoa',
              subtitle: 'Thống kê lịch chung của khoa theo ngày',
            ),

            const SizedBox(height: 18),

            if (schedules.isEmpty)
              const EmptyState(
                icon: Icons.business,
                title: 'Chưa có lịch của khoa',
                message: 'Ngày này khoa chưa có lịch công tác chung.',
              )
            else ...[
              SessionSection(
                title: 'SÁNG',
                icon: Icons.wb_sunny,
                items: morningItems,
                accentColor: const Color(0xFF0F766E),
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
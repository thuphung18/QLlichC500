import 'package:flutter/material.dart';

import '../models/schedule_item.dart';
import '../repositories/schedule_repository.dart';
import '../utils/role_helper.dart';
import '../widgets/app_header.dart';
import '../widgets/day_selector.dart';
import '../widgets/empty_state.dart';
import '../widgets/schedule_summary_card.dart';
import '../widgets/session_section.dart';
import '../theme/app_colors.dart';
import 'dart:async';
import '../services/notification_service.dart';
import '../utils/calendar_export_helper.dart';
import '../utils/event_bus.dart';
import '../utils/app_state.dart';

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
  Future<List<ScheduleItem>>? _schedulesFuture;
  late StreamSubscription<String> _eventSubscription;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
    AppState().selectedDayNotifier.addListener(_onDayChanged);
    _eventSubscription = EventBus().onScheduleDeleted.listen((_) {
      if (mounted) {
        setState(() {
          _loadSchedules();
        });
      }
    });
  }

  void _onDayChanged() {
    if (mounted) {
      setState(() {
        _loadSchedules();
      });
    }
  }

  void _loadSchedules() {
    // Gọi API một lần, sau đó filter theo thứ bên dưới build (để tránh gọi nhiều lần nếu API không hỗ trợ filter)
    // Hoặc có thể filter ngay khi nhận kết quả
    _schedulesFuture = widget.repository.getMySchedules().then(
          (schedules) => schedules.where((item) => item.dayIndex == AppState().selectedDayNotifier.value).toList(),
    );
  }

  @override
  void dispose() {
    AppState().selectedDayNotifier.removeListener(_onDayChanged);
    _eventSubscription.cancel();
    super.dispose();
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
      // Đồng bộ lại thông báo cục bộ sau khi xóa lịch
      widget.repository.getMySchedules().then((mySchedules) async {
        final notificationService = NotificationService();
        await notificationService.updateScheduledNotifications(mySchedules);
      }).catchError((e) {
        print("Lỗi cập nhật thông báo sau khi xóa lịch: $e");
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Xóa lịch thất bại, vui lòng thử lại')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = RoleHelper.canManageSchedule(widget.repository.currentUser.role);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        AppHeader(
          title: 'LỊCH CỦA TÔI',
          subtitle: 'Các lịch có liên quan trực tiếp đến bạn',
          icon: Icons.person_pin_circle,
          accentColor: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Lịch trình cá nhân:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.bodyMedium?.color ?? const Color(0xFF64748B),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
                try {
                  final mySchedules = await widget.repository.getMySchedules();
                  if (context.mounted) Navigator.pop(context);
                  
                  if (mySchedules.isEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Không có lịch biểu cá nhân nào để xuất.')),
                      );
                    }
                    return;
                  }
                  
                  await CalendarExportHelper.exportToIcs(mySchedules, 'lich_ca_nhan.ics');
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi xuất lịch cá nhân: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Tải lịch cá nhân (.ics)', style: TextStyle(fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DaySelector(
          selectedDayIndex: AppState().selectedDayNotifier.value,
          onChanged: (value) {
            if (AppState().selectedDayNotifier.value != value) {
              AppState().selectedDayNotifier.value = value;
            }
          },
        ),
        const SizedBox(height: 18),
        FutureBuilder<List<ScheduleItem>>(
          future: _schedulesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 50),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final schedules = snapshot.data ?? [];
            final morningItems = _filterBySession(schedules, 'morning');
            final afternoonItems = _filterBySession(schedules, 'afternoon');
            final eveningItems = _filterBySession(schedules, 'evening');

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ScheduleSummaryCard(
                  totalCount: schedules.length,
                  morningCount: morningItems.length,
                  afternoonCount: afternoonItems.length,
                  eveningCount: eveningItems.length,
                  accentColor: Theme.of(context).colorScheme.primary,
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
                    accentColor: Theme.of(context).colorScheme.primary,
                    isAdmin: canManage,
                    onDelete: _deleteSchedule,
                  ),
                  SessionSection(
                    title: 'CHIỀU',
                    icon: Icons.brightness_5,
                    items: afternoonItems,
                    accentColor: AppColors.warning,
                    isAdmin: canManage,
                    onDelete: _deleteSchedule,
                  ),
                  SessionSection(
                    title: 'TỐI',
                    icon: Icons.nights_stay,
                    items: eveningItems,
                    accentColor: const Color(0xFF7C3AED),
                    isAdmin: canManage,
                    onDelete: _deleteSchedule,
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  List<ScheduleItem> _filterBySession(
      List<ScheduleItem> items,
      String session,
      ) {
    return items.where((item) => item.session == session).toList();
  }
}
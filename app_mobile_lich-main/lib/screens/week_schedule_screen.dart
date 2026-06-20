import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/create_schedule_request.dart';
import '../models/schedule_item.dart';
import '../repositories/schedule_repository.dart';
import '../utils/role_helper.dart';
import '../widgets/app_header.dart';
import '../widgets/day_selector.dart';
import '../widgets/empty_state.dart';
import '../widgets/schedule_summary_card.dart';
import '../widgets/session_section.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import 'create_schedule_screen.dart';
import 'review_imported_schedule_screen.dart';
import 'package:file_picker/file_picker.dart';
import '../data/api_schedule_repository.dart';
import 'dart:async';
import '../utils/event_bus.dart';
import '../utils/app_state.dart';

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
    _schedulesFuture = widget.repository.getSchedulesByDay(AppState().selectedDayNotifier.value);
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Xóa lịch thất bại, vui lòng thử lại')),
      );
    }
  }

  Future<void> _importPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'xlsx'],
        withData: true,
      );

      if (result != null) {
        if (!mounted) return;
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('AI đang đọc và xử lý tài liệu...'),
                  ],
                ),
              ),
            ),
          ),
        );

        final repo = widget.repository as ApiScheduleRepository;
        List<CreateScheduleRequest> previewSchedules;
        
        if (kIsWeb) {
          previewSchedules = await repo.uploadScheduleFileBytes(result.files.single.bytes!, result.files.single.name);
        } else {
          previewSchedules = await repo.uploadScheduleFile(result.files.single.path!);
        }

        if (!mounted) return;
        Navigator.pop(context); // Tắt loading

        if (previewSchedules.isNotEmpty) {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReviewImportedScheduleScreen(
                importedSchedules: previewSchedules,
                currentUser: widget.repository.currentUser,
              ),
            ),
          );
          if (res == true) {
            setState(() {
              _loadSchedules();
            });
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể nhận diện lịch hoặc có lỗi xảy ra.')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      // Kiểm tra nếu loading dialog đang hiện thì tắt đi, tránh tắt nhầm màn hình chính
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = RoleHelper.canManageSchedule(widget.repository.currentUser.role);
    final isAdmin = RoleHelper.isAdmin(widget.repository.currentUser.role);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: canManage ? Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'importFab',
            onPressed: _importPdf,
            backgroundColor: AppColors.accentLight,
            icon: const Icon(Icons.auto_awesome, color: Colors.white),
            label: const Text('Import AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'createFab',
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
            backgroundColor: Theme.of(context).colorScheme.primary,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Thêm thủ công', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ) : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          AppHeader(
            title: widget.isAdmin ? 'LỊCH TOÀN TRƯỜNG' : 'LỊCH TUẦN',
            subtitle: 'Từ 08/6 - 14/6/2026',
            icon: Icons.calendar_month,
            accentColor: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
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
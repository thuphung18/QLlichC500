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
import '../utils/calendar_export_helper.dart';
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

  Future<void> _importPdf() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
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
            // Đồng bộ lại thông báo cục bộ sau khi import AI thành công
            widget.repository.getMySchedules().then((mySchedules) async {
              final notificationService = NotificationService();
              await notificationService.updateScheduledNotifications(mySchedules);
            }).catchError((e) {
              print("Lỗi cập nhật thông báo sau khi import: $e");
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

  Future<void> _clearAllSchedules() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa toàn bộ lịch?'),
        content: const Text('Hành động này sẽ xóa vĩnh viễn toàn bộ lịch (thuộc quyền quản lý của bạn). Bạn có chắc chắn muốn tiếp tục?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa tất cả'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final success = await widget.repository.clearAllSchedules();
    if (!mounted) return;
    Navigator.pop(context); // Tắt loading

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa toàn bộ lịch thành công')),
      );
      setState(() {
        _loadSchedules();
      });
      widget.repository.getMySchedules().then((mySchedules) async {
        final notificationService = NotificationService();
        await notificationService.updateScheduledNotifications(mySchedules);
      }).catchError((e) {
        print("Lỗi cập nhật thông báo: $e");
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Xóa thất bại, vui lòng thử lại')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = RoleHelper.canManageSchedule(widget.repository.currentUser.role);

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
                  await notificationService.updateScheduledNotifications(mySchedules);
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
            subtitle: _currentWeekRangeText(),
            icon: Icons.calendar_month,
            accentColor: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lịch trình tuần này:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.bodyMedium?.color ?? const Color(0xFF64748B),
                ),
              ),
              Row(
                children: [
                  if (canManage)
                    IconButton(
                      icon: const Icon(Icons.delete_sweep, color: Colors.red),
                      tooltip: 'Xóa toàn bộ lịch',
                      onPressed: _clearAllSchedules,
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
                        final allSchedules = await widget.repository.getAllSchedules();
                        if (context.mounted) Navigator.pop(context);
                        
                        if (allSchedules.isEmpty) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Không có lịch biểu nào trong tuần này để xuất.')),
                            );
                          }
                          return;
                        }
                        
                        final filename = widget.isAdmin ? 'lich_tuan_toan_truong.ics' : 'lich_tuan_ca_nhan.ics';
                        await CalendarExportHelper.exportToIcs(allSchedules, filename);
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Lỗi xuất lịch tuần: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Tải lịch tuần', style: TextStyle(fontWeight: FontWeight.bold)),
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

  // Hàm format ngày ngắn để hiển thị trên header.
  // Ví dụ: DateTime(2026, 6, 29) -> "29/6"
  String _formatShortDate(DateTime date) {
    return '${date.day}/${date.month}';
  }

  // Hàm lấy khoảng tuần hiện tại theo thời gian thật của thiết bị.
  // Ví dụ:
  // Nếu hôm nay nằm trong tuần 29/6 - 5/7/2026
  // thì hàm này trả về: "Từ 29/6 - 5/7/2026"
  String _currentWeekRangeText() {
    final today = DateTime.now();

    final currentDate = DateTime(
      today.year,
      today.month,
      today.day,
    );

    final monday = currentDate.subtract(
      Duration(days: currentDate.weekday - DateTime.monday),
    );

    final sunday = monday.add(const Duration(days: 6));

    // Nếu tuần nằm trong cùng một năm thì chỉ cần hiện năm ở cuối.
    if (monday.year == sunday.year) {
      return 'Từ ${_formatShortDate(monday)} - ${_formatShortDate(sunday)}/${sunday.year}';
    }

    // Nếu tuần vắt qua năm mới, ví dụ 30/12/2026 - 05/01/2027,
    // thì hiện đủ năm cho cả 2 đầu để tránh nhầm.
    return 'Từ ${_formatShortDate(monday)}/${monday.year} - ${_formatShortDate(sunday)}/${sunday.year}';
  }

  List<ScheduleItem> _filterBySession(
      List<ScheduleItem> items,
      String session,
      ) {
    return items.where((item) => item.session == session).toList();
  }
}
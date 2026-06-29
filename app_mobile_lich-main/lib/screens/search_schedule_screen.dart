import 'package:flutter/material.dart';

import '../models/schedule_item.dart';
import '../repositories/schedule_repository.dart';
import '../utils/role_helper.dart';
import '../widgets/app_header.dart';
import '../widgets/empty_state.dart';
import '../widgets/schedule_card.dart';
import '../theme/app_colors.dart';
import 'schedule_detail_screen.dart';
import 'dart:async';
import '../utils/event_bus.dart';

// SearchScheduleScreen là màn hình tìm kiếm lịch.
// Người dùng có thể tìm theo tên lịch, phòng, đơn vị, người phụ trách...
class SearchScheduleScreen extends StatefulWidget {
  final ScheduleRepository repository;

  const SearchScheduleScreen({
    super.key,
    required this.repository,
  });

  @override
  State<SearchScheduleScreen> createState() => _SearchScheduleScreenState();
}

class _SearchScheduleScreenState extends State<SearchScheduleScreen> {
  final TextEditingController _controller = TextEditingController();

  String _keyword = '';
  List<ScheduleItem>? _allSchedules;
  List<ScheduleItem> _displayedSchedules = [];
  bool _isLoading = true;
  late StreamSubscription<String> _eventSubscription;

  @override
  void initState() {
    super.initState();
    _loadAllSchedules();
    _eventSubscription = EventBus().onScheduleDeleted.listen((_) {
      if (mounted) {
        _loadAllSchedules();
      }
    });
  }

  Future<void> _loadAllSchedules() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Tải sẵn toàn bộ lịch (hoặc lịch cá nhân) để filter local cho mượt mà
      final schedules = await widget.repository.searchSchedules("");
      if (!mounted) return;
      setState(() {
        _allSchedules = schedules;
        _isLoading = false;
        _filterSchedules();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể tải dữ liệu tìm kiếm')),
      );
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _keyword = query;
      _filterSchedules();
    });
  }

  void _filterSchedules() {
    if (_allSchedules == null) return;

    if (_keyword.trim().isEmpty) {
      _displayedSchedules = List.from(_allSchedules!);
      return;
    }

    final kw = _keyword.toLowerCase().trim();
    _displayedSchedules = _allSchedules!.where((item) {
      return item.title.toLowerCase().contains(kw) ||
             item.teacher.toLowerCase().contains(kw) ||
             item.room.toLowerCase().contains(kw) ||
             item.unit.toLowerCase().contains(kw) ||
             item.departmentName.toLowerCase().contains(kw) ||
             item.participants.any((p) => p.toLowerCase().contains(kw));
    }).toList();
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _deleteSchedule(ScheduleItem item) async {
    final success = await widget.repository.deleteSchedule(item.id);
    if (!mounted) return;
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Xóa lịch thành công')),
      );
      _loadAllSchedules(); // Reload data
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
          title: 'TÌM KIẾM',
          subtitle: 'Tra cứu lịch theo tên, phòng, đơn vị hoặc người phụ trách',
          icon: Icons.search,
          accentColor: Theme.of(context).colorScheme.primary,
        ),

        const SizedBox(height: 16),

        TextField(
          controller: _controller,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Nhập từ khóa tìm kiếm...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withAlpha(12)
                : AppColors.backgroundLight,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),

        const SizedBox(height: 18),

        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_displayedSchedules.isEmpty)
          const EmptyState(
            icon: Icons.manage_search,
            title: 'Không tìm thấy lịch',
            message: 'Thử nhập từ khóa khác để tìm kiếm.',
          )
        else
          ..._displayedSchedules.map(
                (item) => ScheduleCard(
              item: item,
              accentColor: _getColorByItem(item, context),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ScheduleDetailScreen(
                      item: item,
                      accentColor: _getColorByItem(item, context),
                      isAdmin: canManage,
                      onDelete: () => _deleteSchedule(item),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Color _getColorByItem(ScheduleItem item, BuildContext context) {
    if (item.isMine) {
      return Theme.of(context).colorScheme.primary;
    }

    if (item.isDepartment) {
      return AppColors.success;
    }

    return AppColors.accentLight;
  }
}
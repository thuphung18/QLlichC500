import 'package:flutter/material.dart';

import '../models/schedule_item.dart';
import '../repositories/schedule_repository.dart';
import '../widgets/app_header.dart';
import '../widgets/empty_state.dart';
import '../widgets/schedule_card.dart';
import 'schedule_detail_screen.dart';

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
  Future<List<ScheduleItem>>? _schedulesFuture;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  void _loadSchedules() {
    _schedulesFuture = widget.repository.searchSchedules(_keyword);
  }

  @override
  void dispose() {
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
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final results = snapshot.data ?? [];
        
        final isAdmin = widget.repository.currentUser.role.toLowerCase() == 'quản trị viên' || 
                        widget.repository.currentUser.role.toLowerCase() == 'admin';

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const AppHeader(
              title: 'TÌM KIẾM',
              subtitle: 'Tra cứu lịch theo tên, phòng, đơn vị hoặc người phụ trách',
              icon: Icons.search,
              accentColor: Color(0xFF7C3AED),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _controller,
              onChanged: (value) {
                setState(() {
                  _keyword = value;
                  _loadSchedules();
                });
              },
              decoration: InputDecoration(
                hintText: 'Nhập từ khóa tìm kiếm...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 18),

            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (results.isEmpty)
              const EmptyState(
                icon: Icons.manage_search,
                title: 'Không tìm thấy lịch',
                message: 'Thử nhập từ khóa khác để tìm kiếm.',
              )
            else
              ...results.map(
                    (item) => ScheduleCard(
                  item: item,
                  accentColor: _getColorByItem(item),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ScheduleDetailScreen(
                          item: item,
                          accentColor: _getColorByItem(item),
                          isAdmin: isAdmin,
                          onDelete: () => _deleteSchedule(item),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Color _getColorByItem(ScheduleItem item) {
    if (item.isMine) {
      return const Color(0xFF2563EB);
    }

    if (item.isDepartment) {
      return const Color(0xFF0F766E);
    }

    return const Color(0xFF7C3AED);
  }
}
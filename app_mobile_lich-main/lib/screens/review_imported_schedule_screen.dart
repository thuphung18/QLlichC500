import 'package:flutter/material.dart';
import '../data/api_schedule_repository.dart';
import '../models/create_schedule_request.dart';
import '../models/user_profile.dart';
import '../theme/app_colors.dart';

class ReviewImportedScheduleScreen extends StatefulWidget {
  final List<CreateScheduleRequest> importedSchedules;
  final UserProfile currentUser;

  const ReviewImportedScheduleScreen({
    super.key,
    required this.importedSchedules,
    required this.currentUser,
  });

  @override
  State<ReviewImportedScheduleScreen> createState() => _ReviewImportedScheduleScreenState();
}

class _ReviewImportedScheduleScreenState extends State<ReviewImportedScheduleScreen> {
  late List<CreateScheduleRequest> _schedules;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Copy danh sách để có thể chỉnh sửa nội bộ
    _schedules = List.from(widget.importedSchedules);
  }

  void _removeSchedule(int index) {
    setState(() {
      _schedules.removeAt(index);
    });
  }

  Future<void> _saveAll() async {
    if (_schedules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có lịch nào để lưu!')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final repo = ApiScheduleRepository(currentUser: widget.currentUser);
    final success = await repo.bulkCreateSchedules(_schedules);

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu thành công các lịch vào hệ thống!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true); // Trả về true để màn hình trước reload lại danh sách
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Có lỗi xảy ra khi lưu lịch!'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Duyệt Lịch Nhập Tự Động'),
        actions: [
          if (_schedules.isNotEmpty)
            TextButton.icon(
              onPressed: _isSaving ? null : _saveAll,
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(
                _isSaving ? 'Đang lưu...' : 'Lưu tất cả (${_schedules.length})',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
        ],
      ),
      body: _schedules.isEmpty
          ? const Center(child: Text('Danh sách lịch trống.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _schedules.length,
              itemBuilder: (context, index) {
                final schedule = _schedules[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                schedule.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeSchedule(index),
                              tooltip: 'Xóa lịch này',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.calendar_today, 'Ngày', schedule.scheduleDate),
                        _buildInfoRow(Icons.access_time, 'Thời gian', '${schedule.startTime} - ${schedule.endTime}'),
                        _buildInfoRow(Icons.person, 'Chủ trì', schedule.teacher),
                        if (schedule.room.isNotEmpty) _buildInfoRow(Icons.location_on, 'Địa điểm', schedule.room),
                        if (schedule.note != null && schedule.note!.isNotEmpty)
                          _buildInfoRow(Icons.info_outline, 'Ghi chú / Thành phần dự', schedule.note!),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withAlpha(25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Loại lịch: ${schedule.category} | Phòng ban ID: ${schedule.departmentId.isEmpty ? "Trống" : schedule.departmentId}',
                            style: const TextStyle(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: Colors.grey[800], fontSize: 14),
                children: [
                  TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

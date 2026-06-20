import 'package:flutter/material.dart';
import '../data/api_schedule_repository.dart';
import '../models/create_schedule_request.dart';
import '../models/user_profile.dart';
import '../models/department.dart';
import '../models/user_compact.dart';
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

  List<Department> _departments = [];
  List<UserCompact> _users = [];
  bool _isLoadingMetadata = true;

  @override
  void initState() {
    super.initState();
    // Copy danh sách để có thể chỉnh sửa nội bộ
    _schedules = List.from(widget.importedSchedules);
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    try {
      final repo = ApiScheduleRepository(currentUser: widget.currentUser);
      final formData = await repo.getFormData();
      setState(() {
        _departments = formData.departments;
        _users = formData.users;
        _isLoadingMetadata = false;
      });
    } catch (e) {
      print("Error loading metadata: $e");
      setState(() {
        _isLoadingMetadata = false;
      });
    }
  }

  void _removeSchedule(int index) {
    setState(() {
      _schedules.removeAt(index);
    });
  }

  Future<void> _editSchedule(int index) async {
    if (_isLoadingMetadata) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang tải danh sách phòng ban và người dùng, vui lòng đợi...')),
      );
      return;
    }

    final schedule = _schedules[index];
    final updatedSchedule = await showDialog<CreateScheduleRequest>(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditScheduleDialog(
        schedule: schedule,
        departments: _departments,
        users: _users,
      ),
    );

    if (updatedSchedule != null) {
      setState(() {
        _schedules[index] = updatedSchedule;
      });
    }
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
                
                // Tìm tên phòng ban hiển thị cho trực quan
                String deptName = schedule.departmentId;
                if (_departments.isNotEmpty) {
                  final dept = _departments.firstWhere((d) => d.id == schedule.departmentId, orElse: () => Department(id: '', name: ''));
                  if (dept.name.isNotEmpty) {
                    deptName = dept.name;
                  }
                }

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
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editSchedule(index),
                              tooltip: 'Chỉnh sửa lịch này',
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
                            'Loại lịch: ${schedule.category} | Phòng ban: $deptName',
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

class EditScheduleDialog extends StatefulWidget {
  final CreateScheduleRequest schedule;
  final List<Department> departments;
  final List<UserCompact> users;

  const EditScheduleDialog({
    super.key,
    required this.schedule,
    required this.departments,
    required this.users,
  });

  @override
  State<EditScheduleDialog> createState() => _EditScheduleDialogState();
}

class _EditScheduleDialogState extends State<EditScheduleDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _teacherController;
  late TextEditingController _roomController;
  late TextEditingController _noteController;
  late TextEditingController _unitController;
  late TextEditingController _categoryController;

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  String? _selectedDepartmentId;
  final Set<String> _selectedUserIds = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.schedule.title);
    _teacherController = TextEditingController(text: widget.schedule.teacher);
    _roomController = TextEditingController(text: widget.schedule.room);
    _noteController = TextEditingController(text: widget.schedule.note ?? '');
    _unitController = TextEditingController(text: widget.schedule.unit);
    _categoryController = TextEditingController(text: widget.schedule.category);

    // Parse date
    if (widget.schedule.scheduleDate.isNotEmpty) {
      try {
        _selectedDate = DateTime.parse(widget.schedule.scheduleDate);
      } catch (_) {
        _selectedDate = DateTime.now();
      }
    } else {
      _selectedDate = DateTime.now();
    }

    // Parse times
    _startTime = _parseTimeOfDay(widget.schedule.startTime);
    _endTime = _parseTimeOfDay(widget.schedule.endTime);

    // Set department
    if (widget.schedule.departmentId.isNotEmpty) {
      final exists = widget.departments.any((d) => d.id == widget.schedule.departmentId);
      if (exists) {
        _selectedDepartmentId = widget.schedule.departmentId;
      } else if (widget.departments.isNotEmpty) {
        _selectedDepartmentId = widget.departments.first.id;
      }
    } else if (widget.departments.isNotEmpty) {
      _selectedDepartmentId = widget.departments.first.id;
    }

    // Set participants
    _selectedUserIds.addAll(widget.schedule.participantUserIds);
  }

  TimeOfDay? _parseTimeOfDay(String timeStr) {
    if (timeStr.isEmpty) return null;
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (_) {}
    return null;
  }

  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return '';
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _teacherController.dispose();
    _roomController.dispose();
    _noteController.dispose();
    _unitController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final TimeOfDay initialTime = isStart 
        ? (_startTime ?? TimeOfDay.now())
        : (_endTime ?? TimeOfDay.now());
        
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null || _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn đầy đủ ngày và giờ')),
      );
      return;
    }

    final updated = CreateScheduleRequest(
      title: _titleController.text,
      teacher: _teacherController.text,
      room: _roomController.text,
      scheduleDate: _formatDate(_selectedDate),
      startTime: _formatTimeOfDay(_startTime),
      endTime: _formatTimeOfDay(_endTime),
      note: _noteController.text.isNotEmpty ? _noteController.text : null,
      unit: _unitController.text,
      departmentId: _selectedDepartmentId ?? '',
      category: _categoryController.text,
      participantUserIds: _selectedUserIds.toList(),
    );

    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chỉnh sửa thông tin lịch', style: TextStyle(fontWeight: FontWeight.bold)),
      content: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Tiêu đề sự kiện', border: OutlineInputBorder()),
                  validator: (value) => value == null || value.isEmpty ? 'Không được để trống' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _teacherController,
                        decoration: const InputDecoration(labelText: 'Chủ trì', border: OutlineInputBorder()),
                        validator: (value) => value == null || value.isEmpty ? 'Không được để trống' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _roomController,
                        decoration: const InputDecoration(labelText: 'Phòng/Địa điểm', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _selectDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Ngày', border: OutlineInputBorder()),
                          child: Text(_selectedDate == null ? 'Chọn ngày' : _formatDate(_selectedDate)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(true),
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Bắt đầu', border: OutlineInputBorder()),
                          child: Text(_startTime == null ? 'Chọn giờ' : _formatTimeOfDay(_startTime)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(false),
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Kết thúc', border: OutlineInputBorder()),
                          child: Text(_endTime == null ? 'Chọn giờ' : _formatTimeOfDay(_endTime)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (widget.departments.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Khoa/Phòng ban', border: OutlineInputBorder()),
                    value: _selectedDepartmentId,
                    items: widget.departments.map((d) {
                      return DropdownMenuItem(value: d.id, child: Text(d.name));
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedDepartmentId = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _unitController,
                        decoration: const InputDecoration(labelText: 'Đơn vị tổ chức', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _categoryController,
                        decoration: const InputDecoration(labelText: 'Danh mục', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(labelText: 'Ghi chú / Thành phần dự', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                if (widget.users.isNotEmpty) ...[
                  const Text('Thành phần tham dự:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Tìm kiếm người tham dự...',
                      prefixIcon: Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim().toLowerCase();
                      });
                    },
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
                    height: 120,
                    child: Builder(
                      builder: (context) {
                        final filteredUsers = widget.users
                            .where((u) => u.fullName.toLowerCase().contains(_searchQuery))
                            .toList();
                            
                        if (filteredUsers.isEmpty) {
                          return const Center(
                            child: Text('Không tìm thấy kết quả', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          );
                        }
                        
                        return ListView.builder(
                          itemCount: filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            return CheckboxListTile(
                              dense: true,
                              title: Text(user.fullName, style: const TextStyle(fontSize: 13)),
                              subtitle: Text(user.departmentId, style: const TextStyle(fontSize: 11)),
                              value: _selectedUserIds.contains(user.id),
                              onChanged: (bool? checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedUserIds.add(user.id);
                                  } else {
                                    _selectedUserIds.remove(user.id);
                                  }
                                });
                              },
                            );
                          },
                        );
                      }
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _onSave,
          child: const Text('Cập nhật'),
        ),
      ],
    );
  }
}


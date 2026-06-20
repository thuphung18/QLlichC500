import 'package:flutter/material.dart';
import '../models/create_schedule_request.dart';
import '../models/department.dart';
import '../models/user_compact.dart';
import '../repositories/schedule_repository.dart';

class CreateScheduleScreen extends StatefulWidget {
  final ScheduleRepository repository;

  const CreateScheduleScreen({super.key, required this.repository});

  @override
  State<CreateScheduleScreen> createState() => _CreateScheduleScreenState();
}

class _CreateScheduleScreenState extends State<CreateScheduleScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;

  List<Department> _departments = [];
  List<UserCompact> _users = [];

  // Form Fields
  final _titleController = TextEditingController();
  final _teacherController = TextEditingController();
  final _roomController = TextEditingController();
  final _noteController = TextEditingController();
  final _unitController = TextEditingController();
  final _categoryController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  String? _selectedDepartmentId;
  final Set<String> _selectedUserIds = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFormData();
  }

  Future<void> _loadFormData() async {
    try {
      final formData = await widget.repository.getFormData();
      setState(() {
        _departments = formData.departments;
        _users = formData.users;
        if (_departments.isNotEmpty) {
          _selectedDepartmentId = _departments.first.id;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi tải dữ liệu. Vui lòng thử lại.')),
        );
      }
    }
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
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
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

  Future<void> _saveSchedule() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedDate == null || _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ngày và giờ')),
      );
      return;
    }

    if (_selectedDepartmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn khoa/phòng ban')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final request = CreateScheduleRequest(
      title: _titleController.text,
      teacher: _teacherController.text,
      room: _roomController.text,
      scheduleDate: _formatDate(_selectedDate),
      startTime: _formatTimeOfDay(_startTime),
      endTime: _formatTimeOfDay(_endTime),
      note: _noteController.text.isNotEmpty ? _noteController.text : null,
      unit: _unitController.text,
      departmentId: _selectedDepartmentId!,
      category: _categoryController.text,
      participantUserIds: _selectedUserIds.toList(),
    );

    final success = await widget.repository.createSchedule(request);

    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thêm lịch thành công')),
        );
        Navigator.pop(context, true); // Return true to signal refresh
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Có lỗi xảy ra khi lưu lịch')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm Lịch Mới'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600), // Responsive for Web
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(labelText: 'Tiêu đề sự kiện', border: OutlineInputBorder()),
                            validator: (value) => value == null || value.isEmpty ? 'Không được để trống' : null,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _teacherController,
                                  decoration: const InputDecoration(labelText: 'Giảng viên/Người chủ trì', border: OutlineInputBorder()),
                                  validator: (value) => value == null || value.isEmpty ? 'Không được để trống' : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _roomController,
                                  decoration: const InputDecoration(labelText: 'Phòng/Địa điểm', border: OutlineInputBorder()),
                                  validator: (value) => value == null || value.isEmpty ? 'Không được để trống' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
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
                                    decoration: const InputDecoration(labelText: 'Giờ bắt đầu', border: OutlineInputBorder()),
                                    child: Text(_startTime == null ? 'Chọn giờ' : _formatTimeOfDay(_startTime)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _selectTime(false),
                                  child: InputDecorator(
                                    decoration: const InputDecoration(labelText: 'Giờ kết thúc', border: OutlineInputBorder()),
                                    child: Text(_endTime == null ? 'Chọn giờ' : _formatTimeOfDay(_endTime)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(labelText: 'Khoa/Phòng ban', border: OutlineInputBorder()),
                            value: _selectedDepartmentId,
                            items: _departments.map((d) {
                              return DropdownMenuItem(value: d.id, child: Text(d.name));
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedDepartmentId = val;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _unitController,
                                  decoration: const InputDecoration(labelText: 'Đơn vị tổ chức', border: OutlineInputBorder()),
                                  validator: (value) => value == null || value.isEmpty ? 'Không được để trống' : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _categoryController,
                                  decoration: const InputDecoration(labelText: 'Danh mục', border: OutlineInputBorder()),
                                  validator: (value) => value == null || value.isEmpty ? 'Không được để trống' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _noteController,
                            decoration: const InputDecoration(labelText: 'Ghi chú', border: OutlineInputBorder()),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 24),
                          const Text('Thành phần tham dự:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          TextField(
                            decoration: const InputDecoration(
                              hintText: 'Tìm kiếm người tham dự...',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val.trim().toLowerCase();
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
                            height: 200,
                            child: Builder(
                              builder: (context) {
                                final filteredUsers = _users
                                    .where((user) => user.fullName.toLowerCase().contains(_searchQuery))
                                    .toList();
                                    
                                if (filteredUsers.isEmpty) {
                                  return const Center(
                                    child: Text('Không tìm thấy kết quả', style: TextStyle(color: Colors.grey)),
                                  );
                                }
                                
                                return ListView.builder(
                                  itemCount: filteredUsers.length,
                                  itemBuilder: (context, index) {
                                    final user = filteredUsers[index];
                                    return CheckboxListTile(
                                      title: Text(user.fullName),
                                      subtitle: Text(user.departmentId),
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
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 50,
                            child: FilledButton(
                              onPressed: _isSaving ? null : _saveSchedule,
                              child: _isSaving 
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text('Lưu Lịch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

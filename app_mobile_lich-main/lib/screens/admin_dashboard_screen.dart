import 'package:flutter/material.dart';

import '../data/api_user_repository.dart';
import '../models/department.dart';
import '../models/user_profile.dart';
import '../utils/role_helper.dart';
import '../theme/app_colors.dart';
import 'create_user_screen.dart';

/// [AdminDashboardScreen] - Màn hình quản trị hệ thống dành cho Admin.
/// Gồm 2 tab:
///   - Tab 1: Quản lý Tài khoản (danh sách user, khóa/mở khóa, sửa, xóa)
///   - Tab 2: Quản lý Phòng ban (danh sách phòng, thêm, đổi tên, xóa)
class AdminDashboardScreen extends StatefulWidget {
  final UserProfile adminProfile;

  const AdminDashboardScreen({super.key, required this.adminProfile});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final ApiUserRepository _userRepo;

  List<UserDetail> _users = [];
  List<Map<String, String>> _departments = [];
  bool _isLoadingUsers = true;
  bool _isLoadingDepts = true;

  @override
  void initState() {
    super.initState();
    _userRepo = ApiUserRepository(sessionToken: widget.adminProfile.sessionToken ?? '');
    final isManager = RoleHelper.isManager(widget.adminProfile.role);
    _tabController = TabController(length: isManager ? 1 : 2, vsync: this);
    _loadUsers();
    _loadDepartments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoadingUsers = true);
    final users = await _userRepo.getAllUsers(widget.adminProfile.id);
    if (mounted) setState(() { _users = users; _isLoadingUsers = false; });
  }

  Future<void> _loadDepartments() async {
    if (RoleHelper.isManager(widget.adminProfile.role)) {
      setState(() {
        _departments = [
          {
            'id': widget.adminProfile.departmentId,
            'name': widget.adminProfile.departmentName,
          }
        ];
        _isLoadingDepts = false;
      });
      return;
    }
    setState(() => _isLoadingDepts = true);
    final depts = await _userRepo.getDepartments(widget.adminProfile.id);
    if (mounted) setState(() { _departments = depts; _isLoadingDepts = false; });
  }

  // ---------- User management actions ----------

  void _navigateToCreateUser() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateUserScreen(currentUser: widget.adminProfile),
      ),
    );
    if (result == true) _loadUsers();
  }

  void _showEditUserDialog(UserDetail user) {
    final nameCtrl = TextEditingController(text: user.fullName);
    final emailCtrl = TextEditingController(text: user.email);
    final phoneCtrl = TextEditingController(text: user.phone);
    String selectedRole = user.role;
    String selectedDeptId = user.departmentId;
    bool isActive = user.isActive;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Chỉnh sửa: ${user.username}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField(nameCtrl, 'Họ và tên', Icons.person),
                  const SizedBox(height: 12),
                  _buildTextField(emailCtrl, 'Email', Icons.email),
                  const SizedBox(height: 12),
                  _buildTextField(phoneCtrl, 'Số điện thoại', Icons.phone),
                  const SizedBox(height: 12),
                  // Role dropdown
                  DropdownButtonFormField<String>(
                    value: RoleHelper.availableRoles.contains(selectedRole) ? selectedRole : null,
                    decoration: _inputDeco('Vai trò', Icons.manage_accounts),
                    items: RoleHelper.availableRoles.map((r) =>
                        DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (val) => setStateDialog(() => selectedRole = val ?? selectedRole),
                  ),
                  const SizedBox(height: 12),
                  // Department dropdown
                  DropdownButtonFormField<String>(
                    value: _departments.any((d) => d['id'] == selectedDeptId) ? selectedDeptId : null,
                    decoration: _inputDeco('Phòng ban', Icons.business),
                    items: _departments.map((d) =>
                        DropdownMenuItem(value: d['id'], child: Text(d['name'] ?? ''))).toList(),
                    onChanged: (val) => setStateDialog(() => selectedDeptId = val ?? selectedDeptId),
                  ),
                  const SizedBox(height: 12),
                  // Lock toggle
                  Row(
                    children: [
                      const Icon(Icons.lock, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Tài khoản hoạt động', style: TextStyle(fontWeight: FontWeight.w600))),
                      Switch(
                        value: isActive,
                        onChanged: user.id == widget.adminProfile.id
                            ? null // Không cho Admin tự khóa mình
                            : (val) => setStateDialog(() => isActive = val),
                        activeColor: AppColors.success,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final deptName = _departments.firstWhere(
                    (d) => d['id'] == selectedDeptId,
                    orElse: () => {'name': user.unit},
                  )['name'] ?? user.unit;

                  final success = await _userRepo.adminUpdateUser(
                    user.id,
                    AdminUpdateUserRequest(
                      fullName: nameCtrl.text.trim(),
                      role: selectedRole,
                      unit: deptName,
                      departmentId: selectedDeptId,
                      email: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                      phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                      isActive: isActive,
                    ),
                    widget.adminProfile.id,
                  );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(success ? 'Cập nhật thành công' : 'Cập nhật thất bại'),
                        backgroundColor: success ? AppColors.success : AppColors.error,
                      ));
                      if (success) _loadUsers();
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Lưu'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteUser(UserDetail user) {
    if (user.id == widget.adminProfile.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể xóa tài khoản của chính mình')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xác nhận xóa', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Bạn có chắc muốn xóa tài khoản "${user.fullName}" không?\nThao tác này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await _userRepo.deleteUser(user.id, widget.adminProfile.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(success ? 'Đã xóa tài khoản' : 'Xóa tài khoản thất bại'),
                  backgroundColor: success ? AppColors.success : AppColors.error,
                ));
                if (success) _loadUsers();
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  // ---------- Department management actions ----------

  void _showDeptDialog({String? id, String? currentName}) {
    final isEdit = id != null;
    final ctrl = TextEditingController(text: currentName ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isEdit ? 'Đổi tên phòng ban' : 'Thêm phòng ban mới',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: _inputDeco('Tên phòng ban', Icons.business),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              bool success;
              if (isEdit) {
                success = await _userRepo.updateDepartment(id!, name, widget.adminProfile.id);
              } else {
                success = await _userRepo.createDepartment(name, widget.adminProfile.id);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(success
                      ? (isEdit ? 'Đổi tên thành công' : 'Thêm phòng ban thành công')
                      : 'Thao tác thất bại'),
                  backgroundColor: success ? AppColors.success : AppColors.error,
                ));
                if (success) _loadDepartments();
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(isEdit ? 'Lưu' : 'Thêm'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteDept(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận xóa', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Xóa phòng ban "$name"?\nChỉ có thể xóa nếu không còn nhân sự nào.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final error = await _userRepo.deleteDepartment(id, widget.adminProfile.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(error == null ? 'Xóa phòng ban thành công' : 'Lỗi: $error'),
                  backgroundColor: error == null ? AppColors.success : AppColors.error,
                ));
                if (error == null) _loadDepartments();
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final isManager = RoleHelper.isManager(widget.adminProfile.role);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isManager ? 'Quản lý thành viên khoa' : 'Quản trị hệ thống',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: isManager
            ? null
            : TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(icon: Icon(Icons.group), text: 'Tài khoản'),
                  Tab(icon: Icon(Icons.business), text: 'Phòng ban'),
                ],
              ),
      ),
      body: isManager
          ? _buildUsersTab()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUsersTab(),
                _buildDeptsTab(),
              ],
            ),
    );
  }

  // ---------- Tab 1: Users ----------

  Widget _buildUsersTab() {
    if (_isLoadingUsers || _isLoadingDepts) {
      return const Center(child: CircularProgressIndicator());
    }

    // Nhóm user theo tên phòng ban
    Map<String, List<UserDetail>> groupedUsers = {};
    for (var user in _users) {
      final deptName = _departments.firstWhere(
        (d) => d['id'] == user.departmentId,
        orElse: () => {'name': user.unit.isNotEmpty ? user.unit : 'Chưa phân bổ'},
      )['name'] ?? (user.unit.isNotEmpty ? user.unit : 'Chưa phân bổ');

      if (!groupedUsers.containsKey(deptName)) {
        groupedUsers[deptName] = [];
      }
      groupedUsers[deptName]!.add(user);
    }

    final sortedDepts = groupedUsers.keys.toList()..sort();

    return Column(
      children: [
        // Header actions
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Tổng: ${_users.length} tài khoản',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF64748B)),
                ),
              ),
              FilledButton.icon(
                onPressed: _navigateToCreateUser,
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Tạo mới'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        // User list grouped by department
        Expanded(
          child: _users.isEmpty
              ? const Center(child: Text('Chưa có tài khoản nào', style: TextStyle(color: Color(0xFF64748B))))
              : RefreshIndicator(
                  onRefresh: () async {
                    await _loadDepartments();
                    await _loadUsers();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: sortedDepts.length,
                    itemBuilder: (ctx, i) {
                      final deptName = sortedDepts[i];
                      final deptUsers = groupedUsers[deptName]!;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 16, bottom: 12, left: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.business, size: 18, color: Color(0xFF64748B)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    deptName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withAlpha(20),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${deptUsers.length}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...deptUsers.map((u) => _buildUserCard(u)),
                        ],
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildUserCard(UserDetail user) {
    final isSelf = user.id == widget.adminProfile.id;
    final roleColor = RoleHelper.isAdmin(user.role)
        ? const Color(0xFF7C3AED)
        : RoleHelper.isManager(user.role)
            ? const Color(0xFFF97316)
            : Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10, offset: const Offset(0, 4))],
        border: user.isActive ? Border.all(color: Theme.of(context).brightness == Brightness.light ? AppColors.borderLight : AppColors.borderDark) : Border.all(color: AppColors.error.withAlpha(100), width: 1.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: roleColor.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            RoleHelper.isAdmin(user.role) ? Icons.admin_panel_settings
                : RoleHelper.isManager(user.role) ? Icons.manage_accounts
                : Icons.person,
            color: roleColor,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  overflow: TextOverflow.ellipsis),
            ),
            if (!user.isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Đã khóa', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text('@${user.username}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: roleColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(user.role, style: TextStyle(color: roleColor, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(user.departmentName, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
        ),
        trailing: isSelf
            ? const Chip(label: Text('Bạn', style: TextStyle(fontSize: 11)))
            : PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'edit') _showEditUserDialog(user);
                  if (action == 'delete') _confirmDeleteUser(user);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Row(
                    children: [Icon(Icons.edit, size: 18, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), const Text('Chỉnh sửa')],
                  )),
                  PopupMenuItem(value: 'delete', child: Row(
                    children: [Icon(Icons.delete, size: 18, color: AppColors.error), const SizedBox(width: 8), Text('Xóa tài khoản', style: TextStyle(color: AppColors.error))],
                  )),
                ],
              ),
      ),
    );
  }

  // ---------- Tab 2: Departments ----------

  Widget _buildDeptsTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Tổng: ${_departments.length} phòng ban',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF64748B)),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showDeptDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Thêm mới'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingDepts
              ? const Center(child: CircularProgressIndicator())
              : _departments.isEmpty
                  ? const Center(child: Text('Chưa có phòng ban nào', style: TextStyle(color: Color(0xFF64748B))))
                  : RefreshIndicator(
                      onRefresh: _loadDepartments,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _departments.length,
                        itemBuilder: (ctx, i) => _buildDeptCard(_departments[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildDeptCard(Map<String, String> dept) {
    final id = dept['id'] ?? '';
    final name = dept['name'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).brightness == Brightness.light ? AppColors.borderLight : AppColors.borderDark),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.success.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.apartment, color: AppColors.success),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('ID: $id', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _showDeptDialog(id: id, currentName: name),
              icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary, size: 20),
              tooltip: 'Đổi tên',
            ),
            IconButton(
              onPressed: () => _confirmDeleteDept(id, name),
              icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
              tooltip: 'Xóa',
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Helpers ----------

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      decoration: _inputDeco(label, icon),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withAlpha(12)
          : AppColors.backgroundLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}

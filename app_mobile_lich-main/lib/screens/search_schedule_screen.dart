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
// Phạm vi tìm kiếm của màn Tìm kiếm.
// Mặc định sẽ là "Tất cả".
// Khi người dùng bấm icon kính lúp, app sẽ cho chọn:
// Tất cả, Chủ trì, Tiêu đề, Khoa, Tham gia.
enum SearchScope {
  all,
  teacher,
  title,
  department,
  participant,
}

class _SearchScheduleScreenState extends State<SearchScheduleScreen> {
  final TextEditingController _controller = TextEditingController();

  String _keyword = '';

// Mặc định tìm theo "Tất cả".
// Tất cả ở đây gồm: tiêu đề, chủ trì, khoa/đơn vị, người tham gia.
// Không tìm theo phòng/địa điểm nữa.
  SearchScope _selectedScope = SearchScope.all;

  List<ScheduleItem>? _allSchedules;
  List<ScheduleItem> _displayedSchedules = [];
  bool _isLoading = true;
  late StreamSubscription<String> _eventSubscription;

  @override
  void initState() {
    super.initState();
    _loadAllSchedules();
    _eventSubscription = EventBus().onSchedulesChanged.listen((_) {
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

    final keyword = _normalizeText(_keyword);

    // Giữ nguyên hành vi hiện tại của code bạn:
    // Nếu chưa nhập gì thì hiển thị toàn bộ lịch đã tải.
    if (keyword.isEmpty) {
      _displayedSchedules = List.from(_allSchedules!);
      return;
    }

    _displayedSchedules = _allSchedules!.where((item) {
      final title = _normalizeText(item.title);
      final teacher = _normalizeText(item.teacher);
      final unit = _normalizeText(item.unit);
      final departmentName = _normalizeText(item.departmentName);
      final participants = _normalizeText(item.participants.join(' '));

      switch (_selectedScope) {
        case SearchScope.teacher:
        // Chỉ tìm theo người chủ trì / người phụ trách.
          return teacher.contains(keyword);

        case SearchScope.title:
        // Chỉ tìm theo tiêu đề lịch.
          return title.contains(keyword);

        case SearchScope.department:
        // Tìm theo khoa/phòng ban hoặc đơn vị.
          return unit.contains(keyword) || departmentName.contains(keyword);

        case SearchScope.participant:
        // Chỉ tìm theo người tham gia.
          return participants.contains(keyword);

        case SearchScope.all:
        // Tìm rộng, nhưng KHÔNG tìm theo phòng/địa điểm nữa.
          return title.contains(keyword) ||
              teacher.contains(keyword) ||
              unit.contains(keyword) ||
              departmentName.contains(keyword) ||
              participants.contains(keyword);
      }
    }).toList();
  }

// Chuẩn hóa tiếng Việt để tìm kiếm dễ hơn.
// Ví dụ:
// - Nhập "vu" vẫn tìm được "Vũ".
// - Nhập "cong nghe" vẫn tìm được "Công nghệ".
  String _normalizeText(String value) {
    var text = value.toLowerCase().trim();

    text = text
        .replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
        .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
        .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
        .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
        .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
        .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y')
        .replaceAll(RegExp(r'đ'), 'd');

    return text;
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

            // Kính lúp chỉ là biểu tượng tìm kiếm.
            // Bộ lọc tìm kiếm sẽ nằm ở dòng bên dưới để người dùng dễ hiểu hơn.
            prefixIcon: const Icon(Icons.search),

            // Có từ khóa thì hiện nút xóa nhanh.
            suffixIcon: _keyword.trim().isEmpty
                ? null
                : IconButton(
              tooltip: 'Xóa từ khóa',
              icon: const Icon(Icons.close),
              onPressed: () {
                _controller.clear();
                _onSearchChanged('');
              },
            ),

            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withAlpha(12)
                : AppColors.backgroundLight,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),

        const SizedBox(height: 10),

// Dòng chọn phạm vi tìm kiếm.
// Theo yêu cầu của bạn, tiêu đề là "Tìm kiếm theo".
        _buildSearchScopeSelector(),

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
// Widget hiển thị phạm vi tìm kiếm hiện tại.
// Ví dụ: "Tìm kiếm theo: Tất cả"
// Khi bấm vào widget này, app mở bảng chọn từ dưới lên.
  Widget _buildSearchScopeSelector() {
    return InkWell(
      onTap: _showSearchScopeBottomSheet,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withAlpha(10)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withAlpha(22)
                : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(
                Theme.of(context).brightness == Brightness.dark ? 18 : 8,
              ),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _scopeIcon(_selectedScope),
                size: 19,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),

            const SizedBox(width: 10),

            Text(
              'Tìm kiếm theo:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),

            const SizedBox(width: 6),

            Expanded(
              child: Text(
                _scopeLabel(_selectedScope),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),

            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ],
        ),
      ),
    );
  }

// Mở bảng chọn phạm vi tìm kiếm từ dưới lên.
// Đã bỏ mục "Phòng" theo yêu cầu của bạn.
  Future<void> _showSearchScopeBottomSheet() async {
    final selected = await showModalBottomSheet<SearchScope>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(bottomSheetContext).size.height * 0.75,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withAlpha(35)
                          : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Chọn kiểu tìm kiếm',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        _buildScopeOption(SearchScope.all),
                        _buildScopeOption(SearchScope.teacher),
                        _buildScopeOption(SearchScope.title),
                        _buildScopeOption(SearchScope.department),
                        _buildScopeOption(SearchScope.participant),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected == null) return;

    setState(() {
      _selectedScope = selected;
      _filterSchedules();
    });
  }

// Một dòng lựa chọn trong bottom sheet.
// Danh sách hiện tại gồm:
// Tất cả, Chủ trì, Tiêu đề, Khoa, Tham gia.
  Widget _buildScopeOption(SearchScope scope) {
    final isSelected = _selectedScope == scope;

    return InkWell(
      onTap: () {
        Navigator.pop(context, scope);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withAlpha(22)
              : Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withAlpha(8)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withAlpha(16)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.primary.withAlpha(18),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                _scopeIcon(scope),
                size: 20,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.primary,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _scopeLabel(scope),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _scopeDescription(scope),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),

            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

// Tên hiển thị của từng kiểu tìm kiếm.
  String _scopeLabel(SearchScope scope) {
    switch (scope) {
      case SearchScope.all:
        return 'Tất cả';
      case SearchScope.teacher:
        return 'Chủ trì';
      case SearchScope.title:
        return 'Tiêu đề';
      case SearchScope.department:
        return 'Khoa';
      case SearchScope.participant:
        return 'Tham gia';
    }
  }

// Mô tả ngắn để người dùng hiểu lựa chọn này tìm theo trường nào.
  String _scopeDescription(SearchScope scope) {
    switch (scope) {
      case SearchScope.all:
        return 'Tìm trong tiêu đề, chủ trì, khoa, người tham gia';
      case SearchScope.teacher:
        return 'Chỉ tìm theo người chủ trì / người phụ trách';
      case SearchScope.title:
        return 'Chỉ tìm theo tiêu đề hoặc nội dung lịch';
      case SearchScope.department:
        return 'Chỉ tìm theo khoa, phòng ban hoặc đơn vị';
      case SearchScope.participant:
        return 'Chỉ tìm theo người tham gia lịch';
    }
  }

// Icon tương ứng với từng kiểu tìm kiếm.
  IconData _scopeIcon(SearchScope scope) {
    switch (scope) {
      case SearchScope.all:
        return Icons.manage_search;
      case SearchScope.teacher:
        return Icons.person_search;
      case SearchScope.title:
        return Icons.title;
      case SearchScope.department:
        return Icons.business;
      case SearchScope.participant:
        return Icons.groups;
    }
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
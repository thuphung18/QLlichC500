import 'package:flutter/material.dart';

// DaySelector là thanh chọn ngày trong tuần.
// Người dùng bấm T2, T3, T4... để đổi lịch theo ngày.
class DaySelector extends StatefulWidget {
  final int selectedDayIndex;
  final ValueChanged<int> onChanged;

  const DaySelector({
    super.key,
    required this.selectedDayIndex,
    required this.onChanged,
  });

  @override
  State<DaySelector> createState() => _DaySelectorState();
}

class _DaySelectorState extends State<DaySelector> {
  late ScrollController _scrollController;

  // index dùng để lọc lịch:
  // 2 = thứ 2
  // 3 = thứ 3
  // ...
  // 8 = chủ nhật
  static const List<_DayInfo> _days = [
    _DayInfo(index: 2, label: 'T2', date: '08/6'),
    _DayInfo(index: 3, label: 'T3', date: '09/6'),
    _DayInfo(index: 4, label: 'T4', date: '10/6'),
    _DayInfo(index: 5, label: 'T5', date: '11/6'),
    _DayInfo(index: 6, label: 'T6', date: '12/6'),
    _DayInfo(index: 7, label: 'T7', date: '13/6'),
    _DayInfo(index: 8, label: 'CN', date: '14/6'),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    
    // Đợi layout xong thì cuộn tới ngày đang chọn
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDay(animate: false);
    });
  }

  @override
  void didUpdateWidget(covariant DaySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDayIndex != widget.selectedDayIndex) {
      _scrollToSelectedDay(animate: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedDay({bool animate = true}) {
    if (!_scrollController.hasClients) return;

    final index = _days.indexWhere((day) => day.index == widget.selectedDayIndex);
    if (index == -1) return;

    const itemWidth = 62.0;
    const separatorWidth = 10.0;
    const itemStride = itemWidth + separatorWidth;

    // Tọa độ tâm của phần tử đang chọn
    final itemCenter = (index * itemStride) + (itemWidth / 2);

    // Kích thước chiều ngang của màn hình / khung hiển thị
    final viewportWidth = _scrollController.position.viewportDimension;

    // Tính toán để đưa phần tử vào giữa màn hình
    var targetOffset = itemCenter - (viewportWidth / 2);

    // Đảm bảo không cuộn quá giới hạn
    if (targetOffset < 0) {
      targetOffset = 0;
    } else if (targetOffset > _scrollController.position.maxScrollExtent) {
      targetOffset = _scrollController.position.maxScrollExtent;
    }

    if (animate) {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(targetOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _days.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final day = _days[index];
          final isSelected = widget.selectedDayIndex == day.index;

          return GestureDetector(
            onTap: () {
              widget.onChanged(day.index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 62,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    day.label,
                    style: TextStyle(
                      color:
                      isSelected ? Colors.white : (Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF0F172A)),
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    day.date,
                    style: TextStyle(
                      color:
                      isSelected ? Colors.white70 : (Theme.of(context).textTheme.bodyMedium?.color ?? const Color(0xFF64748B)),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
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
}

// Class nhỏ chỉ dùng nội bộ trong DaySelector.
class _DayInfo {
  final int index;
  final String label;
  final String date;

  const _DayInfo({
    required this.index,
    required this.label,
    required this.date,
  });
}
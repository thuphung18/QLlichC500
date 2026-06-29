import 'package:flutter/material.dart';

// DaySelector là thanh chọn ngày trong tuần.
// Bản cũ đang fix cứng ngày 08/6 - 14/6.
// Bản này tự lấy tuần hiện tại theo thời gian thật của thiết bị.
//
// Quy ước dayIndex trong app của bạn:
// 2 = Thứ 2
// 3 = Thứ 3
// ...
// 7 = Thứ 7
// 8 = Chủ nhật
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

  // Hàm này tạo danh sách 7 ngày của TUẦN HIỆN TẠI.
  // Ví dụ hôm nay là 29/6/2026:
  // - T2 sẽ là ngày đầu tuần
  // - CN sẽ là ngày cuối tuần
  //
  // Không còn fix cứng 08/6, 09/6 nữa.
  List<_DayInfo> _getCurrentWeekDays() {
    final today = DateTime.now();

    // Cắt bỏ giờ/phút/giây để chỉ lấy ngày hiện tại.
    final currentDate = DateTime(
      today.year,
      today.month,
      today.day,
    );

    // DateTime.weekday của Dart:
    // Monday = 1, Tuesday = 2, ..., Sunday = 7.
    //
    // Tính ra ngày thứ 2 của tuần hiện tại.
    final monday = currentDate.subtract(
      Duration(days: currentDate.weekday - DateTime.monday),
    );

    // Sinh ra 7 ngày từ thứ 2 đến chủ nhật.
    return List.generate(7, (position) {
      final date = monday.add(Duration(days: position));

      // App bạn đang dùng dayIndex:
      // position 0 -> T2 -> index 2
      // position 1 -> T3 -> index 3
      // ...
      // position 6 -> CN -> index 8
      final dayIndex = position + 2;

      final label = dayIndex == 8 ? 'CN' : 'T$dayIndex';
      final dateText = '${date.day}/${date.month}';

      return _DayInfo(
        index: dayIndex,
        label: label,
        date: dateText,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // Đợi layout xong thì cuộn tới ngày đang chọn.
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

    final days = _getCurrentWeekDays();

    final index = days.indexWhere(
          (day) => day.index == widget.selectedDayIndex,
    );

    if (index == -1) return;

    const itemWidth = 62.0;
    const separatorWidth = 10.0;
    const itemStride = itemWidth + separatorWidth;

    // Tọa độ tâm của phần tử đang chọn.
    final itemCenter = (index * itemStride) + (itemWidth / 2);

    // Chiều ngang khung ListView hiện tại.
    final viewportWidth = _scrollController.position.viewportDimension;

    // Tính offset để đưa phần tử được chọn vào giữa màn hình.
    var targetOffset = itemCenter - (viewportWidth / 2);

    // Không cho cuộn quá đầu/cuối danh sách.
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
    final days = _getCurrentWeekDays();

    return SizedBox(
      height: 72,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final day = days[index];
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
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).cardColor,
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
                      color: isSelected
                          ? Colors.white
                          : (Theme.of(context).textTheme.bodyLarge?.color ??
                          const Color(0xFF0F172A)),
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    day.date,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white70
                          : (Theme.of(context).textTheme.bodyMedium?.color ??
                          const Color(0xFF64748B)),
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
// Nó không liên quan backend, chỉ phục vụ hiển thị UI.
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
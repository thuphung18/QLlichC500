import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../models/schedule_item.dart';
import '../theme/app_colors.dart';

// ScheduleCard là card hiển thị một lịch.
// Widget này dùng trong:
// - Lịch tuần
// - Lịch của tôi
// - Lịch khoa
// - Tìm kiếm
class ScheduleCard extends StatelessWidget {
  final ScheduleItem item;
  final Color accentColor;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ScheduleCard({
    super.key,
    required this.item,
    required this.accentColor,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // Khi bấm vào card, sẽ mở chi tiết lịch.
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white10 
                    : accentColor.withAlpha(26),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(9),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cột thời gian bên trái.
                Container(
                  width: 66,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: accentColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        item.startTime,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        width: 20,
                        height: 2,
                        decoration: BoxDecoration(
                          color: accentColor.withAlpha(120),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.endTime,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color ?? const Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 14),

                // Nội dung chính của lịch.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Loại lịch và Trạng thái
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withAlpha(18),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              item.category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (item.isPassed) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF94A3B8).withAlpha(30),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: const Text(
                                'Đã diễn ra',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ]
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Tên lịch.
                      Text(
                        item.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF0F172A),
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          height: 1.28,
                        ),
                      ),

                      const SizedBox(height: 9),

                      _SmallInfoRow(
                        icon: Icons.location_on,
                        text: item.room,
                        color: accentColor,
                      ),
                      const SizedBox(height: 6),
                      _SmallInfoRow(
                        icon: Icons.person,
                        text: item.teacher,
                        color: accentColor,
                      ),
                      const SizedBox(height: 6),
                      _SmallInfoRow(
                        icon: Icons.business,
                        text: item.unit,
                        color: accentColor,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                Icon(
                  Icons.chevron_right,
                  color: accentColor,
                  size: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Widget finalCard = item.isPassed
        ? Opacity(
            opacity: 0.6,
            child: card,
          )
        : card;

    if (onDelete != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Slidable(
          key: Key('schedule_${item.id}'),
          endActionPane: ActionPane(
            motion: const ScrollMotion(),
            extentRatio: 0.25,
            children: [
              CustomSlidableAction(
                onPressed: (context) {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text("Xác nhận xóa"),
                        content: const Text("Bạn có chắc chắn muốn xóa lịch này không?"),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("Hủy"),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              onDelete!();
                            },
                            child: Text("Xóa", style: TextStyle(color: AppColors.error)),
                          ),
                        ],
                      );
                    },
                  );
                },
                backgroundColor: Colors.transparent,
                foregroundColor: AppColors.error,
                padding: EdgeInsets.zero,
                child: Container(
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(20),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.error.withAlpha(50)),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline, color: AppColors.error, size: 28),
                      const SizedBox(height: 4),
                      Text(
                        'Xóa',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          child: Container(
            // We moved the bottom margin of the card out to the Slidable's padding
            // so the Slidable action button doesn't look misaligned
            margin: EdgeInsets.zero,
            child: finalCard,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        margin: EdgeInsets.zero,
        child: finalCard,
      ),
    );
  }
}

// Dòng thông tin nhỏ: phòng, người phụ trách, đơn vị.
class _SmallInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _SmallInfoRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 15,
          color: color,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color ?? const Color(0xFF475569),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
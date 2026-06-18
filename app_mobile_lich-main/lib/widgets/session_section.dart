import 'package:flutter/material.dart';

import '../models/schedule_item.dart';
import '../screens/schedule_detail_screen.dart';
import 'schedule_card.dart';

// SessionSection là một khu vực lịch theo buổi.
// Ví dụ:
// - SÁNG
// - CHIỀU
// - TỐI
class SessionSection extends StatelessWidget {
  final String title;
  final List<ScheduleItem> items;
  final Color accentColor;
  final IconData icon;
  final bool isAdmin;
  final Future<void> Function(ScheduleItem)? onDelete;

  const SessionSection({
    super.key,
    required this.title,
    required this.items,
    required this.accentColor,
    this.icon = Icons.event_available,
    this.isAdmin = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Nếu buổi đó không có lịch thì không hiển thị khu vực này.
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề buổi.
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(22),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF0F172A),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Chip(
                backgroundColor: accentColor.withAlpha(18),
                side: BorderSide(
                  color: accentColor.withAlpha(55),
                ),
                label: Text(
                  '${items.length} lịch',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Danh sách card lịch trong buổi đó.
          ...items.map(
                (item) => ScheduleCard(
              item: item,
              accentColor: accentColor,
              onDelete: onDelete != null ? () => onDelete!(item) : null,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ScheduleDetailScreen(
                      item: item,
                      accentColor: accentColor,
                      isAdmin: isAdmin,
                      onDelete: onDelete != null ? () => onDelete!(item) : null,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
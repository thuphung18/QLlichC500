import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// ScheduleSummaryCard là card thống kê tổng số lịch.
// Nó hiển thị:
// - Tổng lịch trong ngày
// - Số lịch buổi sáng
// - Số lịch buổi chiều
// - Số lịch buổi tối
class ScheduleSummaryCard extends StatelessWidget {
  final int totalCount;
  final int morningCount;
  final int afternoonCount;
  final int eveningCount;
  final Color accentColor;
  final String title;
  final String subtitle;

  const ScheduleSummaryCard({
    super.key,
    required this.totalCount,
    required this.morningCount,
    required this.afternoonCount,
    required this.eveningCount,
    required this.accentColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hàng trên: icon + tiêu đề + tổng số lịch.
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.assessment,
                  color: accentColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF0F172A),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color ?? const Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(22),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$totalCount lịch',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Hàng dưới: thống kê sáng / chiều / tối.
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Sáng',
                  count: morningCount,
                  color: Theme.of(context).colorScheme.primary,
                  icon: Icons.wb_sunny,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: 'Chiều',
                  count: afternoonCount,
                  color: AppColors.warning,
                  icon: Icons.brightness_5,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: 'Tối',
                  count: eveningCount,
                  color: AppColors.accentLight,
                  icon: Icons.nights_stay,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Widget nhỏ cho từng ô thống kê.
class _MiniStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _MiniStat({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 22,
          ),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color ?? const Color(0xFF475569),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
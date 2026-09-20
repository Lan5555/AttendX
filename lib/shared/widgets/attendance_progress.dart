import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Circular attendance progress indicator with a percentage label
/// in the center. Color reflects standing relative to [threshold].
class AttendanceProgress extends StatelessWidget {
  final double percentage;
  final double threshold;
  final double size;

  const AttendanceProgress({
    super.key,
    required this.percentage,
    this.threshold = 75,
    this.size = 128,
  });

  Color get _color {
    if (percentage >= threshold) return AppColors.success;
    if (percentage >= threshold - 15) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (percentage / 100).clamp(0, 1)),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => CircularProgressIndicator(
                value: value,
                strokeWidth: 10,
                backgroundColor: AppColors.outline,
                valueColor: AlwaysStoppedAnimation<Color>(_color),
                strokeCap: StrokeCap.round,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: size * 0.22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              Text(
                'Attendance',
                style: TextStyle(fontSize: size * 0.075, color: AppColors.textTertiary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

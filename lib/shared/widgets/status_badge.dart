import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

enum StatusTone { success, warning, error, info, neutral }

/// Small pill badge used across the app for attendance/session/eligibility
/// states, e.g. "Eligible", "Attendance Open", "Synced".
class StatusBadge extends StatelessWidget {
  final String label;
  final StatusTone tone;
  final IconData? icon;

  const StatusBadge({super.key, required this.label, this.tone = StatusTone.neutral, this.icon});

  ({Color bg, Color fg}) get _colors {
    switch (tone) {
      case StatusTone.success:
        return (bg: AppColors.successBg, fg: AppColors.success);
      case StatusTone.warning:
        return (bg: AppColors.warningBg, fg: AppColors.warning);
      case StatusTone.error:
        return (bg: AppColors.errorBg, fg: AppColors.error);
      case StatusTone.info:
        return (bg: AppColors.infoBg, fg: AppColors.info);
      case StatusTone.neutral:
        return (bg: AppColors.surfaceAlt, fg: AppColors.textSecondary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: c.fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: c.fg),
          ),
        ],
      ),
    );
  }
}

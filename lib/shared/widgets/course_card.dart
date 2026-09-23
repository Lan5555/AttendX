import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../models/course.dart';
import 'status_badge.dart';

/// Reusable course summary card used on Student Courses and Lecturer
/// Courses screens.
class CourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback? onTap;
  final bool isLecturerView;
  final VoidCallback? onEdit;
  final VoidCallback? onManageStudents;

  const CourseCard({
    super.key,
    required this.course,
    this.onTap,
    this.isLecturerView = false,
    this.onEdit,
    this.onManageStudents,
  });

  StatusTone _eligibilityTone() {
    switch (course.eligibility) {
      case AttendanceEligibility.eligible:
        return StatusTone.success;
      case AttendanceEligibility.atRisk:
        return StatusTone.warning;
      case AttendanceEligibility.ineligible:
        return StatusTone.error;
    }
  }

  String _eligibilityLabel() {
    switch (course.eligibility) {
      case AttendanceEligibility.eligible:
        return 'Eligible';
      case AttendanceEligibility.atRisk:
        return 'At Risk';
      case AttendanceEligibility.ineligible:
        return 'Ineligible';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(course.code, style: Theme.of(context).textTheme.titleMedium),
                        Text(course.title, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  if (!isLecturerView) StatusBadge(label: _eligibilityLabel(), tone: _eligibilityTone()),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.sm),
              if (!isLecturerView) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MiniStat(label: 'Attendance', value: '${course.classesAttended} / ${course.classesHeld}'),
                    _MiniStat(label: 'Percentage', value: '${course.attendancePercentage.toStringAsFixed(0)}%'),
                    _MiniStat(label: 'Units', value: '${course.creditUnits}'),
                  ],
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MiniStat(label: 'Students', value: '${course.enrolledStudents}'),
                    _MiniStat(label: 'Schedule', value: '${course.schedule.day} • ${course.schedule.startTime}'),
                    _MiniStat(label: 'Attendance', value: '${course.attendancePercentage.toStringAsFixed(0)}%'),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onEdit,
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                        child: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onManageStudents,
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                        child: const Text('Manage'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
      ],
    );
  }
}

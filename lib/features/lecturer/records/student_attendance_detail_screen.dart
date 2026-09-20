import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/course.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/attendance_progress.dart';

class StudentAttendanceDetailScreen extends StatelessWidget {
  final String studentName;
  final String studentId;
  final Course course;

  const StudentAttendanceDetailScreen({
    super.key,
    required this.studentName,
    required this.studentId,
    required this.course,
  });

  List<(String, bool)> get _history {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final present = (i + studentId.length) % 4 != 0;
      final date = DateFormat('d MMM').format(now.subtract(Duration(days: i * 2)));
      return (date, present);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Attendance')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(studentName[0], style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.primary)),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(studentName, style: Theme.of(context).textTheme.titleLarge),
                Text(studentId, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(child: AttendanceProgress(percentage: course.attendancePercentage, threshold: course.attendanceThreshold)),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              children: [
                _Row(label: 'Course', value: course.code),
                const Divider(height: 20),
                _Row(label: 'Attendance', value: '${course.classesAttended} / ${course.classesHeld}'),
                const Divider(height: 20),
                _Row(label: 'Threshold', value: '${course.attendanceThreshold.toStringAsFixed(0)}%'),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Status', style: Theme.of(context).textTheme.bodyMedium),
                    StatusBadge(
                      label: switch (course.eligibility) {
                        AttendanceEligibility.eligible => 'Eligible',
                        AttendanceEligibility.atRisk => 'At Risk',
                        AttendanceEligibility.ineligible => 'Ineligible',
                      },
                      tone: switch (course.eligibility) {
                        AttendanceEligibility.eligible => StatusTone.success,
                        AttendanceEligibility.atRisk => StatusTone.warning,
                        AttendanceEligibility.ineligible => StatusTone.error,
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('History', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          ..._history.map((h) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    h.$2 ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: h.$2 ? AppColors.success : AppColors.error,
                  ),
                  title: Text(h.$1, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  trailing: Text(h.$2 ? 'Present' : 'Absent',
                      style: TextStyle(color: h.$2 ? AppColors.success : AppColors.error, fontWeight: FontWeight.w700, fontSize: 12.5)),
                ),
              )),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
      ],
    );
  }
}

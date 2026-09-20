import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/attendance_session.dart';
import '../../../shared/widgets/app_button.dart';
import '../records/attendance_records_screen.dart';
import '../export/export_screen.dart';

class SessionSummaryScreen extends StatelessWidget {
  final AttendanceSession session;
  const SessionSummaryScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final absent = session.totalStudents - session.presentCount;
    return Scaffold(
      appBar: AppBar(title: Text(session.courseCode), automaticallyImplyLeading: false),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.md),
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(color: AppColors.successBg, shape: BoxShape.circle),
                child: const Icon(Icons.task_alt_rounded, color: AppColors.success, size: 36),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Attendance Session Complete', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(session.courseTitle, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(child: _StatBlock(label: 'Present', value: '${session.presentCount}', color: AppColors.success)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _StatBlock(label: 'Absent', value: '$absent', color: AppColors.error)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _StatBlock(label: 'Total', value: '${session.totalStudents}', color: AppColors.info)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                  children: [
                    Text('Attendance Rate', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text('${session.attendanceRate.toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  ],
                ),
              ),
              const Spacer(),
              AppButton(
                label: 'View Attendance',
                icon: Icons.list_alt_rounded,
                width: double.infinity,
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => AttendanceRecordsScreen(initialCourseId: session.courseId)),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Export CSV',
                      variant: AppButtonVariant.outlined,
                      icon: Icons.file_download_outlined,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ExportScreen(preselectedCourseId: session.courseId)),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      label: 'Export Excel',
                      variant: AppButtonVariant.outlined,
                      icon: Icons.table_chart_outlined,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ExportScreen(preselectedCourseId: session.courseId)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Back to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBlock({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}

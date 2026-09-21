import 'package:attendx/controllers/attendance_controller.dart';
import 'package:attendx/controllers/course_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/models/course.dart';
import '../../../shared/models/attendance_record.dart';
import '../../../shared/widgets/attendance_progress.dart';
import '../../../shared/widgets/attendance_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/loading_state.dart';
import '../attendance/mark_attendance_flow.dart';

class CourseDetailsScreen extends StatefulWidget {
  final String courseId;
  const CourseDetailsScreen({super.key, required this.courseId});

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen> {
  Course? _course;
  List<AttendanceRecord> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<CourseController>();
    final attendanceHandler = context.read<AttendanceController>();
    await appState.findCourseById(widget.courseId);

    final history = await attendanceHandler.getAttendanceForCourse(widget.courseId);
    if (!mounted) return;
    setState(() {
      _course = appState.courseData;
      _history = history;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          body: LoadingState(message: 'Loading course details…'));
    }
    final course = _course;
    if (course == null) {
      return const Scaffold(body: Center(child: Text('Course not found.')));
    }

    return Scaffold(
      appBar: AppBar(title: Text(course.code)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(course.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(course.lecturerName,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          Center(
              child: AttendanceProgress(
                  percentage: course.attendancePercentage,
                  threshold: course.attendanceThreshold)),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: StatusBadge(
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
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              children: [
                _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Venue',
                    value: course.schedule.venue),
                const Divider(height: 20),
                _InfoRow(
                    icon: Icons.schedule_rounded,
                    label: 'Schedule',
                    value:
                        '${course.schedule.day} • ${course.schedule.timeRangeLabel}'),
                const Divider(height: 20),
                _InfoRow(
                    icon: Icons.event_available_rounded,
                    label: 'Classes Held',
                    value: '${course.classesHeld}'),
                const Divider(height: 20),
                _InfoRow(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Classes Attended',
                    value: '${course.classesAttended}'),
                const Divider(height: 20),
                _InfoRow(
                    icon: Icons.cancel_outlined,
                    label: 'Classes Missed',
                    value: '${course.classesMissed}'),
                const Divider(height: 20),
                _InfoRow(
                    icon: Icons.flag_outlined,
                    label: 'Attendance Threshold',
                    value: '${course.attendanceThreshold.toStringAsFixed(0)}%'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => MarkAttendanceFlow(course: course),
                    fullscreenDialog: true),
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text('Mark Attendance'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Attendance History',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          ..._history.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AttendanceRecordCard(record: r, showCourse: false),
              )),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textTertiary),
        const SizedBox(width: 10),
        Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textPrimary)),
      ],
    );
  }
}

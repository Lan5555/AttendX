import 'package:attendx/controllers/attendance_controller.dart';
import 'package:attendx/controllers/course_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final courseController = context.read<CourseController>();
      final attendanceHandler = context.read<AttendanceController>();

      await courseController.findCourseById(widget.courseId);
      final course = courseController.courseData;

       attendanceHandler.fetchStudentAttendanceHistory();

      // Scope the history to this course only.
      final history = course == null
          ? <AttendanceRecord>[]
          : attendanceHandler.attendanceHistory
              .where((r) => r.courseCode == course.code)
              .toList();

      if (!mounted) return;
      setState(() {
        _course = course;
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load course details.';
      });
    }
  }

  /// True if the student already has an attendance record for this
  /// course dated today.
  bool get _hasMarkedToday {
    final now = DateTime.now();
    return _history.any((r) {
      final d = r.date;
      return d.year == now.year &&
          d.month == now.month &&
          d.day == now.day;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: LoadingState(message: 'Loading course details…'),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  color: AppColors.textTertiary,
                  size: 48,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final course = _course;
    if (course == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: const Center(child: Text('Course not found.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: _CourseHero(course: course),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _AttendanceCard(course: course),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      _MiniStat(
                        label: 'Held',
                        value: '${course.classesHeld}',
                        color: AppColors.info,
                        icon: Icons.event_available_rounded,
                      ),
                      const SizedBox(width: 8),
                      _MiniStat(
                        label: 'Attended',
                        value: '${course.classesAttended}',
                        color: AppColors.success,
                        icon: Icons.check_circle_outline_rounded,
                      ),
                      const SizedBox(width: 8),
                      _MiniStat(
                        label: 'Missed',
                        value: '${course.classesMissed}',
                        color: AppColors.error,
                        icon: Icons.cancel_outlined,
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _CourseInfoCard(course: course),
                ),
              ),

              // ── Mark Attendance CTA (conditional) ──────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _hasMarkedToday
                      ? const _MarkedTodayBanner()
                      : SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      MarkAttendanceFlow(course: course),
                                  fullscreenDialog: true,
                                ),
                              );
                              if (mounted) _load();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                            ),
                            icon: const Icon(
                              Icons.qr_code_scanner_rounded,
                              size: 20,
                            ),
                            label: const Text(
                              'Mark Attendance',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                ),
              ),

              // ── History header ────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      const Text(
                        'Attendance History',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${_history.length}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── History list or empty ─────────────────────────────
              if (_history.isEmpty)
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  sliver: SliverToBoxAdapter(child: _EmptyHistory()),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  sliver: SliverList.separated(
                    itemCount: _history.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) => AttendanceRecordCard(
                      record: _history[i],
                      showCourse: false,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.xl),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// HERO HEADER
// ─────────────────────────────────────────────────────────────────────
class _CourseHero extends StatelessWidget {
  final Course course;
  const _CourseHero({required this.course});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        topPadding + AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryLight.withValues(alpha: .16),
            AppColors.primaryLight.withValues(alpha: .04),
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (Navigator.of(context).canPop())
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.textPrimary,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 22,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              course.code,
              style: const TextStyle(
                color: AppColors.onPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            course.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                size: 14,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  course.lecturerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _HeroChip(
                icon: Icons.school_outlined,
                label: course.department,
              ),
              _HeroChip(
                icon: Icons.star_rounded,
                label: '${course.creditUnits} units',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textTertiary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// ATTENDANCE CARD
// ─────────────────────────────────────────────────────────────────────
class _AttendanceCard extends StatelessWidget {
  final Course course;
  const _AttendanceCard({required this.course});

  @override
  Widget build(BuildContext context) {
    final isEligible = course.eligibility == AttendanceEligibility.eligible;
    final isAtRisk = course.eligibility == AttendanceEligibility.atRisk;
    final color = isEligible
        ? AppColors.success
        : isAtRisk
            ? AppColors.warning
            : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            color.withValues(alpha: .04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: color.withValues(alpha: .22),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          AttendanceProgress(
            percentage: course.attendancePercentage,
            threshold: course.attendanceThreshold,
            size: 96,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attendance Rate',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  isEligible
                      ? "You're on track to pass this course."
                      : isAtRisk
                          ? 'Attend upcoming classes to stay eligible.'
                          : 'You have missed too many classes.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 10),
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
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// MINI STAT
// ─────────────────────────────────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// COURSE INFO CARD
// ─────────────────────────────────────────────────────────────────────
class _CourseInfoCard extends StatelessWidget {
  final Course course;
  const _CourseInfoCard({required this.course});

  @override
  Widget build(BuildContext context) {
    final rows = <_InfoData>[
      _InfoData(
        icon: Icons.location_on_outlined,
        label: 'Venue',
        value: course.schedule.venue.isEmpty ? 'TBA' : course.schedule.venue,
      ),
      _InfoData(
        icon: Icons.calendar_today_outlined,
        label: 'Day',
        value: course.schedule.day.isEmpty ? 'TBA' : course.schedule.day,
      ),
      _InfoData(
        icon: Icons.schedule_rounded,
        label: 'Time',
        value: course.schedule.timeRangeLabel,
      ),
      _InfoData(
        icon: Icons.flag_outlined,
        label: 'Threshold',
        value: '${course.attendanceThreshold.toStringAsFixed(0)}%',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _InfoRow(data: rows[i]),
            if (i != rows.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.outline,
                indent: 56,
              ),
          ],
        ],
      ),
    );
  }
}

class _InfoData {
  final IconData icon;
  final String label;
  final String value;
  const _InfoData({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _InfoRow extends StatelessWidget {
  final _InfoData data;
  const _InfoRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 14,
      ),
      child: Row(
        children: [
          Icon(data.icon, size: 20, color: AppColors.textTertiary),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              data.label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            data.value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// MARKED TODAY BANNER
// ─────────────────────────────────────────────────────────────────────
class _MarkedTodayBanner extends StatelessWidget {
  const _MarkedTodayBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.success.withValues(alpha: .3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attendance marked today',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "You're all set for this session.",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// EMPTY HISTORY
// ─────────────────────────────────────────────────────────────────────
class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xl,
        horizontal: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history_rounded,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'No attendance yet',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your records for this course will show up here after you scan in.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
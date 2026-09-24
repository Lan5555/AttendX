import 'package:attendx/controllers/auth_controller.dart';
import 'package:attendx/controllers/course_controller.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/models/student.dart';
import '../../../shared/models/course.dart';
import '../../../shared/mock/mock_data.dart';
import '../../../shared/widgets/attendance_progress.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/loading_state.dart';
import '../courses/course_details_screen.dart';
import '../attendance/mark_attendance_flow.dart';

enum ClassSessionState { upcoming, attendanceOpen, completed, missed }

class _TodayClass {
  final Course course;
  final ClassSessionState state;
  const _TodayClass(this.course, this.state);
}

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Course> _courses = [];
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final courseController = context.read<CourseController>();
    await courseController.fetchStudentCourses();
    if (!mounted) return;
    setState(() {
      _courses = courseController.courses;
      _isLoading = false;
    });
    _fadeController.forward();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  // ── Today's classes ─────────────────────────────────────────────────
  List<_TodayClass> get _todayClasses {
    final weekday = DateFormat('EEEE').format(DateTime.now());
    return _courses
        .where((c) => c.schedule.day.toLowerCase() == weekday.toLowerCase())
        .map((c) => _TodayClass(c, _inferState(c)))
        .toList()
      ..sort((a, b) {
        // Sort: attendance-open first, then upcoming, then completed, then missed.
        int rank(ClassSessionState s) => switch (s) {
              ClassSessionState.attendanceOpen => 0,
              ClassSessionState.upcoming => 1,
              ClassSessionState.completed => 2,
              ClassSessionState.missed => 3,
            };
        return rank(a.state).compareTo(rank(b.state));
      });
  }

  ClassSessionState _inferState(Course course) {
    final now = DateTime.now();
    final start = _parseTime(course.schedule.startTime);
    final end = _parseTime(course.schedule.endTime);
    if (start == null || end == null) return ClassSessionState.upcoming;

    final classStart = DateTime(
      now.year,
      now.month,
      now.day,
      start.hour,
      start.minute,
    );
    final classEnd = DateTime(
      now.year,
      now.month,
      now.day,
      end.hour,
      end.minute,
    );

    if (now.isBefore(classStart)) return ClassSessionState.upcoming;
    if (now.isAfter(classEnd)) return ClassSessionState.completed;
    return ClassSessionState.attendanceOpen;
  }

  TimeOfDay? _parseTime(String s) {
    if (s.trim().isEmpty) return null;
    try {
      final dt = DateFormat('h:mm a').parseStrict(s.trim());
      return TimeOfDay(hour: dt.hour, minute: dt.minute);
    } catch (_) {
      try {
        final dt = DateFormat('HH:mm').parseStrict(s.trim());
        return TimeOfDay(hour: dt.hour, minute: dt.minute);
      } catch (_) {
        return null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthController>();
    final student = authState.currentUser is Student
        ? authState.currentUser as Student
        : MockData.demoStudent;

    final todayClasses = _todayClasses;
    final hasOpenSession = todayClasses.any(
      (c) => c.state == ClassSessionState.attendanceOpen,
    );

    // Only count courses that have actually held sessions — otherwise a
    // fresh course (0/0) with no attendance yet would be flagged.
    final below = _courses
        .where((c) => c.classesHeld > 0)
        .where((c) => c.eligibility != AttendanceEligibility.eligible)
        .length;

    final attended =
        _courses.fold<int>(0, (sum, c) => sum + c.classesAttended);
    final missed = _courses.fold<int>(0, (sum, c) => sum + c.classesMissed);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          OfflineBanner(isOnline: authState.isOnline),
          Expanded(
            child: _isLoading
                ? const LoadingState(message: 'Loading your dashboard…')
                : RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: CustomScrollView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        slivers: [
                          // ── Hero header ───────────────────────────
                          SliverToBoxAdapter(
                            child: _Hero(
                              greeting: _greeting(),
                              student: student,
                              todayCount: todayClasses.length,
                              hasOpenSession: hasOpenSession,
                            ),
                          ),

                          // ── Overall attendance ────────────────────
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.lg,
                              AppSpacing.lg,
                              0,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: _OverallAttendanceCard(
                                student: student,
                                belowCount: below,
                              ),
                            ),
                          ),

                          // ── Today's classes header ────────────────
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.xl,
                              AppSpacing.lg,
                              AppSpacing.sm,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: _SectionHeader(
                                title: "Today's Classes",
                                subtitle: todayClasses.isEmpty
                                    ? null
                                    : '${todayClasses.length}',
                                icon: Icons.calendar_today_rounded,
                              ),
                            ),
                          ),

                          // ── Today's classes list or empty ─────────
                          if (todayClasses.isEmpty)
                            const SliverPadding(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                              ),
                              sliver: SliverToBoxAdapter(
                                child: _EmptyState(
                                  icon: Icons.event_available_rounded,
                                  message: 'No classes scheduled today',
                                  subtitle: 'Enjoy your free day! 🎉',
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                              ),
                              sliver: SliverList.separated(
                                itemCount: todayClasses.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (_, i) {
                                  final tc = todayClasses[i];
                                  return _AnimatedListItem(
                                    index: i,
                                    child: _TodayClassCard(
                                      data: tc,
                                      onTap: () =>
                                          Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              CourseDetailsScreen(
                                            courseId: tc.course.id,
                                          ),
                                        ),
                                      ),
                                      onMarkAttendance: () =>
                                          Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              MarkAttendanceFlow(
                                            course: tc.course,
                                          ),
                                          fullscreenDialog: true,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                          // ── Summary header ────────────────────────
                          const SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.xl,
                              AppSpacing.lg,
                              AppSpacing.sm,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: _SectionHeader(
                                title: 'Attendance Summary',
                                icon: Icons.insights_rounded,
                              ),
                            ),
                          ),

                          // ── Summary grid ──────────────────────────
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _SummaryTile(
                                      label: 'Attended',
                                      value: '$attended',
                                      icon: Icons.check_circle_outline_rounded,
                                      color: AppColors.success,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: _SummaryTile(
                                      label: 'Missed',
                                      value: '$missed',
                                      icon: Icons.cancel_outlined,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.sm,
                              AppSpacing.lg,
                              0,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _SummaryTile(
                                      label: 'Overall',
                                      value:
                                          '${student.overallAttendancePercentage.toStringAsFixed(0)}%',
                                      icon:
                                          Icons.pie_chart_outline_rounded,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: _SummaryTile(
                                      label: 'At Risk',
                                      value: '$below',
                                      icon: Icons.warning_amber_rounded,
                                      color: below > 0
                                          ? AppColors.warning
                                          : AppColors.textTertiary,
                                    ),
                                  ),
                                ],
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
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// HERO HEADER
// ─────────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  final String greeting;
  final Student student;
  final int todayCount;
  final bool hasOpenSession;

  const _Hero({
    required this.greeting,
    required this.student,
    required this.todayCount,
    required this.hasOpenSession,
  });

  String get _emoji {
    final hour = DateTime.now().hour;
    if (hour < 12) return '☀️';
    if (hour < 17) return '🌤️';
    return '🌙';
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final firstName = student.fullName.split(' ').first;
    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$greeting,',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(_emoji, style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      firstName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _InfoPill(
                          icon: Icons.badge_outlined,
                          label: student.studentId,
                        ),
                        const SizedBox(width: 6),
                        if (student.semester.isNotEmpty)
                          Flexible(
                            child: _InfoPill(
                              icon: Icons.school_outlined,
                              label: student.semester,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: .3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppColors.onPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          // Live session status strip
          if (hasOpenSession) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: .3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Attendance is open now',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.outline),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: AppColors.textTertiary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// OVERALL ATTENDANCE CARD
// ─────────────────────────────────────────────────────────────────────
class _OverallAttendanceCard extends StatelessWidget {
  final Student student;
  final int belowCount;

  const _OverallAttendanceCard({
    required this.student,
    required this.belowCount,
  });

  @override
  Widget build(BuildContext context) {
    final isGood = student.overallAttendancePercentage >=
        AppConstants.defaultAttendanceThreshold;
    final statusColor = isGood ? AppColors.success : AppColors.warning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            statusColor.withValues(alpha: .04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: statusColor.withValues(alpha: .2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: .08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          AttendanceProgress(
            percentage: student.overallAttendancePercentage,
            threshold: AppConstants.defaultAttendanceThreshold,
            size: 96,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isGood
                            ? Icons.verified_rounded
                            : Icons.trending_down_rounded,
                        size: 16,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Overall Attendance',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isGood
                      ? "You're in good standing across your courses."
                      : 'Your attendance is below the required threshold in some courses.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                        fontSize: 12.5,
                      ),
                ),
                const SizedBox(height: 10),
                StatusBadge(
                  label: belowCount == 0
                      ? 'All courses on track'
                      : '$belowCount course${belowCount == 1 ? '' : 's'} below threshold',
                  tone: belowCount == 0
                      ? StatusTone.success
                      : StatusTone.warning,
                  icon: belowCount == 0
                      ? Icons.check_circle_rounded
                      : Icons.warning_amber_rounded,
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
// SECTION HEADER
// ─────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.icon,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              subtitle!,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// SUMMARY TILE
// ─────────────────────────────────────────────────────────────────────
class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textTertiary,
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
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;

  const _EmptyState({
    required this.icon,
    required this.message,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// ANIMATED LIST ITEM
// ─────────────────────────────────────────────────────────────────────
class _AnimatedListItem extends StatefulWidget {
  final int index;
  final Widget child;

  const _AnimatedListItem({required this.index, required this.child});

  @override
  State<_AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<_AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    Future.delayed(Duration(milliseconds: 80 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// TODAY CLASS CARD
// ─────────────────────────────────────────────────────────────────────
class _TodayClassCard extends StatefulWidget {
  final _TodayClass data;
  final VoidCallback onTap;
  final VoidCallback onMarkAttendance;

  const _TodayClassCard({
    required this.data,
    required this.onTap,
    required this.onMarkAttendance,
  });

  @override
  State<_TodayClassCard> createState() => _TodayClassCardState();
}

class _TodayClassCardState extends State<_TodayClassCard> {
  bool _isPressed = false;

  (String, StatusTone, IconData, Color) get _statusInfo {
    switch (widget.data.state) {
      case ClassSessionState.upcoming:
        return (
          'Upcoming',
          StatusTone.info,
          Icons.schedule_rounded,
          AppColors.info
        );
      case ClassSessionState.attendanceOpen:
        return (
          'Attendance Open',
          StatusTone.success,
          Icons.qr_code_scanner_rounded,
          AppColors.success
        );
      case ClassSessionState.completed:
        return (
          'Completed',
          StatusTone.neutral,
          Icons.check_circle_outline_rounded,
          AppColors.textTertiary
        );
      case ClassSessionState.missed:
        return (
          'Missed',
          StatusTone.error,
          Icons.cancel_outlined,
          AppColors.error
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final (label, tone, icon, accentColor) = _statusInfo;
    final course = widget.data.course;
    final isAttendanceOpen =
        widget.data.state == ClassSessionState.attendanceOpen;

    return AnimatedScale(
      scale: _isPressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isAttendanceOpen
                ? AppColors.success.withValues(alpha: .4)
                : AppColors.outline,
            width: isAttendanceOpen ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isAttendanceOpen
                  ? AppColors.success.withValues(alpha: .1)
                  : Colors.black.withValues(alpha: .03),
              blurRadius: isAttendanceOpen ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 4,
                        height: 40,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course.code,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              course.title,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(label: label, tone: tone, icon: icon),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      _MetaItem(
                        icon: Icons.access_time_rounded,
                        text: course.schedule.timeRangeLabel,
                      ),
                      _MetaItem(
                        icon: Icons.location_on_outlined,
                        text: course.schedule.venue,
                      ),
                    ],
                  ),
                  if (isAttendanceOpen) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: widget.onMarkAttendance,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          'Mark Attendance',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// META ITEM
// ─────────────────────────────────────────────────────────────────────
class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
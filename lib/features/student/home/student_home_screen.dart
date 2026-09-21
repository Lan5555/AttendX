import 'package:attendx/controllers/auth_controller.dart';
import 'package:attendx/controllers/course_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/models/student.dart';
import '../../../shared/models/course.dart';
import '../../../shared/mock/mock_data.dart';
import '../../../shared/widgets/attendance_progress.dart';
import '../../../shared/widgets/statistic_card.dart';
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
    _load();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final appState = context.read<CourseController>();
    final auth = context.read<AuthController>();
    await appState.fetchStudentCourses();
    if (!mounted) return;
    setState(() {
      _courses = appState.courses;
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

  String _greetingEmoji() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '☀️';
    if (hour < 17) return '🌤️';
    return '🌙';
  }

  List<_TodayClass> get _todayClasses {
    if (_courses.isEmpty) return [];
    final states = [
      ClassSessionState.attendanceOpen,
      ClassSessionState.upcoming,
      ClassSessionState.completed,
      ClassSessionState.missed,
    ];
    return List.generate(
      _courses.length.clamp(0, 4),
      (i) => _TodayClass(_courses[i], states[i % states.length]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AuthController>();
    final student = appState.currentUser is Student
        ? appState.currentUser as Student
        : MockData.demoStudent;

    final below = _courses
        .where((c) => c.eligibility != AttendanceEligibility.eligible)
        .length;
    final attended = _courses.fold<int>(0, (sum, c) => sum + c.classesAttended);
    final missed = _courses.fold<int>(0, (sum, c) => sum + c.classesMissed);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          OfflineBanner(isOnline: appState.isOnline),
          Expanded(
            child: _isLoading
                ? const LoadingState(message: 'Loading your dashboard…')
                : RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.primary,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        children: [
                          // ─── Greeting Header ───────────────────────
                          _GreetingHeader(
                            greeting: _greeting(),
                            emoji: _greetingEmoji(),
                            firstName: student.fullName.split(' ').first,
                            studentId: student.studentId,
                            semester: student.semester,
                            isOnline: appState.isOnline,
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          // ─── Overall Attendance Card ───────────────
                          _OverallAttendanceCard(
                            student: student,
                            belowCount: below,
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          // ─── Today's Classes ───────────────────────
                          _SectionHeader(
                            title: "Today's Classes",
                            subtitle: _todayClasses.isEmpty
                                ? null
                                : '${_todayClasses.length} session${_todayClasses.length == 1 ? '' : 's'}',
                            icon: Icons.calendar_today_rounded,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (_todayClasses.isEmpty)
                            const _EmptyState(
                              icon: Icons.event_available_rounded,
                              message: 'No classes scheduled for today',
                              subtitle: 'Enjoy your free day! 🎉',
                            )
                          else
                            ..._todayClasses.asMap().entries.map((entry) {
                              final index = entry.key;
                              final tc = entry.value;
                              return _AnimatedListItem(
                                index: index,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm,
                                  ),
                                  child: _TodayClassCard(
                                    data: tc,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => CourseDetailsScreen(
                                          courseId: tc.course.id,
                                        ),
                                      ),
                                    ),
                                    onMarkAttendance: () =>
                                        Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => MarkAttendanceFlow(
                                          course: tc.course,
                                        ),
                                        fullscreenDialog: true,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),

                          const SizedBox(height: AppSpacing.lg),

                          // ─── Attendance Summary ────────────────────
                          const _SectionHeader(
                            title: 'Attendance Summary',
                            icon: Icons.insights_rounded,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: AppSpacing.sm,
                            mainAxisSpacing: AppSpacing.sm,
                            childAspectRatio: 1.45,
                            children: [
                              StatisticCard(
                                label: 'Attended',
                                value: '$attended',
                                icon: Icons.check_circle_outline_rounded,
                                accentColor: AppColors.success,
                              ),
                              StatisticCard(
                                label: 'Missed',
                                value: '$missed',
                                icon: Icons.cancel_outlined,
                                accentColor: AppColors.error,
                              ),
                              StatisticCard(
                                label: 'Overall',
                                value:
                                    '${student.overallAttendancePercentage.toStringAsFixed(0)}%',
                                icon: Icons.pie_chart_outline_rounded,
                                accentColor: AppColors.primary,
                              ),
                              StatisticCard(
                                label: 'At Risk',
                                value: '$below',
                                icon: Icons.warning_amber_rounded,
                                accentColor: AppColors.warning,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xl),
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

// ─────────────────────────────────────────────────────────────
// Greeting Header
// ─────────────────────────────────────────────────────────────
class _GreetingHeader extends StatelessWidget {
  final String greeting;
  final String emoji;
  final String firstName;
  final String studentId;
  final String semester;
  final bool isOnline;

  const _GreetingHeader({
    required this.greeting,
    required this.emoji,
    required this.firstName,
    required this.studentId,
    required this.semester,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                height: 30,
              ),
              Row(
                children: [
                  Text(
                    '$greeting, ',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                  ),
                  Text(
                    firstName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(width: 6),
                  Text(emoji, style: const TextStyle(fontSize: 22)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.badge_outlined,
                    label: studentId,
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.school_outlined,
                    label: semester,
                  ),
                ],
              ),
            ],
          ),
        ),
        // Avatar
        // Container(
        //   width: 52,
        //   height: 52,
        //   decoration: BoxDecoration(
        //     gradient: LinearGradient(
        //       colors: [
        //         AppColors.primary,
        //         AppColors.primary.withValues(alpha: .7),
        //       ],
        //       begin: Alignment.topLeft,
        //       end: Alignment.bottomRight,
        //     ),
        //     borderRadius: BorderRadius.circular(16),
        //     boxShadow: [
        //       BoxShadow(
        //         color: AppColors.primary.withValues(alpha: .25),
        //         blurRadius: 12,
        //         offset: const Offset(0, 4),
        //       ),
        //     ],
        //   ),
        //   child: Center(
        //     child: Text(
        //       firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
        //       style: const TextStyle(
        //         color: Colors.white,
        //         fontSize: 22,
        //         fontWeight: FontWeight.w700,
        //       ),
        //     ),
        //   ),
        // ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outline.withValues(alpha: .5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textTertiary),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 9,
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Overall Attendance Card
// ─────────────────────────────────────────────────────────────
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
                    Text(
                      'Overall Attendance',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isGood
                      ? "You're in good standing across your registered courses."
                      : 'Your attendance is below the required threshold in some courses.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 10),
                StatusBadge(
                  label: belowCount == 0
                      ? 'All courses on track'
                      : '$belowCount course(s) below threshold',
                  tone:
                      belowCount == 0 ? StatusTone.success : StatusTone.warning,
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

// ─────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────
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
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────
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
        border: Border.all(color: AppColors.outline.withValues(alpha: .5)),
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
                  fontWeight: FontWeight.w600,
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

// ─────────────────────────────────────────────────────────────
// Animated List Item
// ─────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────
// Today Class Card
// ─────────────────────────────────────────────────────────────
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
                : AppColors.outline.withValues(alpha: .5),
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
                    children: [
                      // Accent bar
                      Container(
                        width: 3,
                        height: 40,
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course.code,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              course.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(label: label, tone: tone, icon: icon),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _MetaItem(
                        icon: Icons.access_time_rounded,
                        text: course.schedule.timeRangeLabel,
                      ),
                      const SizedBox(width: 16),
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
                            fontWeight: FontWeight.w600,
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

// ─────────────────────────────────────────────────────────────
// Meta Item (time / venue)
// ─────────────────────────────────────────────────────────────
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
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
        ),
      ],
    );
  }
}

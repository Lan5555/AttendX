import 'package:attendx/controllers/auth_controller.dart';
import 'package:attendx/controllers/course_controller.dart';
import 'package:attendx/controllers/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/lecturer.dart';
import '../../../shared/models/course.dart';
import '../../../shared/models/attendance_session.dart';
import '../../../shared/widgets/statistic_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../sessions/attendance_session_screen.dart';

class LecturerDashboardScreen extends StatefulWidget {
  const LecturerDashboardScreen({super.key});

  @override
  State<LecturerDashboardScreen> createState() =>
      _LecturerDashboardScreenState();
}

class _LecturerDashboardScreenState extends State<LecturerDashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Course> _courses = [];

  late final AnimationController _entranceController;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;

    final courseController = context.read<CourseController>();
    final sessionController = context.read<SessionController>();

    await Future.wait([
      courseController.fetchLecturerCourses(),
      sessionController.fetchTodaySessions(),
    ]);

    if (!mounted) return;

    setState(() {
      _courses = courseController.lecturerCourses;
      _isLoading = false;
    });
    _entranceController.forward();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _openSession(AttendanceSession session) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttendanceSessionScreen(session: session),
        fullscreenDialog: true,
      ),
    );

    if (!mounted) return;
    await context.read<SessionController>().fetchTodaySessions();
  }

  Future<void> _startNewSession() async {
    if (_courses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have no courses to start a session for.'),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<Course>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose a course',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _courses.length,
                itemBuilder: (_, i) {
                  final c = _courses[i];
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.menu_book_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(
                      c.code,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      c.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textTertiary,
                    ),
                    onTap: () => Navigator.of(sheetContext).pop(c),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;

    final placeholder = AttendanceSession(
      id: '',
      courseId: selected.id,
      courseCode: selected.code,
      courseTitle: selected.title,
      timeRangeLabel: 'Starting now',
      venue: selected.schedule.venue,
      totalStudents: 0,
      status: SessionStatus.upcoming,
    );

    await _openSession(placeholder);
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthController>();
    final sessionState = context.watch<SessionController>();

    final lecturer = authState.currentUser is Lecturer
        ? authState.currentUser as Lecturer
        : null;

    final sessions = sessionState.todaySessions;

    // Find any session currently active or paused.
    AttendanceSession? liveSession;
    for (final s in sessions) {
      if (s.status == SessionStatus.active ||
          s.status == SessionStatus.paused) {
        liveSession = s;
        break;
      }
    }

    final avgAttendance = _courses.isEmpty
        ? 0.0
        : _courses.fold<double>(
                0, (sum, c) => sum + c.attendancePercentage) /
            _courses.length;

    final totalPresentToday =
        sessions.fold<int>(0, (sum, s) => sum + s.presentCount);

    // Upcoming sessions = scheduled today but not yet started.
    final upcomingSessions = sessions
        .where((s) => s.status == SessionStatus.upcoming)
        .toList();
    final completedSessions = sessions
        .where((s) => s.status == SessionStatus.completed)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNewSession,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.play_arrow_rounded, size: 20),
        label: const Text(
          'Start Session',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          OfflineBanner(isOnline: authState.isOnline),
          Expanded(
            child: _isLoading
                ? const LoadingState(message: 'Loading your dashboard…')
                : RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.primary,
                    child: FadeTransition(
                      opacity: _fadeIn,
                      child: CustomScrollView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        slivers: [
                          // ── Hero header ─────────────────────────────
                          SliverToBoxAdapter(
                            child: _HeroHeader(
                              greeting: _greeting(),
                              lecturer: lecturer,
                            ),
                          ),

                          // ── Live session banner ─────────────────────
                          if (liveSession != null)
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.lg,
                                AppSpacing.md,
                                AppSpacing.lg,
                                0,
                              ),
                              sliver: SliverToBoxAdapter(
                                child: _LiveSessionBanner(
                                  session: liveSession,
                                  onTap: () => _openSession(liveSession!),
                                ),
                              ),
                            ),

                          // ── Stats grid ──────────────────────────────
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.lg,
                              AppSpacing.lg,
                              0,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisSpacing: AppSpacing.sm,
                                mainAxisSpacing: AppSpacing.sm,
                                childAspectRatio: 1.45,
                                children: [
                                  StatisticCard(
                                    label: 'Total Courses',
                                    value: '${_courses.length}',
                                    icon: Icons.menu_book_rounded,
                                  ),
                                  StatisticCard(
                                    label: "Today's Sessions",
                                    value: '${sessions.length}',
                                    icon: Icons.event_note_rounded,
                                    accentColor: AppColors.info,
                                  ),
                                  StatisticCard(
                                    label: 'Students Present',
                                    value: '$totalPresentToday',
                                    icon: Icons.people_alt_rounded,
                                    accentColor: AppColors.success,
                                  ),
                                  StatisticCard(
                                    label: 'Attendance Rate',
                                    value:
                                        '${avgAttendance.toStringAsFixed(0)}%',
                                    icon: Icons.insights_rounded,
                                    accentColor: AppColors.primary,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // ── Today's Sessions header ─────────────────
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
                                  Text(
                                    "Today's Sessions",
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (sessions.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: .1),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        '${sessions.length}',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  const Spacer(),
                                  if (sessions.isNotEmpty)
                                    Text(
                                      '${completedSessions.length} done · ${upcomingSessions.length} upcoming',
                                      style: const TextStyle(
                                        color: AppColors.textTertiary,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          // ── Session list / loading / empty ──────────
                          if (sessionState.isLoadingToday)
                            const SliverPadding(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                              ),
                              sliver: SliverToBoxAdapter(
                                child: _SessionsLoadingCard(),
                              ),
                            )
                          else if (sessions.isEmpty)
                            const SliverPadding(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                              ),
                              sliver: SliverToBoxAdapter(
                                child: _EmptySessionsCard(),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                              ),
                              sliver: SliverList.separated(
                                itemCount: sessions.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (_, i) => _SessionCard(
                                  session: sessions[i],
                                  onStart: () => _openSession(sessions[i]),
                                ),
                              ),
                            ),

                          const SliverToBoxAdapter(
                            child: SizedBox(height: 96),
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
class _HeroHeader extends StatelessWidget {
  final String greeting;
  final Lecturer? lecturer;

  const _HeroHeader({required this.greeting, required this.lecturer});

  @override
  Widget build(BuildContext context) {
    final firstName = lecturer?.fullName.split(' ').last ?? 'Lecturer';
    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : 'L';

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg + 12,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryLight.withValues(alpha: .18),
            AppColors.primaryLight.withValues(alpha: .04),
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${lecturer?.title ?? ''} $firstName'.trim(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (lecturer?.staffId != null) ...[
                      _InfoPill(
                        icon: Icons.badge_outlined,
                        label: lecturer!.staffId!,
                      ),
                    ],
                    if (lecturer?.staffId != null &&
                        lecturer?.department != null)
                      const SizedBox(width: 6),
                    if (lecturer?.department != null)
                      Flexible(
                        child: _InfoPill(
                          icon: Icons.school_outlined,
                          label: lecturer!.department!,
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.textTertiary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// LIVE SESSION BANNER
// ─────────────────────────────────────────────────────────────────────
class _LiveSessionBanner extends StatelessWidget {
  final AttendanceSession session;
  final VoidCallback onTap;
  const _LiveSessionBanner({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final paused = session.status == SessionStatus.paused;
    final color = paused ? AppColors.warning : AppColors.success;

    return Material(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: color.withValues(alpha: .35)),
          ),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .2),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      paused
                          ? Icons.pause_rounded
                          : Icons.qr_code_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          paused ? 'PAUSED' : 'LIVE NOW',
                          style: TextStyle(
                            color: color,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${session.courseCode} · ${session.presentCount} present',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: color,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// SESSION CARD
// ─────────────────────────────────────────────────────────────────────
class _SessionCard extends StatelessWidget {
  final AttendanceSession session;
  final VoidCallback onStart;
  const _SessionCard({required this.session, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final isActive = session.status == SessionStatus.active;
    final isCompleted = session.status == SessionStatus.completed;
    final isPaused = session.status == SessionStatus.paused;

    final String statusLabel;
    final StatusTone statusTone;
    if (isActive) {
      statusLabel = 'Active';
      statusTone = StatusTone.success;
    } else if (isPaused) {
      statusLabel = 'Paused';
      statusTone = StatusTone.warning;
    } else if (isCompleted) {
      statusLabel = 'Completed';
      statusTone = StatusTone.neutral;
    } else {
      statusLabel = 'Upcoming';
      statusTone = StatusTone.info;
    }

    final String buttonLabel;
    final IconData buttonIcon;
    if (isActive || isPaused) {
      buttonLabel = 'Resume Attendance';
      buttonIcon = Icons.play_arrow_rounded;
    } else if (isCompleted) {
      buttonLabel = 'View Summary';
      buttonIcon = Icons.assessment_outlined;
    } else {
      buttonLabel = 'Start Attendance';
      buttonIcon = Icons.qr_code_rounded;
    }

    final accentColor = isActive
        ? AppColors.success
        : isPaused
            ? AppColors.warning
            : isCompleted
                ? AppColors.textTertiary
                : AppColors.info;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isActive
              ? AppColors.success.withValues(alpha: .35)
              : isPaused
                  ? AppColors.warning.withValues(alpha: .35)
                  : AppColors.outline,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.courseCode,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        session.courseTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(label: statusLabel, tone: statusTone),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _MetaItem(
                  icon: Icons.access_time_rounded,
                  label: session.timeRangeLabel,
                ),
                _MetaItem(
                  icon: Icons.location_on_outlined,
                  label: session.venue,
                ),
                _MetaItem(
                  icon: Icons.people_alt_outlined,
                  label: '${session.totalStudents} students',
                ),
                if (isActive || isPaused)
                  _MetaItem(
                    icon: Icons.check_circle_outline_rounded,
                    label: '${session.presentCount} present',
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onStart,
                icon: Icon(buttonIcon, size: 18),
                label: Text(buttonLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActive
                      ? AppColors.success
                      : isPaused
                          ? AppColors.warning
                          : AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}

class _SessionsLoadingCard extends StatelessWidget {
  const _SessionsLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _EmptySessionsCard extends StatelessWidget {
  const _EmptySessionsCard();

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
              color: AppColors.primary.withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No sessions scheduled today',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap the button below to start a session for any of your courses.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}
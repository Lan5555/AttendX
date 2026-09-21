import 'package:attendx/controllers/auth_controller.dart';
import 'package:attendx/controllers/course_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
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
  List<AttendanceSession> _sessions = [];

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
    _load();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final appState = context.read<CourseController>();
    await appState.fetchLecturerCourses();
    if (!mounted) return;
    setState(() {
      _courses = appState.lecturerCourses;
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

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AuthController>();
    final lecturer = appState.currentUser is Lecturer
        ? appState.currentUser as Lecturer
        : null;

    final avgAttendance = _courses.isEmpty
        ? 0.0
        : _courses.fold<double>(
                0, (sum, c) => sum + c.attendancePercentage) /
            _courses.length;
    final totalPresentToday =
        _sessions.fold<int>(0, (sum, s) => sum + s.presentCount);

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
                      opacity: _fadeIn,
                      child: CustomScrollView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        slivers: [
                          SliverToBoxAdapter(
                            child: _HeroHeader(
                              greeting: _greeting(),
                              lecturer: lecturer,
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
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
                                    value: '${_sessions.length}',
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
                                  if (_sessions.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: .1),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        '${_sessions.length}',
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
                          if (_sessions.isEmpty)
                            const SliverPadding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg),
                              sliver: SliverToBoxAdapter(
                                child: _EmptySessionsCard(),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg),
                              sliver: SliverList.separated(
                                itemCount: _sessions.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (_, i) => _SessionCard(
                                  session: _sessions[i],
                                  onStart: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AttendanceSessionScreen(
                                          session: _sessions[i]),
                                      fullscreenDialog: true,
                                    ),
                                  ),
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
        AppSpacing.lg,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20,),
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
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (lecturer?.staffId != null) ...[
                      const Icon(
                        Icons.badge_outlined,
                        size: 13,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        lecturer!.staffId!,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                      ),
                    ],
                    if (lecturer?.staffId != null &&
                        lecturer?.department != null)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '•',
                          style: TextStyle(color: AppColors.textTertiary),
                        ),
                      ),
                    if (lecturer?.department != null)
                      Flexible(
                        child: Text(
                          lecturer!.department!,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textTertiary,
                                  ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: .28),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: AppColors.onPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
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

    final String statusLabel;
    final StatusTone statusTone;
    if (isActive) {
      statusLabel = 'Active';
      statusTone = StatusTone.success;
    } else if (isCompleted) {
      statusLabel = 'Completed';
      statusTone = StatusTone.neutral;
    } else {
      statusLabel = 'Upcoming';
      statusTone = StatusTone.info;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isActive
              ? AppColors.success.withValues(alpha: .35)
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
                    color: isActive
                        ? AppColors.success
                        : isCompleted
                            ? AppColors.textTertiary
                            : AppColors.info,
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
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.qr_code_rounded, size: 18),
                label: const Text('Start Attendance'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isActive ? AppColors.success : AppColors.primary,
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

// ─────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────
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
            "Your upcoming classes will appear here when it's time to take attendance.",
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
import 'package:attendx/controllers/course_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/course.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/empty_state.dart';
import 'create_course_screen.dart';
import 'edit_course_screen.dart';
import '../records/attendance_records_screen.dart';

enum _LoadState { loading, error, empty, loaded }

class LecturerCoursesScreen extends StatefulWidget {
  const LecturerCoursesScreen({super.key});

  @override
  State<LecturerCoursesScreen> createState() => _LecturerCoursesScreenState();
}

class _LecturerCoursesScreenState extends State<LecturerCoursesScreen> {
  _LoadState _state = _LoadState.loading;
  List<Course> _courses = [];
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(
      () => setState(() => _query = _searchController.text.trim().toLowerCase()),
    );
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    try {
      final courseHandler = context.read<CourseController>();
      await courseHandler.fetchLecturerCourses();
      if (!mounted) return;
      setState(() {
        _courses = courseHandler.lecturerCourses;
        _state = courseHandler.lecturerCourses.isEmpty
            ? _LoadState.empty
            : _LoadState.loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = _LoadState.error);
    }
  }

  Future<void> _createCourse() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const CreateCourseScreen(),
        fullscreenDialog: true,
      ),
    );
    if (created == true) _load();
  }

  List<Course> get _filtered {
    if (_query.isEmpty) return _courses;
    return _courses.where((c) {
      return c.code.toLowerCase().contains(_query) ||
          c.title.toLowerCase().contains(_query) ||
          c.department.toLowerCase().contains(_query);
    }).toList();
  }

  // Summary stats
  int get _totalStudents =>
      _courses.fold<int>(0, (s, c) => s + c.enrolledStudents);

  double get _avgAttendance {
    if (_courses.isEmpty) return 0;
    final total = _courses.fold<double>(
      0,
      (s, c) => s + c.attendancePercentage,
    );
    return total / _courses.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _state == _LoadState.loading
            ? const LoadingState(message: 'Loading your courses…')
            : _state == _LoadState.error
                ? _buildErrorState()
                : _state == _LoadState.empty
                    ? _buildEmptyState()
                    : _buildLoadedState(),
      ),
      floatingActionButton: _state == _LoadState.loaded ||
              _state == _LoadState.empty
          ? FloatingActionButton.extended(
              onPressed: _createCourse,
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Create Course',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
    );
  }

  Widget _buildErrorState() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.xl),
        ErrorState(
          title: 'Could not load courses',
          message: 'Please check your connection and try again.',
          onRetry: _load,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: const [
        SizedBox(height: AppSpacing.xl),
        EmptyState(
          icon: Icons.menu_book_outlined,
          title: 'No courses created yet',
          message: 'Tap "Create Course" to set up your first course.',
        ),
      ],
    );
  }

  Widget _buildLoadedState() {
    final courses = _filtered;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // ── Header ─────────────────────────────────────────────────
          SliverToBoxAdapter(child: _buildHeader()),

          // ── Search bar ─────────────────────────────────────────────
          if (_courses.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              sliver: SliverToBoxAdapter(child: _buildSearchBar()),
            ),

          // ── Section label ─────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  const Text(
                    'All Courses',
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
                      '${courses.length}',
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

          // ── List ──────────────────────────────────────────────────
          if (courses.isEmpty)
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              sliver: SliverToBoxAdapter(
                child: _NoMatchCard(),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
              ),
              sliver: SliverList.separated(
                itemCount: courses.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) => _CourseTile(
                  course: courses[i],
                  onEdit: () async {
                    final updated = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) =>
                            EditCourseScreen(course: courses[i]),
                      ),
                    );
                    if (updated == true) _load();
                  },
                  onManageStudents: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AttendanceRecordsScreen(
                        initialCourseId: courses[i].id,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'My Courses',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              Material(
                color: AppColors.surface,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {},
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.filter_list_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Manage your courses and track attendance.',
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: .9),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Summary strip
          Row(
            children: [
              _SummaryStat(
                label: 'Courses',
                value: '${_courses.length}',
                icon: Icons.menu_book_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              _SummaryStat(
                label: 'Students',
                value: '$_totalStudents',
                icon: Icons.people_alt_rounded,
                color: AppColors.success,
              ),
              const SizedBox(width: 8),
              _SummaryStat(
                label: 'Avg Attendance',
                value: '${_avgAttendance.toStringAsFixed(0)}%',
                icon: Icons.insights_rounded,
                color: AppColors.info,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // SEARCH
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: 'Search by code, title, or department',
        hintStyle: const TextStyle(
          color: AppColors.textTertiary,
          fontSize: 13.5,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 20,
          color: AppColors.textTertiary,
        ),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
                onPressed: () => _searchController.clear(),
              ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// SUMMARY STAT
// ─────────────────────────────────────────────────────────────────────
class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// COURSE TILE
// ─────────────────────────────────────────────────────────────────────
class _CourseTile extends StatelessWidget {
  final Course course;
  final VoidCallback onEdit;
  final VoidCallback onManageStudents;
  const _CourseTile({
    required this.course,
    required this.onEdit,
    required this.onManageStudents,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
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
            // ── Top row: code + status pill ───────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    course.code,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const Spacer(),
                _EligibilityPill(eligibility: course.eligibility),
              ],
            ),
            const SizedBox(height: 10),

            // ── Title + description ───────────────────────────────────
            Text(
              course.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            if (course.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                course.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ],
            const SizedBox(height: 12),

            // ── Meta chips ─────────────────────────────────────────────
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MetaChip(
                  icon: Icons.star_rounded,
                  label: '${course.creditUnits} units',
                ),
                _MetaChip(
                  icon: Icons.calendar_today_rounded,
                  label: course.schedule.day,
                ),
                _MetaChip(
                  icon: Icons.schedule_rounded,
                  label:
                      '${course.schedule.startTime}–${course.schedule.endTime}',
                ),
                _MetaChip(
                  icon: Icons.place_rounded,
                  label: course.schedule.venue,
                ),
                _MetaChip(
                  icon: Icons.people_alt_outlined,
                  label:
                      '${course.enrolledStudents}/${course.maxStudents} enrolled',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Progress bar ──────────────────────────────────────────
            _AttendanceBar(course: course),
            const SizedBox(height: 14),

            // ── Actions ────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.outline),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: onManageStudents,
                    icon: const Icon(Icons.fact_check_outlined, size: 16),
                    label: const Text('Attendance'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// ATTENDANCE BAR
// ─────────────────────────────────────────────────────────────────────
class _AttendanceBar extends StatelessWidget {
  final Course course;
  const _AttendanceBar({required this.course});

  @override
  Widget build(BuildContext context) {
    final pct = course.attendancePercentage.clamp(0, 100).toDouble();
    final Color color;
    switch (course.eligibility) {
      case AttendanceEligibility.eligible:
        color = AppColors.success;
        break;
      case AttendanceEligibility.atRisk:
        color = AppColors.warning;
        break;
      case AttendanceEligibility.ineligible:
        color = AppColors.error;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Attendance',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${pct.toStringAsFixed(0)}%',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '• ${course.classesAttended}/${course.classesHeld} classes',
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 6,
            backgroundColor: AppColors.outline,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// ELIGIBILITY PILL
// ─────────────────────────────────────────────────────────────────────
class _EligibilityPill extends StatelessWidget {
  final AttendanceEligibility eligibility;
  const _EligibilityPill({required this.eligibility});

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (eligibility) {
      AttendanceEligibility.eligible => (
          'Eligible',
          AppColors.success,
          AppColors.successBg,
        ),
      AttendanceEligibility.atRisk => (
          'At risk',
          AppColors.warning,
          AppColors.warningBg,
        ),
      AttendanceEligibility.ineligible => (
          'Ineligible',
          AppColors.error,
          AppColors.errorBg,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// META CHIP
// ─────────────────────────────────────────────────────────────────────
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textTertiary),
          const SizedBox(width: 4),
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
// NO MATCH CARD
// ─────────────────────────────────────────────────────────────────────
class _NoMatchCard extends StatelessWidget {
  const _NoMatchCard();

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
              Icons.search_off_rounded,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'No matching courses',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try a different code, title, or department.',
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
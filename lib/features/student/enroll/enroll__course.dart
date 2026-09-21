import 'package:attendx/controllers/auth_controller.dart';
import 'package:attendx/services/course_service.dart';
import 'package:attendx/shared/models/course.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';

// ── Palette ────────────────────────────────────────────────────────────
class _C {
  static const blue = Color(0xFF1E6FE8);
  static const blueDark = Color(0xFF1554B0);
  static const blueSoft = Color(0xFFE8F0FE);
  static const white = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF4F7FC);
  static const border = Color(0xFFE3EAF3);
  static const textPrimary = Color(0xFF0F1B2D);
  static const textSecondary = Color(0xFF5A6B82);
  static const textMuted = Color(0xFF8A9BB3);
  static const success = Color(0xFF16A34A);
}

enum _SortOption {
  defaultOrder,
  level100,
  level200,
  level300,
  level400,
  levelAsc,
  levelDesc,
  department,
  unitsDesc,
  titleAsc,
}

extension _SortOptionX on _SortOption {
  String get label => switch (this) {
        _SortOption.defaultOrder => 'Default',
        _SortOption.level100 => '100 Level',
        _SortOption.level200 => '200 Level',
        _SortOption.level300 => '300 Level',
        _SortOption.level400 => '400 Level',
        _SortOption.levelAsc => 'All levels (low → high)',
        _SortOption.levelDesc => 'All levels (high → low)',
        _SortOption.department => 'Department (A → Z)',
        _SortOption.unitsDesc => 'Credit units (high → low)',
        _SortOption.titleAsc => 'Title (A → Z)',
      };

  IconData get icon => switch (this) {
        _SortOption.defaultOrder => Icons.sort_rounded,
        _SortOption.level100 => Icons.filter_1_rounded,
        _SortOption.level200 => Icons.filter_2_rounded,
        _SortOption.level300 => Icons.filter_3_rounded,
        _SortOption.level400 => Icons.filter_4_rounded,
        _SortOption.levelAsc => Icons.arrow_upward_rounded,
        _SortOption.levelDesc => Icons.arrow_downward_rounded,
        _SortOption.department => Icons.apartment_rounded,
        _SortOption.unitsDesc => Icons.star_rounded,
        _SortOption.titleAsc => Icons.sort_by_alpha_rounded,
      };
}

class EnrollCoursesScreen extends StatefulWidget {
  const EnrollCoursesScreen({super.key});

  @override
  State<EnrollCoursesScreen> createState() => _EnrollCoursesScreenState();
}

class _EnrollCoursesScreenState extends State<EnrollCoursesScreen> {
  final _searchController = TextEditingController();
  final _courseService = CourseService();

  List<Course> _catalogue = [];
  final Set<String> _enrolledIds = {};
  final Set<String> _pendingIds = {};

  bool _loading = true;
  String? _loadError;
  _SortOption _sort = _SortOption.defaultOrder;

  @override
  void initState() {
    super.initState();
    _loadCatalogue();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogue() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    final response = await _courseService.fetchAllCourses();

    if (!mounted) return;

    if (!response.success) {
      setState(() {
        _loading = false;
        _loadError = response.message;
      });
      return;
    }

    final rawCourses = response.data['items'];

    if (rawCourses is! List) {
      setState(() {
        _loading = false;
        _loadError = 'Invalid course data received from server.';
      });
      return;
    }

    final courses = rawCourses
        .map((course) => Course.fromJson(course as Map<String, dynamic>))
        .toList();

    setState(() {
      _catalogue = courses;
      _loading = false;
    });
  }

  Future<void> _enroll(Course course) async {
    setState(() => _pendingIds.add(course.id));

    final response = await _courseService.enrollStudent(
      course.id,
      {"studentId": context.read<AuthController>().currentUser?.id},
    );

    if (!mounted) return;

    setState(() => _pendingIds.remove(course.id));

    if (!response.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message)),
      );
      return;
    }

    setState(() => _enrolledIds.add(course.id));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Enrolled in ${course.code}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Derives a level from the first digit of the numeric part of the code.
  /// "CSC 301" -> 300, "MTH 102" -> 100, "PHY 405" -> 400.
  /// Returns 0 if no digit is found, so unparseable codes sort last.
  int _levelOf(Course course) {
    final match = RegExp(r'\d').firstMatch(course.code);
    if (match == null) return 0;
    final firstDigit = int.parse(match.group(0)!);
    return firstDigit * 100;
  }

  List<Course> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _catalogue;
    return _catalogue.where((c) {
      return c.code.toLowerCase().contains(q) ||
          c.title.toLowerCase().contains(q) ||
          c.department.toLowerCase().contains(q);
    }).toList();
  }

  List<Course> get _sorted {
    final list = List<Course>.from(_filtered);
    switch (_sort) {
      case _SortOption.defaultOrder:
        return list;

      // Level-band filters: keep only that band, sorted by code.
      case _SortOption.level100:
        return list.where((c) => _levelOf(c) == 100).toList()
          ..sort((a, b) => a.code.compareTo(b.code));
      case _SortOption.level200:
        return list.where((c) => _levelOf(c) == 200).toList()
          ..sort((a, b) => a.code.compareTo(b.code));
      case _SortOption.level300:
        return list.where((c) => _levelOf(c) == 300).toList()
          ..sort((a, b) => a.code.compareTo(b.code));
      case _SortOption.level400:
        return list.where((c) => _levelOf(c) == 400).toList()
          ..sort((a, b) => a.code.compareTo(b.code));

      case _SortOption.levelAsc:
        list.sort((a, b) => _levelOf(a).compareTo(_levelOf(b)));
        return list;
      case _SortOption.levelDesc:
        list.sort((a, b) => _levelOf(b).compareTo(_levelOf(a)));
        return list;

      case _SortOption.department:
        list.sort((a, b) =>
            a.department.toLowerCase().compareTo(b.department.toLowerCase()));
        return list;
      case _SortOption.unitsDesc:
        list.sort((a, b) => b.creditUnits.compareTo(a.creditUnits));
        return list;
      case _SortOption.titleAsc:
        list.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        return list;
    }
  }

  bool get _isLevelBand =>
      _sort == _SortOption.level100 ||
      _sort == _SortOption.level200 ||
      _sort == _SortOption.level300 ||
      _sort == _SortOption.level400;

  Future<void> _openSortSheet() async {
    final selected = await showModalBottomSheet<_SortOption>(
      context: context,
      backgroundColor: _C.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _C.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sort by',
                  style: TextStyle(
                    color: _C.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (final option in _SortOption.values)
                  ListTile(
                    leading: Icon(
                      option.icon,
                      color: option == _sort ? _C.blue : _C.textMuted,
                    ),
                    title: Text(
                      option.label,
                      style: TextStyle(
                        color: option == _sort ? _C.blue : _C.textPrimary,
                        fontWeight:
                            option == _sort ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    trailing: option == _sort
                        ? const Icon(Icons.check_rounded, color: _C.blue)
                        : null,
                    onTap: () => Navigator.of(context).pop(option),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) {
      setState(() => _sort = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.white,
      appBar: AppBar(
        backgroundColor: _C.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _C.textPrimary,
        title: const Text(
          'Enroll in Courses',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: _C.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: _C.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by code, title, or department',
                hintStyle: const TextStyle(color: _C.textMuted),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: _C.textMuted),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: _C.textMuted),
                        onPressed: () => _searchController.clear(),
                      ),
                filled: true,
                fillColor: _C.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: const BorderSide(color: _C.blue, width: 1.4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SortButton(
            active: _sort != _SortOption.defaultOrder,
            onTap: _openSortSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(_C.blue),
        ),
      );
    }

    if (_loadError != null) {
      return _buildErrorState(_loadError!);
    }

    final courses = _sorted;

    if (courses.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadCatalogue,
      color: _C.blue,
      backgroundColor: _C.white,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        itemCount: courses.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _CourseEnrollCard(
          course: courses[i],
          enrolled: _enrolledIds.contains(courses[i].id),
          pending: _pendingIds.contains(courses[i].id),
          onEnroll: () => _enroll(courses[i]),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: _C.textMuted, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _C.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: _loadCatalogue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final searching = _searchController.text.trim().isNotEmpty;

    final String message;
    if (searching) {
      message = 'No courses match your search.';
    } else if (_isLevelBand) {
      message = 'No courses in this level yet.';
    } else {
      message = 'No courses available right now.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching ? Icons.search_off_rounded : Icons.menu_book_rounded,
              color: _C.textMuted,
              size: 48,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _C.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _SortButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? _C.blueSoft : _C.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          child: Icon(
            Icons.tune_rounded,
            color: active ? _C.blue : _C.textMuted,
          ),
        ),
      ),
    );
  }
}

class _CourseEnrollCard extends StatelessWidget {
  final Course course;
  final bool enrolled;
  final bool pending;
  final VoidCallback onEnroll;

  const _CourseEnrollCard({
    required this.course,
    required this.enrolled,
    required this.pending,
    required this.onEnroll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: enrolled ? _C.blue.withValues(alpha: .5) : _C.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  course.code,
                  style: const TextStyle(
                    color: _C.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (pending)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(_C.blue),
                  ),
                )
              else if (enrolled)
                const _EnrolledPill(),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            course.title,
            style: const TextStyle(
              color: _C.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (course.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              course.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _C.textSecondary, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MetaChip(icon: Icons.school_rounded, label: course.department),
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
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: enrolled ? 'Enrolled' : 'Enroll',
              icon: enrolled
                  ? Icons.check_circle_rounded
                  : Icons.add_circle_outline_rounded,
              onPressed: (enrolled || pending) ? null : onEnroll,
            ),
          ),
        ],
      ),
    );
  }
}

class _EnrolledPill extends StatelessWidget {
  const _EnrolledPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _C.blueSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _C.blue.withValues(alpha: .3)),
      ),
      child: const Text(
        'Enrolled',
        style: TextStyle(
          color: _C.blueDark,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _C.textMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: _C.textSecondary, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}
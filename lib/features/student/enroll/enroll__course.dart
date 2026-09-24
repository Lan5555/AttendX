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
  static const successBg = Color(0xFFE4F6EE);
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

  bool get isFilter => switch (this) {
        _SortOption.level100 ||
        _SortOption.level200 ||
        _SortOption.level300 ||
        _SortOption.level400 =>
          true,
        _ => false,
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCatalogue());
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogue() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final response = await _courseService.fetchAllCourses();
      if (!mounted) return;

      if (!response.success) {
        setState(() {
          _loading = false;
          _loadError = response.message;
        });
        return;
      }

      final dynamic data = response.data;
      List<dynamic> rawCourses;
      if (data is List) {
        rawCourses = data;
      } else if (data is Map<String, dynamic> && data['items'] is List) {
        rawCourses = data['items'] as List;
      } else {
        setState(() {
          _loading = false;
          _loadError = 'Invalid course data received from server.';
        });
        return;
      }

      final courses = <Course>[];
      for (final item in rawCourses) {
        if (item is! Map<String, dynamic>) continue;
        try {
          courses.add(Course.fromJson(item));
        } catch (e) {
          debugPrint('Failed to parse course: $e');
        }
      }

      setState(() {
        _catalogue = courses;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Something went wrong loading courses.';
      });
      debugPrint('_loadCatalogue error: $e');
    }
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

  int _levelOf(Course course) {
    final match = RegExp(r'\d').firstMatch(course.code);
    if (match == null) return 0;
    return int.parse(match.group(0)!) * 100;
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

  Future<void> _openSortSheet() async {
    final selected = await showModalBottomSheet<_SortOption>(
      context: context,
      backgroundColor: _C.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
            ),
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
                  'Sort & Filter',
                  style: TextStyle(
                    color: _C.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
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
                              fontWeight: option == _sort
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          trailing: option == _sort
                              ? const Icon(Icons.check_rounded, color: _C.blue)
                              : null,
                          onTap: () => Navigator.of(sheetContext).pop(option),
                        ),
                    ],
                  ),
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
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: _C.white,
        border: Border(
          bottom: BorderSide(color: _C.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: back + title
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: _C.textPrimary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 22,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Enroll in Courses',
                  style: TextStyle(
                    color: _C.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.only(left: 34),
            child: Text(
              'Browse the catalogue and join your courses.',
              style: TextStyle(
                color: _C.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Search + sort row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(
                    color: _C.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search courses…',
                    hintStyle: const TextStyle(
                      color: _C.textMuted,
                      fontSize: 13.5,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: _C.textMuted,
                    ),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: _C.textMuted,
                            ),
                            onPressed: () => _searchController.clear(),
                          ),
                    filled: true,
                    fillColor: _C.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(
                        color: _C.blue,
                        width: 1.4,
                      ),
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

          // Active sort chip
          if (_sort != _SortOption.defaultOrder) ...[
            const SizedBox(height: AppSpacing.sm),
            _ActiveSortChip(
              label: _sort.label,
              icon: _sort.icon,
              isFilter: _sort.isFilter,
              onClear: () => setState(() => _sort = _SortOption.defaultOrder),
            ),
          ],

          // Result count
          if (!_loading && _loadError == null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${_sorted.length} course${_sorted.length == 1 ? '' : 's'} available',
              style: const TextStyle(
                color: _C.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // BODY
  // ─────────────────────────────────────────────────────────────────────
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
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        itemCount: courses.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
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
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _C.surface,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.cloud_off_rounded,
                color: _C.textMuted,
                size: 30,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _C.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
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

    final String title;
    final String message;
    if (searching) {
      title = 'No matching courses';
      message = 'Try a different code, title, or department.';
    } else if (_sort.isFilter) {
      title = 'No courses in this level';
      message = 'Try another level from the sort menu.';
    } else {
      title = 'No courses available';
      message = 'Check back later — new courses appear here when published.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _C.surface,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                searching ? Icons.search_off_rounded : Icons.menu_book_rounded,
                color: _C.textMuted,
                size: 30,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: const TextStyle(
                color: _C.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _C.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// SORT BUTTON
// ─────────────────────────────────────────────────────────────────────
class _SortButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _SortButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? _C.blue : _C.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.tune_rounded,
                color: active ? _C.white : _C.textMuted,
              ),
              if (active)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: _C.white,
                      shape: BoxShape.circle,
                    ),
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
// ACTIVE SORT CHIP
// ─────────────────────────────────────────────────────────────────────
class _ActiveSortChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isFilter;
  final VoidCallback onClear;

  const _ActiveSortChip({
    required this.label,
    required this.icon,
    required this.isFilter,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _C.blueSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _C.blue.withValues(alpha: .25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _C.blueDark),
          const SizedBox(width: 6),
          Text(
            isFilter ? 'Filtered: $label' : 'Sorted: $label',
            style: const TextStyle(
              color: _C.blueDark,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onClear,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _C.blue.withValues(alpha: .15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.close_rounded,
                size: 11,
                color: _C.blueDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// COURSE CARD
// ─────────────────────────────────────────────────────────────────────
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
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: enrolled ? _C.blue.withValues(alpha: .4) : _C.border,
          width: enrolled ? 1.4 : 1,
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
            // ── Top row: code pill + status ─────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _C.blue.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    course.code,
                    style: const TextStyle(
                      color: _C.blue,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const Spacer(),
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
            const SizedBox(height: 10),

            // ── Title ────────────────────────────────────────────────
            Text(
              course.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _C.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),

            // ── Lecturer ─────────────────────────────────────────────
            if (course.lecturerName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 13,
                    color: _C.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      course.lecturerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // ── Description ──────────────────────────────────────────
            if (course.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                course.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _C.textSecondary,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 12),

            // ── Meta chips ───────────────────────────────────────────
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MetaChip(
                  icon: Icons.school_rounded,
                  label: course.department,
                ),
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
                  label: course.schedule.timeRangeLabel,
                ),
                _MetaChip(
                  icon: Icons.place_rounded,
                  label: course.schedule.venue,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Enroll button ────────────────────────────────────────
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// ENROLLED PILL
// ─────────────────────────────────────────────────────────────────────
class _EnrolledPill extends StatelessWidget {
  const _EnrolledPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _C.successBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _C.success.withValues(alpha: .3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 11,
            color: _C.success,
          ),
          const SizedBox(width: 4),
          Text(
            'Enrolled',
            style: TextStyle(
              color: _C.success,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
            style: const TextStyle(
              color: _C.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

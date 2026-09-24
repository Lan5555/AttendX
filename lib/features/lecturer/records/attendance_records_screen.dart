import 'package:attendx/controllers/course_controller.dart';
import 'package:attendx/features/lecturer/export/export_screen.dart';
import 'package:attendx/services/attendance_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/course.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/empty_state.dart';
import 'student_attendance_detail_screen.dart';

enum _AttendanceFilter { all, present, absent }

class _RosterRecord {
  final String name;
  final String id;
  final DateTime date;
  final String time;
  final bool present;
  final String sessionId;

  const _RosterRecord({
    required this.name,
    required this.id,
    required this.date,
    required this.time,
    required this.present,
    required this.sessionId,
  });
}

/// One attendance session's roster, grouped for display.
class _SessionGroup {
  final String sessionId;
  final DateTime date;
  final List<_RosterRecord> records;

  const _SessionGroup({
    required this.sessionId,
    required this.date,
    required this.records,
  });

  int get presentCount => records.where((r) => r.present).length;
  int get absentCount => records.length - presentCount;
  double get rate =>
      records.isEmpty ? 0 : (presentCount / records.length) * 100;

  String get dateLabel => DateFormat('EEEE, d MMMM').format(date);
}

Course? _findCourseById(List<Course> courses, String id) {
  for (final c in courses) {
    if (c.id == id) return c;
  }
  return null;
}

class AttendanceRecordsScreen extends StatefulWidget {
  final String? initialCourseId;
  const AttendanceRecordsScreen({super.key, this.initialCourseId});

  @override
  State<AttendanceRecordsScreen> createState() =>
      _AttendanceRecordsScreenState();
}

class _AttendanceRecordsScreenState extends State<AttendanceRecordsScreen> {
  final _attendanceService = AttendanceService();
  final _searchController = TextEditingController();

  bool _isLoading = true;
  bool _recordsLoading = false;

  List<Course> _courses = [];
  Course? _selectedCourse;

  _AttendanceFilter _filter = _AttendanceFilter.all;
  String _studentQuery = '';

  final Map<String, List<_RosterRecord>> _recordsCache = {};
  final Map<String, String> _recordsError = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(
      () => setState(() => _studentQuery = _searchController.text),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final courseHandler = context.read<CourseController>();
    await courseHandler.fetchLecturerCourses();

    if (!mounted) return;

    final courses = courseHandler.lecturerCourses;
    final selected = widget.initialCourseId != null
        ? _findCourseById(courses, widget.initialCourseId!)
        : (courses.isNotEmpty ? courses.first : null);

    setState(() {
      _courses = courses;
      _selectedCourse = selected;
      _isLoading = false;
    });

    if (selected != null) {
      await _loadRecordsFor(selected);
    }
  }

  Future<void> _loadRecordsFor(Course course, {bool force = false}) async {
    if (!force && _recordsCache.containsKey(course.id)) return;

    setState(() {
      _recordsLoading = true;
      _recordsError.remove(course.id);
    });

    final response = await _attendanceService.fetchCourseAttendance(course.id);

    if (!mounted) return;

    if (!response.success) {
      setState(() {
        _recordsLoading = false;
        _recordsError[course.id] = response.message;
      });
      return;
    }

    // Backend returns { items: [ ... ] } directly (a Map, not a List).
    final data = response.data;
    final List<dynamic> list;
    if (data is List) {
      list = data as List<dynamic>;
    } else if (data['items'] is List) {
      list = data['items'] as List;
    } else {
      list = const [];
    }

    final records = list.whereType<Map<String, dynamic>>().map((json) {
      final recordedAtRaw = json['date'] as String?;
      final recordedAt =
          (recordedAtRaw != null ? DateTime.tryParse(recordedAtRaw) : null) ??
              DateTime.now();

      return _RosterRecord(
        name: json['studentName'] as String? ?? 'Unknown student',
        id: json['studentId'] as String? ?? '',
        date: recordedAt,
        time: json['time'] as String? ??
            DateFormat('h:mm a').format(recordedAt),
        present: json['present'] as bool? ?? false,
        sessionId: json['sessionId'] as String? ?? '',
      );
    }).toList();

    setState(() {
      _recordsCache[course.id] = records;
      _recordsLoading = false;
    });
  }

  List<_RosterRecord> get _filteredRecords {
    final course = _selectedCourse;
    if (course == null) return [];

    var records = _recordsCache[course.id] ?? const <_RosterRecord>[];

    switch (_filter) {
      case _AttendanceFilter.present:
        records = records.where((r) => r.present).toList();
        break;
      case _AttendanceFilter.absent:
        records = records.where((r) => !r.present).toList();
        break;
      case _AttendanceFilter.all:
        break;
    }

    if (_studentQuery.trim().isNotEmpty) {
      final q = _studentQuery.toLowerCase();
      records = records
          .where((r) =>
              r.name.toLowerCase().contains(q) ||
              r.id.toLowerCase().contains(q))
          .toList();
    }

    return records;
  }

  /// Groups the filtered records by session, newest first. Falls back to
  /// grouping by calendar day if `sessionId` is missing.
  List<_SessionGroup> get _groupedBySession {
    final filtered = _filteredRecords;
    final map = <String, List<_RosterRecord>>{};
    final dates = <String, DateTime>{};

    for (final r in filtered) {
      final key = r.sessionId.isNotEmpty
          ? r.sessionId
          : DateFormat('yyyy-MM-dd').format(r.date);
      map.putIfAbsent(key, () => []).add(r);
      dates.putIfAbsent(key, () => r.date);
    }

    final groups = map.entries.map((e) {
      final sorted = List<_RosterRecord>.from(e.value)
        ..sort((a, b) => a.name.compareTo(b.name));
      return _SessionGroup(
        sessionId: e.key,
        date: dates[e.key]!,
        records: sorted,
      );
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return groups;
  }

  int get _presentCount =>
      _recordsCache[_selectedCourse?.id]?.where((r) => r.present).length ?? 0;

  int get _absentCount =>
      _recordsCache[_selectedCourse?.id]?.where((r) => !r.present).length ?? 0;

  int get _totalCount => _recordsCache[_selectedCourse?.id]?.length ?? 0;

  Future<void> _refreshCurrent() async {
    final course = _selectedCourse;
    if (course == null) return;
    await _loadRecordsFor(course, force: true);
  }

  Future<void> _openCoursePicker() async {
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
                  final isSelected = c.id == _selectedCourse?.id;
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.menu_book_rounded,
                        size: 18,
                        color: isSelected
                            ? AppColors.onPrimary
                            : AppColors.primary,
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
                    trailing: isSelected
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.primary)
                        : null,
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
    setState(() => _selectedCourse = selected);
    await _loadRecordsFor(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const LoadingState(message: 'Loading records…')
            : _courses.isEmpty
                ? const EmptyState(
                    icon: Icons.fact_check_outlined,
                    title: 'No courses yet',
                    message:
                        'Create a course to start tracking attendance records.',
                  )
                : Column(
                    children: [
                      _buildHeader(),
                      Expanded(child: _buildRecordsBody()),
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
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(bottom: BorderSide(color: AppColors.outline)),
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
            0,
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.textPrimary,
                ),
              ),
              const Expanded(
                child: Text(
                  'Attendance Records',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_selectedCourse != null)
                IconButton(
                  tooltip: 'Export attendance',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ExportScreen(
                        preselectedCourseId: _selectedCourse!.id,
                      ),
                    ),
                  ),
                  icon: const Icon(
                    Icons.file_download_outlined,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            0,
          ),
          child: _CoursePickerTile(
            course: _selectedCourse,
            onTap: _openCoursePicker,
          ),
        ),
        if (_selectedCourse != null && !_recordsLoading) ...[
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
            ),
            child: Row(
              children: [
                _SummaryStat(
                  label: 'Present',
                  value: '$_presentCount',
                  color: AppColors.success,
                ),
                const SizedBox(width: 8),
                _SummaryStat(
                  label: 'Absent',
                  value: '$_absentCount',
                  color: AppColors.error,
                ),
                const SizedBox(width: 8),
                _SummaryStat(
                  label: 'Total',
                  value: '$_totalCount',
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'Search by name or ID',
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
              fillColor: AppColors.surfaceAlt,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.4),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                count: _totalCount,
                selected: _filter == _AttendanceFilter.all,
                onTap: () =>
                    setState(() => _filter = _AttendanceFilter.all),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Present',
                count: _presentCount,
                selected: _filter == _AttendanceFilter.present,
                onTap: () =>
                    setState(() => _filter = _AttendanceFilter.present),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Absent',
                count: _absentCount,
                selected: _filter == _AttendanceFilter.absent,
                onTap: () =>
                    setState(() => _filter = _AttendanceFilter.absent),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
  // ─────────────────────────────────────────────────────────────────────
  // BODY
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildRecordsBody() {
    final course = _selectedCourse;
    if (course == null) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No course selected',
        message: 'Pick a course to see its attendance records.',
      );
    }

    if (_recordsLoading) {
      return const LoadingState(message: 'Fetching records…');
    }

    final error = _recordsError[course.id];
    if (error != null) {
      return Center(
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
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: _refreshCurrent,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final groups = _groupedBySession;

    if (groups.isEmpty) {
      return EmptyState(
        icon: _studentQuery.isNotEmpty
            ? Icons.search_off_rounded
            : Icons.people_outline_rounded,
        title: _studentQuery.isNotEmpty
            ? 'No matching students'
            : (_filter == _AttendanceFilter.present
                ? 'No present students yet'
                : _filter == _AttendanceFilter.absent
                    ? 'No absent students'
                    : 'No attendance records yet'),
        message: _studentQuery.isNotEmpty
            ? 'Try a different name or ID.'
            : 'Records will appear here once students scan in.',
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshCurrent,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        itemCount: groups.length,
        itemBuilder: (context, i) {
          final group = groups[i];
          return _SessionSection(
            group: group,
            course: course,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// SESSION SECTION
// ─────────────────────────────────────────────────────────────────────
class _SessionSection extends StatelessWidget {
  final _SessionGroup group;
  final Course course;

  const _SessionSection({required this.group, required this.course});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  group.dateLabel,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _Pill(
                label: '${group.presentCount}/${group.records.length}',
                color: AppColors.success,
                icon: Icons.check_rounded,
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < group.records.length; i++) ...[
            _RecordTile(
              record: group.records[i],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StudentAttendanceDetailScreen(
                    studentName: group.records[i].name,
                    studentId: group.records[i].id,
                    course: course,
                    records: group.records.map((r) => StudentAttendanceEntry.fromJson(r)).toList(),
                  ),
                ),
              ),
            ),
            if (i != group.records.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _Pill({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// COURSE PICKER TILE
// ─────────────────────────────────────────────────────────────────────
class _CoursePickerTile extends StatelessWidget {
  final Course? course;
  final VoidCallback onTap;
  const _CoursePickerTile({required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.menu_book_rounded,
                  size: 18,
                  color: AppColors.onPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course?.code ?? 'Select a course',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (course != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        course!.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _MiniMeta(
                            icon: Icons.people_alt_outlined,
                            label: '${course!.enrolledStudents} enrolled',
                          ),
                          const SizedBox(width: 10),
                          _MiniMeta(
                            icon: Icons.event_available_rounded,
                            label: '${course!.classesHeld} held',
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.unfold_more_rounded,
                color: AppColors.textTertiary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniMeta extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: AppColors.textTertiary),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// SUMMARY STAT
// ─────────────────────────────────────────────────────────────────────
class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: .18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// RECORD TILE
// ─────────────────────────────────────────────────────────────────────
class _RecordTile extends StatelessWidget {
  final _RosterRecord record;
  final VoidCallback onTap;
  const _RecordTile({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final initial =
        record.name.isNotEmpty ? record.name[0].toUpperCase() : '?';
    final present = record.present;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: present ? AppColors.successBg : AppColors.errorBg,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: present ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.badge_outlined,
                          size: 12,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            record.id,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          record.time,
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(present: present),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool present;
  const _StatusPill({required this.present});

  @override
  Widget build(BuildContext context) {
    final color = present ? AppColors.success : AppColors.error;
    final bg = present ? AppColors.successBg : AppColors.errorBg;
    final label = present ? 'Present' : 'Absent';
    final icon = present ? Icons.check_circle_rounded : Icons.cancel_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// FILTER CHIP
// ─────────────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 7,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color:
                      selected ? AppColors.onPrimary : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.onPrimary.withValues(alpha: .22)
                      : AppColors.outline,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: selected
                        ? AppColors.onPrimary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
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
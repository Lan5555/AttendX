import 'package:attendx/controllers/course_controller.dart';
import 'package:attendx/services/attendance_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/course.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/status_badge.dart';
import 'student_attendance_detail_screen.dart';

enum _AttendanceFilter { all, present, absent }

class _RosterRecord {
  final String name;
  final String id;
  final DateTime date;
  final String time;
  final bool present;
  const _RosterRecord({
    required this.name,
    required this.id,
    required this.date,
    required this.time,
    required this.present,
  });
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

  bool _isLoading = true;
  bool _recordsLoading = false;

  List<Course> _courses = [];
  Course? _selectedCourse;

  _AttendanceFilter _filter = _AttendanceFilter.all;
  String _studentQuery = '';

  /// Records cached per course id so switching courses doesn't refetch.
  final Map<String, List<_RosterRecord>> _recordsCache = {};

  /// Tracks which courses returned an error so the UI can show a retry.
  final Map<String, String> _recordsError = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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

    // Backend envelope: { success, message, data: { items: [ ... ] } }
    final data = response.data['data'];
    final raw = (data is Map<String, dynamic>) ? data['items'] : null;
    final list = raw is List ? raw : const [];

    final records = list.whereType<Map<String, dynamic>>().map((json) {
      final recordedAtRaw = json['recordedAt'] as String?;
      final recordedAt =
          (recordedAtRaw != null ? DateTime.tryParse(recordedAtRaw) : null) ??
              DateTime.now();

      return _RosterRecord(
        name: json['studentName'] as String? ?? 'Unknown student',
        id: json['studentId'] as String? ?? '',
        date: recordedAt,
        time: DateFormat('h:mm a').format(recordedAt),
        present: json['present'] as bool? ?? false,
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

  Future<void> _refreshCurrent() async {
    final course = _selectedCourse;
    if (course == null) return;
    await _loadRecordsFor(course, force: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Attendance Records'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        0,
                      ),
                      child: DropdownButtonFormField<Course>(
                        value: _selectedCourse,
                        decoration:
                            const InputDecoration(labelText: 'Course'),
                        items: _courses
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(
                                  '${c.code} — ${c.title}',
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (c) {
                          if (c == null) return;
                          setState(() => _selectedCourse = c);
                          _loadRecordsFor(c);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        0,
                      ),
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Search student',
                          prefixIcon: Icon(Icons.search_rounded, size: 20),
                        ),
                        onChanged: (v) => setState(() => _studentQuery = v),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        0,
                      ),
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'All',
                            selected: _filter == _AttendanceFilter.all,
                            onTap: () => setState(
                                () => _filter = _AttendanceFilter.all),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Present',
                            selected: _filter == _AttendanceFilter.present,
                            onTap: () => setState(
                                () => _filter = _AttendanceFilter.present),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Absent',
                            selected: _filter == _AttendanceFilter.absent,
                            onTap: () => setState(
                                () => _filter = _AttendanceFilter.absent),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(child: _buildRecordsBody()),
                  ],
                ),
    );
  }

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
              const Icon(Icons.cloud_off_rounded,
                  color: AppColors.textTertiary, size: 48),
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

    final records = _filteredRecords;

    if (records.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matching records',
        message: 'Try adjusting your filters or search term.',
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshCurrent,
      color: AppColors.primary,
      child: ListView.separated(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        itemCount: records.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final r = records[i];
          return Card(
            elevation: 0,
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: const BorderSide(color: AppColors.outline),
            ),
            child: ListTile(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StudentAttendanceDetailScreen(
                    studentName: r.name,
                    studentId: r.id,
                    course: course,
                  ),
                ),
              ),
              leading: CircleAvatar(
                backgroundColor:
                    AppColors.primary.withValues(alpha: .1),
                child: Text(
                  r.name.isNotEmpty ? r.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              title: Text(
                r.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
              subtitle: Text(
                '${r.id} • ${DateFormat('d MMM').format(r.date)} • ${r.time}',
                style: const TextStyle(fontSize: 11.5),
              ),
              trailing: StatusBadge(
                label: r.present ? 'Present' : 'Absent',
                tone: r.present ? StatusTone.success : StatusTone.error,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary.withValues(alpha: .12),
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
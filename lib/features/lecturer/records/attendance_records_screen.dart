import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/models/course.dart';
import '../../../shared/mock/mock_data.dart';
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
  const _RosterRecord({required this.name, required this.id, required this.date, required this.time, required this.present});
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
  State<AttendanceRecordsScreen> createState() => _AttendanceRecordsScreenState();
}

class _AttendanceRecordsScreenState extends State<AttendanceRecordsScreen> {
  bool _isLoading = true;
  List<Course> _courses = [];
  Course? _selectedCourse;
  _AttendanceFilter _filter = _AttendanceFilter.all;
  String _studentQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final courses = await context.read<AppState>().courseService.getLecturerCourses();
    if (!mounted) return;
    setState(() {
      _courses = courses;
      _selectedCourse = widget.initialCourseId != null
          ? _findCourseById(courses, widget.initialCourseId!)
          : (courses.isNotEmpty ? courses.first : null);
      _isLoading = false;
    });
  }

  List<_RosterRecord> _recordsFor(Course course) {
    final now = DateTime.now();
    return List.generate(MockData.mockRoster.length, (i) {
      final entry = MockData.mockRoster[i];
      final present = (i + course.classesAttended) % 4 != 0;
      return _RosterRecord(
        name: entry['name']!,
        id: entry['id']!,
        date: now.subtract(Duration(days: i)),
        time: entry['time']!,
        present: present,
      );
    });
  }

  List<_RosterRecord> get _filteredRecords {
    if (_selectedCourse == null) return [];
    var records = _recordsFor(_selectedCourse!);
    if (_filter == _AttendanceFilter.present) records = records.where((r) => r.present).toList();
    if (_filter == _AttendanceFilter.absent) records = records.where((r) => !r.present).toList();
    if (_studentQuery.trim().isNotEmpty) {
      final q = _studentQuery.toLowerCase();
      records = records.where((r) => r.name.toLowerCase().contains(q) || r.id.toLowerCase().contains(q)).toList();
    }
    return records;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Records')),
      body: _isLoading
          ? const LoadingState(message: 'Loading records…')
          : _courses.isEmpty
              ? const EmptyState(icon: Icons.fact_check_outlined, title: 'No courses yet', message: 'Create a course to start tracking attendance records.')
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                      child: DropdownButtonFormField<Course>(
                        value: _selectedCourse,
                        decoration: const InputDecoration(labelText: 'Course'),
                        items: _courses.map((c) => DropdownMenuItem(value: c, child: Text('${c.code} — ${c.title}', style: const TextStyle(
                          fontSize: 14
                        ),))).toList(),
                        onChanged: (c) => setState(() => _selectedCourse = c),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Search student',
                          prefixIcon: Icon(Icons.search_rounded, size: 20),
                        ),
                        onChanged: (v) => setState(() => _studentQuery = v),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                      child: Row(
                        children: [
                          _FilterChip(label: 'All', selected: _filter == _AttendanceFilter.all, onTap: () => setState(() => _filter = _AttendanceFilter.all)),
                          const SizedBox(width: 8),
                          _FilterChip(label: 'Present', selected: _filter == _AttendanceFilter.present, onTap: () => setState(() => _filter = _AttendanceFilter.present)),
                          const SizedBox(width: 8),
                          _FilterChip(label: 'Absent', selected: _filter == _AttendanceFilter.absent, onTap: () => setState(() => _filter = _AttendanceFilter.absent)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: _filteredRecords.isEmpty
                          ? const EmptyState(icon: Icons.search_off_rounded, title: 'No matching records', message: 'Try adjusting your filters or search term.')
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                              itemCount: _filteredRecords.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final r = _filteredRecords[i];
                                return Card(
                                  child: ListTile(
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => StudentAttendanceDetailScreen(
                                          studentName: r.name,
                                          studentId: r.id,
                                          course: _selectedCourse!,
                                        ),
                                      ),
                                    ),
                                    leading: CircleAvatar(
                                      backgroundColor: AppColors.primary.withOpacity(0.1),
                                      child: Text(r.name[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                                    ),
                                    title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                    subtitle: Text('${r.id} • ${DateFormat('d MMM').format(r.date)} • ${r.time}',
                                        style: const TextStyle(fontSize: 11.5)),
                                    trailing: StatusBadge(
                                      label: r.present ? 'Present' : 'Absent',
                                      tone: r.present ? StatusTone.success : StatusTone.error,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary.withOpacity(0.12),
      labelStyle: TextStyle(color: selected ? AppColors.primary : AppColors.textSecondary, fontWeight: FontWeight.w600),
    );
  }
}

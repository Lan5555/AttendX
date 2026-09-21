import 'package:attendx/controllers/auth_controller.dart';
import 'package:attendx/controllers/course_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/models/course.dart';
import '../../../shared/widgets/course_card.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
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
          builder: (_) => const CreateCourseScreen(), fullscreenDialog: true),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Courses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCourse,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create Course'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Builder(builder: (context) {
          switch (_state) {
            case _LoadState.loading:
              return const LoadingState(message: 'Loading your courses…');
            case _LoadState.error:
              return ListView(children: [
                ErrorState(
                    title: 'Could not load courses',
                    message: 'Please check your connection and try again.',
                    onRetry: _load),
              ]);
            case _LoadState.empty:
              return ListView(children: const [
                EmptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'No courses created yet',
                  message: 'Tap "Create Course" to set up your first course.',
                ),
              ]);
            case _LoadState.loaded:
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 90),
                itemCount: _courses.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final course = _courses[i];
                  return CourseCard(
                    course: course,
                    isLecturerView: true,
                    onTap: () {},
                    onEdit: () async {
                      final updated = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                            builder: (_) => EditCourseScreen(course: course)),
                      );
                      if (updated == true) _load();
                    },
                    onManageStudents: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => AttendanceRecordsScreen(
                              initialCourseId: course.id)),
                    ),
                  );
                },
              );
          }
        }),
      ),
    );
  }
}

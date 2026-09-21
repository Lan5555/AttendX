import 'package:attendx/controllers/course_controller.dart';
import 'package:attendx/features/student/enroll/enroll__course.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/models/course.dart';
import '../../../shared/widgets/course_card.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/empty_state.dart';
import 'course_details_screen.dart';

enum _LoadState { loading, error, empty, loaded }

class StudentCoursesScreen extends StatefulWidget {
  const StudentCoursesScreen({super.key});

  @override
  State<StudentCoursesScreen> createState() => _StudentCoursesScreenState();
}

class _StudentCoursesScreenState extends State<StudentCoursesScreen> {
  _LoadState _state = _LoadState.loading;
  List<Course> _courses = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    final courseHandler = context.read<CourseController>();
    await courseHandler.fetchStudentCourses();
    if (!mounted) return;
    setState(() {
      _courses = courseHandler.courses;
      _state =
          courseHandler.courses.isEmpty ? _LoadState.empty : _LoadState.loaded;
    });
    // if (!mounted) return;
    // setState(() => _state = _LoadState.error);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Courses')),
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
                  message:
                      'Something went wrong while fetching your enrolled courses.',
                  onRetry: _load,
                ),
              ]);
            case _LoadState.empty:
              return ListView(children: const [
                EmptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'No courses yet',
                  message:
                      'Courses you are enrolled in will appear here once registration is complete.',
                ),
              ]);
            case _LoadState.loaded:
              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: _courses.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final course = _courses[i];
                  return CourseCard(
                    course: course,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) =>
                              CourseDetailsScreen(courseId: course.id)),
                    ),
                  );
                },
              );
          }
        }),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => const EnrollCoursesScreen()));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

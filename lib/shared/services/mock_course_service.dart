import '../models/course.dart';
import '../mock/mock_data.dart';
import 'course_service.dart';

class MockCourseService implements CourseService {
  final List<Course> _lecturerCourses = List.of(MockData.lecturerCourses);

  @override
  Future<List<Course>> getStudentCourses() async {
    await Future.delayed(const Duration(milliseconds: 700));
    return MockData.studentCourses;
  }

  @override
  Future<List<Course>> getLecturerCourses() async {
    await Future.delayed(const Duration(milliseconds: 700));
    return List.unmodifiable(_lecturerCourses);
  }

  @override
  Future<Course?> getCourseById(String id) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final all = [...MockData.studentCourses, ..._lecturerCourses];
    try {
      return all.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Course> createCourse(Course course) async {
    await Future.delayed(const Duration(milliseconds: 900));
    _lecturerCourses.add(course);
    return course;
  }

  @override
  Future<Course> updateCourse(Course course) async {
    await Future.delayed(const Duration(milliseconds: 900));
    final idx = _lecturerCourses.indexWhere((c) => c.id == course.id);
    if (idx != -1) _lecturerCourses[idx] = course;
    return course;
  }
}

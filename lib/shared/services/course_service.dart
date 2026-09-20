import '../models/course.dart';

/// Abstract course contract. Backed by [MockCourseService] for now;
/// a REST implementation will be swapped in without UI changes.
abstract class CourseService {
  Future<List<Course>> getStudentCourses();
  Future<List<Course>> getLecturerCourses();
  Future<Course?> getCourseById(String id);
  Future<Course> createCourse(Course course);
  Future<Course> updateCourse(Course course);
}

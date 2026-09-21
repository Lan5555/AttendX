import 'package:attendx/core/network/core_service.dart';

class CourseService extends CoreService {
  // GET /courses
  // Student: enrolled courses
  // Lecturer: courses they teach
  Future<APIResponse> fetchCourses() async {
    return fetch('/courses');
  }

  // POST /courses
  // Lecturer only
  Future<APIResponse> createCourse(
    Map<String, dynamic> payload,
  ) async {
    return send(
      '/courses',
      body: payload,
      method: 'POST',
    );
  }

  // GET /courses/:id
  // Role-aware course details
  Future<APIResponse> fetchCourse(String id) async {
    return fetch('/courses/$id');
  }

  // PATCH /courses/:id
  // Lecturer only - own courses
  Future<APIResponse> updateCourse(
    String id,
    Map<String, dynamic> payload,
  ) async {
    return send(
      '/courses/$id',
      body: payload,
      method: 'PATCH',
    );
  }

  // POST /courses/:id/enroll
  // Lecturer only
  Future<APIResponse> enrollStudent(
    String id,
    Map<String, dynamic> payload,
  ) async {
    return send(
      '/courses/$id/enroll',
      body: payload,
      method: 'POST',
    );
  }

  // GET /courses/:id/students
  // Lecturer only
  Future<APIResponse> fetchCourseStudents(String id) async {
    return fetch('/courses/$id/students');
  }

  Future<APIResponse> fetchAllCourses() async {
    return fetch('/courses/find-all');
  }
}

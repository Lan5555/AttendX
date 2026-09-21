import 'package:attendx/controllers/auth_controller.dart';
import 'package:attendx/services/course_service.dart';
import 'package:attendx/shared/models/course.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CourseController extends ChangeNotifier {
  List<Course> courses = [];
  List<Course> lecturerCourses = [];
  List<Course> lecturerEnrolledStudents = [];
  final CourseService _service = CourseService();
  bool isLoading = false;
  String? errorMessage;
  Course? courseData;

  Future<void> fetchStudentCourses() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final res = await _service.fetchCourses();
      if (res.success) {
        final data = res.data['items'];
        if (data is List) {
          courses = data
              .map(
                (course) => Course.fromJson(
                  course as Map<String, dynamic>,
                ),
              )
              .toList();
        } else {
          errorMessage = 'Invalid course data received from server.';
        }
      } else {
        errorMessage = res.message;
      }
    } catch (e) {
      errorMessage = 'Failed to load courses.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> findCourseById(String id) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final res = await _service.fetchCourse(id);
      if (res.success) {
        final data = Course.fromJson(res.data);
        courseData = data;
        notifyListeners();
      } else {
        errorMessage = res.message;
        notifyListeners();
      }
    } catch (e) {
      errorMessage = 'Failed to Load Content';
    }
  }

  Future<void> fetchLecturerCourses() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final res = await _service.fetchCourses();
      if (res.success) {
        final data = res.data['items'];
        if (data is List) {
          lecturerCourses = data
              .map(
                (course) => Course.fromJson(
                  course as Map<String, dynamic>,
                ),
              )
              .toList();
        } else {
          errorMessage = 'Invalid course data received from server.';
        }
      } else {
        errorMessage = res.message;
      }
    } catch (e) {
      errorMessage = 'Failed to load courses.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createCourse(
      Map<String, dynamic> payload, BuildContext context) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    final res = await _service.createCourse(payload);
    if (res.success) {
      final data = res.data['items'];
      if (data is List) {
        lecturerCourses = data
            .map(
              (course) => Course.fromJson(
                course as Map<String, dynamic>,
              ),
            )
            .toList();
      } else {
        errorMessage = 'Invalid course data received from server.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(res.message)));
        notifyListeners();
      }
    } else {
      errorMessage = res.message;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.message)));
      notifyListeners();
    }
    notifyListeners();
  }

  Future<void> updateCourse(
      String id, Map<String, dynamic> payload, BuildContext context) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    final res = await _service.updateCourse(id, payload);
    if (res.success) {
      // final data = res.data['items'];
      // if (data is List) {
      //   lecturerCourses = data
      //       .map(
      //         (course) => Course.fromJson(
      //           course as Map<String, dynamic>,
      //         ),
      //       )
      //       .toList();
      await fetchLecturerCourses();
      notifyListeners();
    } else {
      errorMessage = res.message;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.message)));
      notifyListeners();
    }
    notifyListeners();
  }

  Future<void> getLecturerCoursesEnrolledByStudents(
      BuildContext context) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    final auth = context.read<AuthController>();

    final res = await _service.fetchCourseStudents(auth.currentUser!.id);
    if (res.success) {
      final data = res.data['items'];
      if (data is List) {
        lecturerEnrolledStudents = data
            .map(
              (course) => Course.fromJson(
                course as Map<String, dynamic>,
              ),
            )
            .toList();
      } else {
        errorMessage = 'Invalid course data received from server.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(res.message)));
        notifyListeners();
      }
    } else {
      errorMessage = res.message;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.message)));
      notifyListeners();
    }
    notifyListeners();
  }
}

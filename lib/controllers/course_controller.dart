import 'package:attendx/controllers/auth_controller.dart';
import 'package:attendx/services/course_service.dart';
import 'package:attendx/shared/models/course.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

class CourseController extends ChangeNotifier {
  List<Course> courses = [];
  List<Course> lecturerCourses = [];
  List<Course> lecturerEnrolledStudents = [];
  final CourseService _service = CourseService();
  bool isLoading = false;
  String? errorMessage;
  Course? courseData;

  /// Notifies listeners, deferring until after the current frame if a
  /// build is in progress. Prevents "setState() called during build"
  /// when fetch methods are triggered from initState.
  void _safeNotify() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }

  Future<void> fetchStudentCourses() async {
    isLoading = true;
    errorMessage = null;
    _safeNotify();
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
      _safeNotify();
    }
  }

  Future<void> findCourseById(String id) async {
    isLoading = true;
    errorMessage = null;
    _safeNotify();
    try {
      final res = await _service.fetchCourse(id);
      if (res.success) {
        courseData = Course.fromJson(res.data);
      } else {
        errorMessage = res.message;
      }
    } catch (e) {
      errorMessage = 'Failed to Load Content';
    } finally {
      isLoading = false;
      _safeNotify();
    }
  }

  Future<void> fetchLecturerCourses() async {
    isLoading = true;
    errorMessage = null;
    _safeNotify();
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
      _safeNotify();
    }
  }

  Future<void> createCourse(
    Map<String, dynamic> payload,
    BuildContext context,
  ) async {
    isLoading = true;
    errorMessage = null;
    _safeNotify();

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
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(res.message)));
        }
      }
    } else {
      errorMessage = res.message;
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(res.message)));
      }
    }
    isLoading = false;
    _safeNotify();
  }

  Future<void> updateCourse(
    String id,
    Map<String, dynamic> payload,
    BuildContext context,
  ) async {
    isLoading = true;
    errorMessage = null;
    _safeNotify();

    final res = await _service.updateCourse(id, payload);
    if (res.success) {
      await fetchLecturerCourses();
      isLoading = false;
      _safeNotify();
    } else {
      errorMessage = res.message;
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(res.message)));
      }
      isLoading = false;
      _safeNotify();
    }
  }

  Future<void> getLecturerCoursesEnrolledByStudents(
    BuildContext context,
  ) async {
    isLoading = true;
    errorMessage = null;
    _safeNotify();

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
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(res.message)));
        }
      }
    } else {
      errorMessage = res.message;
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(res.message)));
      }
    }
    isLoading = false;
    _safeNotify();
  }
}

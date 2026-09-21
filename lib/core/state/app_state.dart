// import 'package:flutter/foundation.dart';
// import '../../shared/models/user.dart';
// import '../../shared/services/auth_service.dart';
// import '../../shared/services/course_service.dart';
// import '../../shared/services/attendance_service.dart';
// import '../../shared/services/session_service.dart';
// import '../../shared/services/verification_service.dart';
// import '../../shared/services/sync_service.dart';
// import '../../shared/services/export_service.dart';
// import '../../shared/services/mock_auth_service.dart';
// import '../../shared/services/mock_course_service.dart';
// import '../../shared/services/mock_attendance_service.dart';
// import '../../shared/services/mock_session_service.dart';
// import '../../shared/services/mock_verification_service.dart';
// import '../../shared/services/mock_sync_service.dart';
// import '../../shared/services/mock_export_service.dart';

// /// Root app state: current session + service locator. Services are
// /// declared as interfaces so mock implementations can be swapped for
// /// real REST-backed ones without changing any screen.
// class AppState extends ChangeNotifier {
//   AppState()
//       : authService = MockAuthService(),
//         courseService = MockCourseService(),
//         attendanceService = MockAttendanceService(),
//         sessionService = MockSessionService(),
//         verificationService = MockVerificationService(),
//         syncService = MockSyncService(),
//         exportService = MockExportService();

//   final AuthService authService;
//   final CourseService courseService;
//   final AttendanceService attendanceService;
//   final SessionService sessionService;
//   final VerificationService verificationService;
//   final SyncService syncService;
//   final ExportService exportService;

//   AppUser? get currentUser => authService.currentUser;

//   bool _isOnline = true;
//   bool get isOnline => _isOnline;

//   void setOnline(bool value) {
//     _isOnline = value;
//     if (syncService is MockSyncService) {
//       (syncService as MockSyncService).setOnline(value);
//     }
//     notifyListeners();
//   }

//   void refreshSession() => notifyListeners();

//   Future<void> logout() async {
//     await authService.logout();
//     notifyListeners();
//   }
// }

class AppConstants {
  AppConstants._();

  static const String appName = 'AttendX';
  static const String tagline = 'Secure Attendance. Smarter Campus.';

  /// Default demonstration attendance threshold (percentage).
  /// The backend will eventually provide this per-course/per-institution.
  static const double defaultAttendanceThreshold = 75.0;

  static const Duration qrRefreshInterval = Duration(seconds: 8);
  static const Duration qrCountdownTick = Duration(seconds: 1);
}

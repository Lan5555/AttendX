enum SyncStatus { synced, savedOffline, syncing }
enum RecordVerification { verified, failed }

class AttendanceRecord {
  final String id;
  final String courseCode;
  final String courseTitle;
  final DateTime date;
  final String time;
  final RecordVerification verification;
  final SyncStatus syncStatus;
  final String? studentName;
  final String? studentId;

  const AttendanceRecord({
    required this.id,
    required this.courseCode,
    required this.courseTitle,
    required this.date,
    required this.time,
    this.verification = RecordVerification.verified,
    this.syncStatus = SyncStatus.synced,
    this.studentName,
    this.studentId,
  });
}

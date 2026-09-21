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

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as String,
      courseCode: json['courseCode'] as String,
      courseTitle: json['courseTitle'] as String,
      date: DateTime.parse(json['date'] as String),
      time: json['time'] as String,
      verification: _verificationFromString(json['verification'] as String?),
      syncStatus: _syncStatusFromString(json['syncStatus'] as String?),
      studentName: json['studentName'] as String?,
      studentId: json['studentId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'courseCode': courseCode,
        'courseTitle': courseTitle,
        'date': date.toIso8601String(),
        'time': time,
        'verification': verification.name,
        'syncStatus': syncStatus.name,
        'studentName': studentName,
        'studentId': studentId,
      };

  static RecordVerification _verificationFromString(String? value) {
    return RecordVerification.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RecordVerification.verified,
    );
  }

  static SyncStatus _syncStatusFromString(String? value) {
    return SyncStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SyncStatus.synced,
    );
  }
}
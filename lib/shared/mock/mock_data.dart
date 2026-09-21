import '../models/student.dart';
import '../models/lecturer.dart';
import '../models/course.dart';
import '../models/course_schedule.dart';
import '../models/attendance_record.dart';
import '../models/attendance_session.dart';

/// Centralized mock/demo data. This is the ONLY place seed data lives,
/// so it is trivial to delete once real backend services are wired in.
class MockData {
  MockData._();

  static const Student demoStudent = Student(
    id: 'u_stu_1',
    fullName: 'Nicholas Johnson',
    email: 'nicholas.johnson@uniport.edu.ng',
    department: 'Computer Science',
    faculty: 'Faculty of Computing',
    studentId: 'CSC/21/1234',
    semester: 'Rain Semester, 2025/2026',
    overallAttendancePercentage: 86, accessToken: '',
  );

  static const Lecturer demoLecturer = Lecturer(
    id: 'u_lec_1',
    fullName: 'Samuel Johnson',
    email: 's.johnson@uniport.edu.ng',
    department: 'Computer Science',
    faculty: 'Faculty of Computing',
    staffId: 'STF/0042',
    title: 'Dr.', accessToken: '',
  );

  static final List<Course> studentCourses = [
    Course(
      id: 'c1',
      code: 'CSC 416',
      title: 'Software Engineering',
      description:
          'Principles of large-scale software design, architecture, testing and project management.',
      lecturerName: 'Dr. Samuel Johnson',
      creditUnits: 3,
      department: 'Computer Science',
      schedule: const CourseSchedule(
        day: 'Monday',
        startTime: '10:00 AM',
        endTime: '12:00 PM',
        venue: 'Lab 3',
      ),
      enrolledStudents: 84,
      classesHeld: 20,
      classesAttended: 18,
    ),
    Course(
      id: 'c2',
      code: 'CSC 408',
      title: 'Artificial Intelligence',
      description: 'Search, knowledge representation, machine learning foundations.',
      lecturerName: 'Prof. Amaka Eze',
      creditUnits: 3,
      department: 'Computer Science',
      schedule: const CourseSchedule(
        day: 'Tuesday',
        startTime: '8:00 AM',
        endTime: '10:00 AM',
        venue: 'LT 1',
      ),
      enrolledStudents: 96,
      classesHeld: 18,
      classesAttended: 11,
    ),
    Course(
      id: 'c3',
      code: 'CSC 412',
      title: 'Distributed Systems',
      description: 'Consensus, replication, distributed storage and networking.',
      lecturerName: 'Dr. Ibrahim Musa',
      creditUnits: 2,
      department: 'Computer Science',
      schedule: const CourseSchedule(
        day: 'Wednesday',
        startTime: '2:00 PM',
        endTime: '4:00 PM',
        venue: 'Lab 1',
      ),
      enrolledStudents: 70,
      classesHeld: 16,
      classesAttended: 8,
    ),
    Course(
      id: 'c4',
      code: 'GST 312',
      title: 'Peace and Conflict Resolution',
      description: 'General studies elective on peace studies.',
      lecturerName: 'Dr. Grace Bello',
      creditUnits: 2,
      department: 'General Studies',
      schedule: const CourseSchedule(
        day: 'Thursday',
        startTime: '12:00 PM',
        endTime: '1:00 PM',
        venue: 'LT 4',
      ),
      enrolledStudents: 210,
      classesHeld: 14,
      classesAttended: 14,
    ),
  ];

  static final List<Course> lecturerCourses = [
    Course(
      id: 'c1',
      code: 'CSC 416',
      title: 'Software Engineering',
      description:
          'Principles of large-scale software design, architecture, testing and project management.',
      lecturerName: 'Dr. Samuel Johnson',
      creditUnits: 3,
      department: 'Computer Science',
      schedule: const CourseSchedule(
        day: 'Monday',
        startTime: '10:00 AM',
        endTime: '12:00 PM',
        venue: 'Lab 3',
      ),
      enrolledStudents: 84,
      classesHeld: 20,
      classesAttended: 16, // avg class attendance for stats display
    ),
    Course(
      id: 'c5',
      code: 'CSC 301',
      title: 'Data Structures & Algorithms',
      description: 'Core data structures, complexity analysis and algorithm design.',
      lecturerName: 'Dr. Samuel Johnson',
      creditUnits: 3,
      department: 'Computer Science',
      schedule: const CourseSchedule(
        day: 'Wednesday',
        startTime: '9:00 AM',
        endTime: '11:00 AM',
        venue: 'LT 2',
      ),
      enrolledStudents: 132,
      classesHeld: 20,
      classesAttended: 19,
    ),
    Course(
      id: 'c6',
      code: 'CSC 350',
      title: 'Operating Systems',
      description: 'Processes, memory management, file systems and concurrency.',
      lecturerName: 'Dr. Samuel Johnson',
      creditUnits: 3,
      department: 'Computer Science',
      schedule: const CourseSchedule(
        day: 'Friday',
        startTime: '1:00 PM',
        endTime: '3:00 PM',
        venue: 'Lab 2',
      ),
      enrolledStudents: 58,
      classesHeld: 20,
      classesAttended: 14,
    ),
  ];

  static List<AttendanceRecord> studentHistory(String courseCode, String courseTitle) {
    final now = DateTime.now();
    return [
      AttendanceRecord(
        id: 'r1',
        courseCode: courseCode,
        courseTitle: courseTitle,
        date: now.subtract(const Duration(days: 0)),
        time: '10:42 AM',
        verification: RecordVerification.verified,
        syncStatus: SyncStatus.synced,
      ),
      AttendanceRecord(
        id: 'r2',
        courseCode: courseCode,
        courseTitle: courseTitle,
        date: now.subtract(const Duration(days: 7)),
        time: '10:05 AM',
        verification: RecordVerification.verified,
        syncStatus: SyncStatus.synced,
      ),
      AttendanceRecord(
        id: 'r3',
        courseCode: courseCode,
        courseTitle: courseTitle,
        date: now.subtract(const Duration(days: 9)),
        time: '10:52 AM',
        verification: RecordVerification.verified,
        syncStatus: SyncStatus.savedOffline,
      ),
      AttendanceRecord(
        id: 'r4',
        courseCode: courseCode,
        courseTitle: courseTitle,
        date: now.subtract(const Duration(days: 14)),
        time: '—',
        verification: RecordVerification.failed,
        syncStatus: SyncStatus.synced,
      ),
    ];
  }

  static List<AttendanceRecord> fullStudentHistory() {
    final all = <AttendanceRecord>[];
    for (final c in studentCourses) {
      all.addAll(studentHistory(c.code, c.title));
    }
    all.sort((a, b) => b.date.compareTo(a.date));
    return all;
  }

  static final List<Map<String, String>> mockRoster = [
    {'name': 'John Doe', 'id': 'CSC/21/1234', 'time': '10:42 AM'},
    {'name': 'Amaka Nwosu', 'id': 'CSC/21/1091', 'time': '10:41 AM'},
    {'name': 'Bello Fatima', 'id': 'CSC/21/1187', 'time': '10:40 AM'},
    {'name': 'Chinedu Okafor', 'id': 'CSC/21/1052', 'time': '10:39 AM'},
    {'name': 'Grace Effiong', 'id': 'CSC/21/1203', 'time': '10:38 AM'},
    {'name': 'Musa Ibrahim', 'id': 'CSC/21/1076', 'time': '10:37 AM'},
  ];

  static AttendanceSession get todaySessionForCsc416 => const AttendanceSession(
        id: 's1',
        courseId: 'c1',
        courseCode: 'CSC 416',
        courseTitle: 'Software Engineering',
        timeRangeLabel: '10:00 AM – 12:00 PM',
        venue: 'Lab 3',
        totalStudents: 84,
        presentCount: 0,
        status: SessionStatus.upcoming,
      );
}

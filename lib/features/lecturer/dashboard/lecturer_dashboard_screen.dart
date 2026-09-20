import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/models/lecturer.dart';
import '../../../shared/models/course.dart';
import '../../../shared/models/attendance_session.dart';
import '../../../shared/mock/mock_data.dart';
import '../../../shared/widgets/statistic_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../sessions/attendance_session_screen.dart';

class LecturerDashboardScreen extends StatefulWidget {
  const LecturerDashboardScreen({super.key});

  @override
  State<LecturerDashboardScreen> createState() => _LecturerDashboardScreenState();
}

class _LecturerDashboardScreenState extends State<LecturerDashboardScreen> {
  bool _isLoading = true;
  List<Course> _courses = [];
  List<AttendanceSession> _sessions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    final courses = await appState.courseService.getLecturerCourses();
    final sessions = await appState.sessionService.getTodaySessions();
    if (!mounted) return;
    setState(() {
      _courses = courses;
      _sessions = sessions;
      _isLoading = false;
    });
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final lecturer = appState.currentUser is Lecturer ? appState.currentUser as Lecturer : MockData.demoLecturer;

    final avgAttendance = _courses.isEmpty
        ? 0.0
        : _courses.fold<double>(0, (sum, c) => sum + c.attendancePercentage) / _courses.length;
    final totalPresentToday = _sessions.fold<int>(0, (sum, s) => sum + s.presentCount);

    return Scaffold(
      appBar: AppBar(title: Container(
        padding: const EdgeInsets.only(left: 10),
        child: 
        const Text(AppConstants.appName),
      ), ),
      body: Column(
        children: [
          OfflineBanner(isOnline: appState.isOnline),
          Expanded(
            child: _isLoading
                ? const LoadingState(message: 'Loading your dashboard…')
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        Text('${_greeting()}, ${lecturer.title} ${lecturer.fullName.split(' ').last}',
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 4),
                        Text('${lecturer.staffId} • ${lecturer.department}', style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: AppSpacing.lg),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: AppSpacing.sm,
                          mainAxisSpacing: AppSpacing.sm,
                          childAspectRatio: 1.5,
                          children: [
                            StatisticCard(label: 'Total Courses', value: '${_courses.length}', icon: Icons.menu_book_rounded),
                            StatisticCard(label: "Today's Sessions", value: '${_sessions.length}', icon: Icons.event_note_rounded),
                            StatisticCard(label: 'Students Present', value: '$totalPresentToday', icon: Icons.people_alt_rounded, accentColor: AppColors.success),
                            StatisticCard(label: 'Attendance Rate', value: '${avgAttendance.toStringAsFixed(0)}%', icon: Icons.insights_rounded, accentColor: AppColors.info),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text("Today's Sessions", style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: AppSpacing.sm),
                        if (_sessions.isEmpty)
                          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No sessions scheduled today.'))
                        else
                          ..._sessions.map((s) => Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: _SessionCard(
                                  session: s,
                                  onStart: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => AttendanceSessionScreen(session: s), fullscreenDialog: true),
                                  ),
                                ),
                              )),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final AttendanceSession session;
  final VoidCallback onStart;
  const _SessionCard({required this.session, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.courseCode, style: Theme.of(context).textTheme.titleMedium),
                      Text(session.courseTitle, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                StatusBadge(
                  label: session.status == SessionStatus.active ? 'Active' : (session.status == SessionStatus.completed ? 'Completed' : 'Upcoming'),
                  tone: session.status == SessionStatus.active
                      ? StatusTone.success
                      : session.status == SessionStatus.completed
                          ? StatusTone.neutral
                          : StatusTone.info,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(session.timeRangeLabel, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 12),
                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(session.venue, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 12),
                const Icon(Icons.people_alt_outlined, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text('${session.totalStudents} Students', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.qr_code_rounded, size: 18),
                label: const Text('Start Attendance'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

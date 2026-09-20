import 'package:flutter/material.dart';
import 'dashboard/lecturer_dashboard_screen.dart';
import 'courses/lecturer_courses_screen.dart';
import 'records/attendance_records_screen.dart';
import 'profile/lecturer_profile_screen.dart';

/// Root scaffold for the Lecturer role: bottom navigation across
/// Dashboard, Courses, Sessions (records) and Profile.
class LecturerShell extends StatefulWidget {
  const LecturerShell({super.key});

  @override
  State<LecturerShell> createState() => _LecturerShellState();
}

class _LecturerShellState extends State<LecturerShell> {
  int _index = 0;

  final _screens = const [
    LecturerDashboardScreen(),
    LecturerCoursesScreen(),
    AttendanceRecordsScreen(),
    LecturerProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book_rounded), label: 'Courses'),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner_outlined), selectedIcon: Icon(Icons.qr_code_scanner_rounded), label: 'Sessions'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

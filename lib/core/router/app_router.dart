import 'package:attendx/features/auth/ping-server.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/student/student_shell.dart';
import '../../features/lecturer/lecturer_shell.dart';

/// Top-level navigation only. Detail/flow screens (course details, the
/// mark-attendance flow, create/edit course, live session, etc.) are
/// pushed with Navigator.push from within each shell — this keeps the
/// route table small while still giving every screen a real back stack.
final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/ping', builder: (context, state) => const SplashScreenPing()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
    GoRoute(path: '/student', builder: (context, state) => const StudentShell()),
    GoRoute(path: '/lecturer', builder: (context, state) => const LecturerShell()),
  ],
);

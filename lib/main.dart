import 'package:attendx/controllers/attendance_controller.dart';
import 'package:attendx/controllers/auth_controller.dart';
import 'package:attendx/controllers/course_controller.dart';
import 'package:attendx/controllers/session_controller.dart';
import 'package:attendx/controllers/verification_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  runApp(const AttendXApp());
}

class AttendXApp extends StatelessWidget {
  const AttendXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>(
          create: (_) => AuthController(),
        ),

        ChangeNotifierProvider<CourseController>(
          create: (_) => CourseController(),
        ),

        ChangeNotifierProvider<AttendanceController>(
          create: (_) => AttendanceController(),
        ),

        ChangeNotifierProvider<SessionController>(
          create: (_) => SessionController(),
        ),

        ChangeNotifierProvider<VerificationController>(
          create: (_) => VerificationController(),
        ),
      ],
      child: MaterialApp.router(
        title: 'AttendX',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: appRouter,
      ),
    );
  }
}


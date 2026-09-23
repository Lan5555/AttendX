import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../controllers/session_controller.dart';
import '../../../shared/models/attendance_session.dart';
import '../../../shared/widgets/app_button.dart';
import 'session_summary_screen.dart';

class AttendanceSessionScreen extends StatefulWidget {
  final AttendanceSession session;
  const AttendanceSessionScreen({super.key, required this.session});

  @override
  State<AttendanceSessionScreen> createState() =>
      _AttendanceSessionScreenState();
}

class _AttendanceSessionScreenState extends State<AttendanceSessionScreen> {
  @override
  void initState() {
    super.initState();
    // Start the session after the first frame so we have a valid context
    // to read the controller.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SessionController>().startSession(widget.session.courseId);
    });
    
  }

  @override
  void dispose() {
    // Clear the controller state when this screen goes away so a stale
    // session doesn't leak into the next one.
    // Use scheduleMicrotask so we're not notifying during dispose.
    final controller = context.read<SessionController>();
    scheduleMicrotask(() => controller.clearActiveSession());
    super.dispose();
  }

  Future<void> _onTogglePause() async {
    await context.read<SessionController>().togglePause();
  }

  Future<void> _onEndPressed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End Session?'),
        content: const Text(
          'This will stop accepting new attendance scans for this class. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'End Session',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final summary =
        await context.read<SessionController>().endSession();

    if (!mounted || summary == null) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SessionSummaryScreen(session: summary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SessionController>();

    // Starting — spinner.
    if (controller.isStarting || controller.activeSession == null) {
      return const Scaffold(
        backgroundColor: AppColors.securityDark,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.securityAccent,
          ),
        ),
      );
    }

    // Start failed — error state.
    if (controller.error != null && controller.activeSession == null) {
      return Scaffold(
        backgroundColor: AppColors.securityDark,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    color: Colors.white54,
                    size: 48,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    controller.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Retry',
                    icon: Icons.refresh_rounded,
                    onPressed: () => context
                        .read<SessionController>()
                        .startSession(widget.session.courseId),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final session = controller.activeSession!;
    final paused = controller.isPaused;

    return Scaffold(
      backgroundColor: AppColors.securityDark,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          session.courseCode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          session.courseTitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .5),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              session.timeRangeLabel,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .5),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Status pill ──────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: (paused ? AppColors.warning : AppColors.success)
                    .withValues(alpha: .15),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                paused ? 'Attendance Paused' : 'Attendance Active',
                style: TextStyle(
                  color: paused ? AppColors.warning : AppColors.success,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── QR ───────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: paused
                  ? const SizedBox(
                      width: 200,
                      height: 200,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.pause_circle_outline_rounded,
                              color: AppColors.warning,
                              size: 56,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Paused',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : QrImageView(
                      data: controller.qrToken.isEmpty
                          ? 'attendx-session-${session.id}'
                          : controller.qrToken,
                      version: QrVersions.auto,
                      size: 200,
                      gapless: false,
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'QR refreshes automatically',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .5),
                fontSize: 12,
              ),
            ),
            Text(
              paused
                  ? 'Paused'
                  : 'Refreshes in ${controller.secondsUntilRefresh}s',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Present count ────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.securityDarkAlt,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.people_alt_rounded,
                    color: AppColors.securityAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Present: ${controller.presentCount} / ${session.totalStudents}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Bottom panel ─────────────────────────────────────────
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  0,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppRadius.xl),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Attendance',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: controller.presentCount == 0
                          ? const Center(
                              child: Text('Waiting for the first scan…'),
                            )
                          : Center(
                              child: Text(
                                '${controller.presentCount} student'
                                '${controller.presentCount == 1 ? '' : 's'} '
                                'marked present',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: paused
                                ? 'Resume'
                                : 'Pause Attendance',
                            variant: AppButtonVariant.outlined,
                            icon: paused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            onPressed:
                                controller.isEnding ? null : _onTogglePause,
                            fontSize: 9,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppButton(
                            label: controller.isEnding
                                ? 'Ending…'
                                : 'End Session',
                            variant: AppButtonVariant.danger,
                            icon: Icons.stop_circle_outlined,
                            onPressed:
                                controller.isEnding ? null : _onEndPressed,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
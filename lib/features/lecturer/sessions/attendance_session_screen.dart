import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/models/attendance_session.dart';
import '../../../shared/mock/mock_data.dart';
import '../../../shared/widgets/app_button.dart';
import 'session_summary_screen.dart';

/// Live lecturer attendance session: dynamic (mock) QR, live present
/// count and recent scans, pause/end controls. The QR payload and
/// TOTP-style rotation are mocked by [SessionService]; the real
/// cryptographic generation plugs into the same stream later.
class AttendanceSessionScreen extends StatefulWidget {
  final AttendanceSession session;
  const AttendanceSessionScreen({super.key, required this.session});

  @override
  State<AttendanceSessionScreen> createState() => _AttendanceSessionScreenState();
}

class _AttendanceSessionScreenState extends State<AttendanceSessionScreen> {
  AttendanceSession? _session;
  StreamSubscription<AttendanceSession>? _sub;
  Timer? _countdownTimer;
  int _secondsToRefresh = 8;
  bool _isStarting = true;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    // final appState = context.read<AppState>();
    // final started = await appState.sessionService.startSession(widget.session.courseId);
    // if (!mounted) return;
    // setState(() {
    //   _session = started;
    //   _isStarting = false;
    // });
    // _sub = appState.sessionService.watchSession(started.id).listen((s) {
    //   if (!mounted) return;
    //   setState(() {
    //     _session = s;
    //     _secondsToRefresh = 8;
    //   });
    // });
    // _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
    //   if (!mounted) return;
    //   setState(() {
    //     _secondsToRefresh = _secondsToRefresh > 0 ? _secondsToRefresh - 1 : 8;
    //   });
    // });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _togglePause() async {
    // final s = _session;
    // if (s == null) return;
    // final appState = context.read<AppState>();
    // if (s.status == SessionStatus.active) {
    //   final updated = await appState.sessionService.pauseSession(s.id);
    //   setState(() => _session = updated);
    // } else {
    //   // Resume by re-marking active locally (mock service keeps ticking only while active).
    //   setState(() => _session = s.copyWith(status: SessionStatus.active));
    // }
  }

  Future<void> _confirmEnd() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End Session?'),
        content: const Text('This will stop accepting new attendance scans for this class. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('End Session', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || _session == null) return;

    // final appState = context.read<AppState>();
    // final ended = await appState.sessionService.endSession(_session!.id);
    // if (!mounted) return;
    // Navigator.of(context).pushReplacement(
    //   MaterialPageRoute(builder: (_) => SessionSummaryScreen(session: ended)),
    // );
  }

  @override
  Widget build(BuildContext context) {
    if (_isStarting || _session == null) {
      return const Scaffold(
        backgroundColor: AppColors.securityDark,
        body: Center(child: CircularProgressIndicator(color: AppColors.securityAccent)),
      );
    }
    final session = _session!;
    final paused = session.status == SessionStatus.paused;

    return Scaffold(
      backgroundColor: AppColors.securityDark,
      body: SafeArea(
        child: Column(
          children: [
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
                        Text(session.courseCode, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                        Text(session.courseTitle, style: TextStyle(color: Colors.white.withValues(alpha: .5), fontSize: 11.5)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(session.timeRangeLabel, style: TextStyle(color: Colors.white.withValues(alpha: .5), fontSize: 12)),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: (paused ? AppColors.warning : AppColors.success).withValues(alpha: .15),
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: QrImageView(
                data: session.qrPayload.isEmpty ? 'attendx-session' : session.qrPayload,
                version: QrVersions.auto,
                size: 200,
                gapless: false,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('QR refreshes automatically', style: TextStyle(color: Colors.white.withValues(alpha: .5), fontSize: 12)),
            Text('Refreshes in ${_secondsToRefresh}s', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.md),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: AppColors.securityDarkAlt, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_alt_rounded, color: AppColors.securityAccent, size: 18),
                  const SizedBox(width: 8),
                  Text('Present: ${session.presentCount} / ${session.totalStudents}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recent Attendance', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: session.presentCount == 0
                          ? const Center(child: Text('Waiting for the first scan…'))
                          : ListView.separated(
                              itemCount: session.presentCount.clamp(0, MockData.mockRoster.length),
                              separatorBuilder: (_, __) => const Divider(height: 16),
                              itemBuilder: (context, i) {
                                final entry = MockData.mockRoster[i % MockData.mockRoster.length];
                                return Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppColors.successBg,
                                      child: Icon(Icons.check_rounded, color: AppColors.success, size: 16),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(entry['name']!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                          Text(entry['id']!, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                                        ],
                                      ),
                                    ),
                                    Text(entry['time']!, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                                  ],
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: paused ? 'Resume' : 'Pause Attendance',
                            variant: AppButtonVariant.outlined,
                            icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                            onPressed: _togglePause,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppButton(
                            label: 'End Session',
                            variant: AppButtonVariant.danger,
                            icon: Icons.stop_circle_outlined,
                            onPressed: _confirmEnd,
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

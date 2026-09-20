import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/models/course.dart';
import '../../../shared/models/attendance_verification.dart';
import '../../../shared/widgets/qr_scanner_frame.dart';
import '../../../shared/widgets/verification_step.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/status_badge.dart';

enum _FlowStage { scan, verifying, success, error }

/// The full mark-attendance journey: QR scan -> QR verify -> BLE proximity
/// -> face/liveness verification -> success. Every biometric/crypto/BLE
/// step here is mocked via [VerificationService]; only the UI states are
/// real — the actual sensors/algorithms plug in behind the same interface.
class MarkAttendanceFlow extends StatefulWidget {
  final Course course;
  const MarkAttendanceFlow({super.key, required this.course});

  @override
  State<MarkAttendanceFlow> createState() => _MarkAttendanceFlowState();
}

class _MarkAttendanceFlowState extends State<MarkAttendanceFlow> {
  _FlowStage _stage = _FlowStage.scan;
  bool _flashOn = false;
  AttendanceVerification _verification = const AttendanceVerification();
  StreamSubscription<AttendanceVerification>? _sub;
  String? _errorTitle;
  String? _errorMessage;
  DateTime? _recordedAt;
  bool _synced = true;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _simulateScan() {
    setState(() => _stage = _FlowStage.verifying);
    final appState = context.read<AppState>();
    _sub = appState.verificationService.runVerificationFlow().listen(
      (v) {
        setState(() => _verification = v);
        if (v.attendanceStatus == VerificationStageStatus.success) {
          _finish(appState);
        }
      },
      onError: (_) {
        setState(() {
          _stage = _FlowStage.error;
          _errorTitle = 'Verification Failed';
          _errorMessage = 'Something went wrong during verification. Please try again.';
        });
      },
    );
  }

  Future<void> _finish(AppState appState) async {
    final isOnline = appState.isOnline;
    await appState.attendanceService.recordAttendance(
      courseId: widget.course.id,
      courseCode: widget.course.code,
      courseTitle: widget.course.title,
      isOnline: isOnline,
    );
    if (!mounted) return;
    setState(() {
      _stage = _FlowStage.success;
      _recordedAt = DateTime.now();
      _synced = isOnline;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.securityDark,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: switch (_stage) {
            _FlowStage.scan => _buildScanStep(),
            _FlowStage.verifying => _buildVerifyingStep(),
            _FlowStage.success => _buildSuccessStep(),
            _FlowStage.error => _buildErrorStep(),
          },
        ),
      ),
    );
  }

  Widget _buildScanStep() {
    return Column(
      key: const ValueKey('scan'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => _flashOn = !_flashOn),
                icon: Icon(_flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
        const Spacer(),
        const Text('Scan Attendance QR',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Text(
            'Scan the QR code displayed by your lecturer.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const QrScannerFrame(),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: AppButton(
            label: 'Simulate QR Scan',
            icon: Icons.qr_code_scanner_rounded,
            onPressed: _simulateScan,
            width: double.infinity,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Text(
            'Camera scanning will connect to the device camera once the backend verification service is live.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _buildVerifyingStep() {
    final (title, subtitle, icon) = _activeStageContent();
    return Column(
      key: const ValueKey('verify'),
      children: [
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: VerificationStepper(verification: _verification),
        ),
        const Spacer(),
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.securityAccent.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: AppColors.securityAccent.withOpacity(0.16), shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.securityAccent, size: 36),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
        ),
        const SizedBox(height: AppSpacing.md),
        const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4, valueColor: AlwaysStoppedAnimation(AppColors.securityAccent)),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
        ),
      ],
    );
  }

  (String, String, IconData) _activeStageContent() {
    if (_verification.qrStatus != VerificationStageStatus.success) {
      return ('Verifying attendance...', 'Confirming the QR code signature with the session.', Icons.qr_code_rounded);
    }
    if (_verification.bleStatus != VerificationStageStatus.success) {
      return ('Checking proximity', 'Make sure you are close to your lecturer.', Icons.bluetooth_searching_rounded);
    }
    if (_verification.identityStatus != VerificationStageStatus.success) {
      return ('Verify your identity', 'Position your face inside the frame.', Icons.face_retouching_natural_rounded);
    }
    return ('Recording attendance', 'Signing and saving your attendance record.', Icons.fact_check_rounded);
  }

  Widget _buildSuccessStep() {
    final now = _recordedAt ?? DateTime.now();
    return Padding(
      key: const ValueKey('success'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 52),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('Attendance Recorded',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            'Your attendance has been successfully recorded.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.xl),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.securityDarkAlt,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                _SuccessRow(label: 'Course', value: widget.course.code),
                const Divider(color: Colors.white12, height: 22),
                _SuccessRow(label: 'Time', value: DateFormat('h:mm a').format(now)),
                const Divider(color: Colors.white12, height: 22),
                _SuccessRow(label: 'Date', value: DateFormat('d MMMM yyyy').format(now)),
                const Divider(color: Colors.white12, height: 22),
                _SuccessRow(label: 'Attendance', value: '${widget.course.attendancePercentage.toStringAsFixed(0)}%'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          StatusBadge(
            label: _synced ? 'Synced' : 'Saved offline',
            tone: _synced ? StatusTone.success : StatusTone.warning,
            icon: _synced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
          ),
          if (!_synced) ...[
            const SizedBox(height: 8),
            Text(
              'Attendance saved securely. It will sync automatically when you are back online.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11.5),
            ),
          ],
          const Spacer(),
          AppButton(
            label: 'Done',
            width: double.infinity,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  Widget _buildErrorStep() {
    return Padding(
      key: const ValueKey('error'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 44),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(_errorTitle ?? 'Something went wrong',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Please try again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
          ),
          const Spacer(),
          AppButton(
            label: 'Try Again',
            icon: Icons.refresh_rounded,
            width: double.infinity,
            onPressed: () => setState(() {
              _stage = _FlowStage.scan;
              _verification = const AttendanceVerification();
            }),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

class _SuccessRow extends StatelessWidget {
  final String label;
  final String value;
  const _SuccessRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

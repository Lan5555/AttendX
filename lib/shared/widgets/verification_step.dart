import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../models/attendance_verification.dart';

/// Horizontal QR → BLE → Identity → Attendance progress indicator
/// used during the mark-attendance flow (shown on a dark "security" surface).
class VerificationStepper extends StatelessWidget {
  final AttendanceVerification verification;

  const VerificationStepper({super.key, required this.verification});

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('QR', verification.qrStatus, Icons.qr_code_rounded),
      ('BLE', verification.bleStatus, Icons.bluetooth_searching_rounded),
      ('Identity', verification.identityStatus, Icons.face_retouching_natural_rounded),
      ('Attendance', verification.attendanceStatus, Icons.fact_check_rounded),
    ];

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final leftDone = steps[i ~/ 2].$2 == VerificationStageStatus.success;
          return Expanded(
            child: Container(
              height: 2,
              color: leftDone ? AppColors.securityAccent : Colors.white24,
            ),
          );
        }
        final (label, status, icon) = steps[i ~/ 2];
        return _StepDot(label: label, status: status, icon: icon);
      }),
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final VerificationStageStatus status;
  final IconData icon;
  const _StepDot({required this.label, required this.status, required this.icon});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Widget child;
    switch (status) {
      case VerificationStageStatus.success:
        bg = AppColors.success;
        fg = Colors.white;
        child = const Icon(Icons.check_rounded, size: 16, color: Colors.white);
        break;
      case VerificationStageStatus.failed:
        bg = AppColors.error;
        fg = Colors.white;
        child = const Icon(Icons.close_rounded, size: 16, color: Colors.white);
        break;
      case VerificationStageStatus.inProgress:
        bg = AppColors.securityAccent;
        fg = Colors.white;
        child = SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(fg)),
        );
        break;
      case VerificationStageStatus.pending:
        bg = Colors.white.withValues(alpha: .08);
        fg = Colors.white54;
        child = Icon(icon, size: 15, color: fg);
        break;
    }

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: child,
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha:0.8), fontWeight: FontWeight.w600)),
      ],
    );
  }
}

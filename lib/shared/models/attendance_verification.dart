enum VerificationStageStatus { pending, inProgress, success, failed }

enum VerificationStage { qr, ble, identity, attendance }

/// Tracks the state of each step in the mark-attendance flow.
/// The real cryptographic QR/TOTP, BLE proximity and liveness ML logic
/// will replace the mock transitions later — the UI only needs these states.
class AttendanceVerification {
  final VerificationStageStatus qrStatus;
  final VerificationStageStatus bleStatus;
  final VerificationStageStatus identityStatus;
  final VerificationStageStatus attendanceStatus;

  const AttendanceVerification({
    this.qrStatus = VerificationStageStatus.pending,
    this.bleStatus = VerificationStageStatus.pending,
    this.identityStatus = VerificationStageStatus.pending,
    this.attendanceStatus = VerificationStageStatus.pending,
  });

  AttendanceVerification copyWith({
    VerificationStageStatus? qrStatus,
    VerificationStageStatus? bleStatus,
    VerificationStageStatus? identityStatus,
    VerificationStageStatus? attendanceStatus,
  }) {
    return AttendanceVerification(
      qrStatus: qrStatus ?? this.qrStatus,
      bleStatus: bleStatus ?? this.bleStatus,
      identityStatus: identityStatus ?? this.identityStatus,
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
    );
  }
}

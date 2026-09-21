enum VerificationStageStatus { pending, inProgress, success, failed }

enum VerificationStage { qr, ble, identity, attendance }

/// Tracks the state of each step in the mark-attendance flow, plus the
/// data each step produces so the flow can build the API payload once
/// every stage succeeds.
class AttendanceVerification {
  final VerificationStageStatus qrStatus;
  final VerificationStageStatus bleStatus;
  final VerificationStageStatus identityStatus;
  final VerificationStageStatus attendanceStatus;

  // 🔌 Payload fields — populated as each stage succeeds.
  final String? sessionId;   // from the QR step
  final String? qrToken;     // from the QR step
  final int? bleRssi;        // from the BLE step
  final bool livenessConfirmed; // from the identity step

  const AttendanceVerification({
    this.qrStatus = VerificationStageStatus.pending,
    this.bleStatus = VerificationStageStatus.pending,
    this.identityStatus = VerificationStageStatus.pending,
    this.attendanceStatus = VerificationStageStatus.pending,
    this.sessionId,
    this.qrToken,
    this.bleRssi,
    this.livenessConfirmed = false,
  });

  AttendanceVerification copyWith({
    VerificationStageStatus? qrStatus,
    VerificationStageStatus? bleStatus,
    VerificationStageStatus? identityStatus,
    VerificationStageStatus? attendanceStatus,
    String? sessionId,
    String? qrToken,
    int? bleRssi,
    bool? livenessConfirmed,
  }) {
    return AttendanceVerification(
      qrStatus: qrStatus ?? this.qrStatus,
      bleStatus: bleStatus ?? this.bleStatus,
      identityStatus: identityStatus ?? this.identityStatus,
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
      sessionId: sessionId ?? this.sessionId,
      qrToken: qrToken ?? this.qrToken,
      bleRssi: bleRssi ?? this.bleRssi,
      livenessConfirmed: livenessConfirmed ?? this.livenessConfirmed,
    );
  }

  /// True once every stage has succeeded — the flow can then POST.
  bool get allPassed =>
      qrStatus == VerificationStageStatus.success &&
      bleStatus == VerificationStageStatus.success &&
      identityStatus == VerificationStageStatus.success &&
      attendanceStatus == VerificationStageStatus.success;

  /// True if any stage has failed — the flow should bail out.
  bool get hasFailed =>
      qrStatus == VerificationStageStatus.failed ||
      bleStatus == VerificationStageStatus.failed ||
      identityStatus == VerificationStageStatus.failed ||
      attendanceStatus == VerificationStageStatus.failed;

  /// Convenience accessor for the current stage's status.
  VerificationStageStatus statusOf(VerificationStage stage) => switch (stage) {
        VerificationStage.qr => qrStatus,
        VerificationStage.ble => bleStatus,
        VerificationStage.identity => identityStatus,
        VerificationStage.attendance => attendanceStatus,
      };
}
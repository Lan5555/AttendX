import 'dart:async';
import '../models/attendance_verification.dart';
import 'verification_service.dart';

/// Mocks the QR -> BLE -> Identity -> Attendance verification pipeline
/// with realistic timed transitions. Swap for the real crypto/BLE/ML
/// implementation later without touching the UI.
class MockVerificationService implements VerificationService {
  @override
  Stream<AttendanceVerification> runVerificationFlow() {
    late StreamController<AttendanceVerification> controller;
    controller = StreamController<AttendanceVerification>(
      onListen: () async {
        var state = const AttendanceVerification();

        // QR verification
        state = state.copyWith(qrStatus: VerificationStageStatus.inProgress);
        controller.add(state);
        await Future.delayed(const Duration(milliseconds: 1400));
        state = state.copyWith(qrStatus: VerificationStageStatus.success);
        controller.add(state);

        // BLE proximity
        await Future.delayed(const Duration(milliseconds: 400));
        state = state.copyWith(bleStatus: VerificationStageStatus.inProgress);
        controller.add(state);
        await Future.delayed(const Duration(milliseconds: 1600));
        state = state.copyWith(bleStatus: VerificationStageStatus.success);
        controller.add(state);

        // Identity / liveness
        await Future.delayed(const Duration(milliseconds: 400));
        state = state.copyWith(identityStatus: VerificationStageStatus.inProgress);
        controller.add(state);
        await Future.delayed(const Duration(milliseconds: 1800));
        state = state.copyWith(identityStatus: VerificationStageStatus.success);
        controller.add(state);

        // Final attendance signing
        await Future.delayed(const Duration(milliseconds: 300));
        state = state.copyWith(attendanceStatus: VerificationStageStatus.inProgress);
        controller.add(state);
        await Future.delayed(const Duration(milliseconds: 900));
        state = state.copyWith(attendanceStatus: VerificationStageStatus.success);
        controller.add(state);

        await controller.close();
      },
    );
    return controller.stream;
  }
}

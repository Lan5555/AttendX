import '../models/attendance_verification.dart';

/// Abstract contract for the QR / BLE / liveness verification pipeline.
/// Mocked with timed state transitions for the MVP demo; the real
/// cryptographic TOTP + BLE RSSI + ML liveness logic plugs in later.
abstract class VerificationService {
  Stream<AttendanceVerification> runVerificationFlow();
}

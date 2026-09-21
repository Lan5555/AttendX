import 'package:attendx/core/network/core_service.dart';

class SyncService extends CoreService {
  // POST /sync/attendance
  // Batch-sync offline attendance records
  Future<APIResponse> syncAttendance(
    Map<String, dynamic> payload,
  ) async {
    return send(
      '/sync/attendance',
      body: payload,
      method: 'POST',
    );
  }
}
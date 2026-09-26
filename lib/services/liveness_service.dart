import 'package:attendx/core/network/core_service.dart';

class LivenessService extends CoreService {
  Future<APIResponse> checkLivenessState() async {
    return fetch('/liveness/check-current-state');
  }
}

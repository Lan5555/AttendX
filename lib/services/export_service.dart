import 'package:attendx/core/network/core_service.dart';

class ExportService extends CoreService {
  // GET /export/course/:courseId
  // Download course attendance export
  Future<APIResponse> exportCourse(String courseId) async {
    return fetch('/export/course/$courseId');
  }
}
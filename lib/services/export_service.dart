import 'package:attendx/core/network/core_service.dart';
import 'package:http/http.dart' as http;

class ExportService extends CoreService {
  /// GET /export/course/:courseId
  ///
  /// Downloads the course attendance export as raw bytes. The caller is
  /// responsible for writing them to a file. Supports optional format and
  /// date-range filters via query params.
  Future<http.Response> exportAttendance(
    String courseId, {
    String? format,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return download(
      '/export/course/$courseId',
      query: {
        if (format != null) 'format': format,
        if (startDate != null) 'start': startDate.toIso8601String(),
        if (endDate != null) 'end': endDate.toIso8601String(),
      },
    );
  }
}
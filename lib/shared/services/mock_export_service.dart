import 'export_service.dart';

class MockExportService implements ExportService {
  @override
  Future<ExportResult> generateExport({
    required String courseId,
    required ExportFormat format,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1400));
    final ext = format == ExportFormat.csv ? 'csv' : 'xlsx';
    return ExportResult(
      success: true,
      fileName: 'attendance_${courseId}_export.$ext',
    );
  }
}

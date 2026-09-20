enum ExportFormat { csv, excel }

class ExportResult {
  final bool success;
  final String fileName;
  const ExportResult({required this.success, required this.fileName});
}

/// Abstract contract for exporting attendance records.
abstract class ExportService {
  Future<ExportResult> generateExport({
    required String courseId,
    required ExportFormat format,
    DateTime? startDate,
    DateTime? endDate,
  });
}

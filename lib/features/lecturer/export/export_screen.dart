import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/models/course.dart';
import '../../../shared/services/export_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/loading_state.dart';

class ExportScreen extends StatefulWidget {
  final String? preselectedCourseId;
  const ExportScreen({super.key, this.preselectedCourseId});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  List<Course> _courses = [];
  Course? _selectedCourse;
  ExportFormat _format = ExportFormat.csv;
  DateTimeRange? _range;
  bool _isLoading = true;
  bool _isExporting = false;
  ExportResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // final courses = await context.read<AppState>().courseService.getLecturerCourses();
    // if (!mounted) return;
    // setState(() {
    //   _courses = courses;
    //   _selectedCourse = widget.preselectedCourseId != null
    //       ? _find(courses, widget.preselectedCourseId!)
    //       : (courses.isNotEmpty ? courses.first : null);
    //   _isLoading = false;
    // });
  }

  Course? _find(List<Course> courses, String id) {
    for (final c in courses) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      initialDateRange: DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _generate() async {
    // if (_selectedCourse == null) return;
    // setState(() {
    //   _isExporting = true;
    //   _result = null;
    // });
    // final result = await context.read<AppState>().exportService.generateExport(
    //       courseId: _selectedCourse!.id,
    //       format: _format,
    //       startDate: _range?.start,
    //       endDate: _range?.end,
    //     );
    // if (!mounted) return;
    // setState(() {
    //   _isExporting = false;
    //   _result = result;
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export Attendance')),
      body: _isLoading
          ? const LoadingState()
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Course', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<Course>(
                      value: _selectedCourse,
                      items: _courses.map((c) => DropdownMenuItem(value: c, child: Text('${c.code} — ${c.title}'))).toList(),
                      onChanged: (c) => setState(() => _selectedCourse = c),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Date Range', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: _pickRange,
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(
                        _range == null
                            ? 'Select a date range'
                            : '${DateFormat('d MMM yyyy').format(_range!.start)} – ${DateFormat('d MMM yyyy').format(_range!.end)}',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Format', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _FormatTile(
                            label: 'CSV',
                            icon: Icons.description_outlined,
                            selected: _format == ExportFormat.csv,
                            onTap: () => setState(() => _format = ExportFormat.csv),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _FormatTile(
                            label: 'Excel',
                            icon: Icons.table_chart_outlined,
                            selected: _format == ExportFormat.excel,
                            onTap: () => setState(() => _format = ExportFormat.excel),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: 'Generate Export',
                      icon: Icons.file_download_outlined,
                      isLoading: _isExporting,
                      onPressed: _selectedCourse == null ? null : _generate,
                      width: double.infinity,
                    ),
                    if (_result != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.successBg,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppColors.success),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Export ready: ${_result!.fileName}',
                                style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _FormatTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _FormatTile({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: .08) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 1.4),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppColors.primary : AppColors.textTertiary),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: selected ? AppColors.primary : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

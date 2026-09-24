import 'dart:io';

import 'package:attendx/controllers/course_controller.dart';
import 'package:attendx/services/export_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/course.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/loading_state.dart';

enum ExportFormat {
  csv('csv', 'CSV'),
  excel('xlsx', 'Excel');

  const ExportFormat(this.extension, this.label);
  final String extension;
  final String label;
}

class ExportScreen extends StatefulWidget {
  final String? preselectedCourseId;
  const ExportScreen({super.key, this.preselectedCourseId});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final _exportService = ExportService();

  List<Course> _courses = [];
  Course? _selectedCourse;
  ExportFormat _format = ExportFormat.csv;
  DateTimeRange? _range;

  bool _isLoading = true;
  bool _isExporting = false;
  String? _errorMessage;
  File? _exportedFile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final courseController = context.read<CourseController>();
    await courseController.fetchLecturerCourses();

    if (!mounted) return;

    final courses = courseController.lecturerCourses;
    setState(() {
      _courses = courses;
      _selectedCourse = widget.preselectedCourseId != null
          ? _find(courses, widget.preselectedCourseId!)
          : (courses.isNotEmpty ? courses.first : null);
      _isLoading = false;
    });
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
      initialDateRange: _range ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
    );
    if (picked != null) setState(() => _range = picked);
  }

  void _clearRange() {
    setState(() => _range = null);
  }

  Future<void> _generate() async {
    final course = _selectedCourse;
    if (course == null) return;

    setState(() {
      _isExporting = true;
      _errorMessage = null;
      _exportedFile = null;
    });

    try {
      // Download the raw file from the backend.
      final response = await _exportService.exportAttendance(
        course.id,
        format: _format.extension,
        startDate: _range?.start,
        endDate: _range?.end,
      );

      if (!mounted) return;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        setState(() {
          _isExporting = false;
          _errorMessage =
              'Export failed (${response.statusCode}). Please try again.';
        });
        return;
      }

      // Write the bytes to a temp file so we can share or open it.
      final dir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final filename =
          '${course.code.replaceAll(' ', '_')}_$timestamp.${_format.extension}';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(response.bodyBytes);

      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _exportedFile = file;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _errorMessage = 'Could not reach the server. Check your connection.';
      });
    }
  }

  Future<void> _shareFile() async {
    final file = _exportedFile;
    if (file == null) return;

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Attendance Export',
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Export Attendance'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? const LoadingState(message: 'Loading courses…')
          : _courses.isEmpty
              ? _buildNoCourses()
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Course picker ───────────────────────────
                        Text(
                          'Course',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        DropdownButtonFormField<Course>(
                          value: _selectedCourse,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                              borderSide:
                                  const BorderSide(color: AppColors.outline),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                              borderSide:
                                  const BorderSide(color: AppColors.outline),
                            ),
                          ),
                          items: _courses
                              .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      '${c.code} — ${c.title}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                          onChanged: (c) =>
                              setState(() => _selectedCourse = c),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // ── Date range ──────────────────────────────
                        Row(
                          children: [
                            Text(
                              'Date Range',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(optional)',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.textTertiary),
                            ),
                            const Spacer(),
                            if (_range != null)
                              TextButton(
                                onPressed: _clearRange,
                                child: const Text('Clear'),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        InkWell(
                          onTap: _pickRange,
                          borderRadius:
                              BorderRadius.circular(AppRadius.md),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.outline),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _range == null
                                        ? 'Select a date range'
                                        : '${DateFormat('d MMM yyyy').format(_range!.start)} – ${DateFormat('d MMM yyyy').format(_range!.end)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _range == null
                                          ? AppColors.textTertiary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.textTertiary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // ── Format ──────────────────────────────────
                        Text(
                          'Format',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: _FormatTile(
                                label: 'CSV',
                                icon: Icons.description_outlined,
                                selected: _format == ExportFormat.csv,
                                onTap: () => setState(
                                    () => _format = ExportFormat.csv),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _FormatTile(
                                label: 'Excel',
                                icon: Icons.table_chart_outlined,
                                selected: _format == ExportFormat.excel,
                                onTap: () => setState(
                                    () => _format = ExportFormat.excel),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // ── Generate ────────────────────────────────
                        AppButton(
                          label: 'Generate Export',
                          icon: Icons.file_download_outlined,
                          isLoading: _isExporting,
                          onPressed:
                              _selectedCourse == null ? null : _generate,
                          width: double.infinity,
                        ),

                        // ── Error ───────────────────────────────────
                        if (_errorMessage != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          _Banner(
                            icon: Icons.error_outline_rounded,
                            message: _errorMessage!,
                            fg: AppColors.error,
                            bg: AppColors.errorBg,
                          ),
                        ],

                        // ── Success ─────────────────────────────────
                        if (_exportedFile != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          _Banner(
                            icon: Icons.check_circle_rounded,
                            message:
                                'Export ready: ${_exportedFile!.path.split('/').last}',
                            fg: AppColors.success,
                            bg: AppColors.successBg,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppButton(
                            label: 'Share File',
                            icon: Icons.ios_share_rounded,
                            onPressed: _shareFile,
                            width: double.infinity,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildNoCourses() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: .08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.menu_book_outlined,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No courses to export',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Create a course and hold a session before exporting attendance.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// FORMAT TILE
// ─────────────────────────────────────────────────────────────────────
class _FormatTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FormatTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: .08)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? AppColors.primary : AppColors.textTertiary,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// BANNER
// ─────────────────────────────────────────────────────────────────────
class _Banner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color fg;
  final Color bg;

  const _Banner({
    required this.icon,
    required this.message,
    required this.fg,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: fg.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
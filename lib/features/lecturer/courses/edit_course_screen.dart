import 'package:attendx/controllers/course_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/course.dart';
import '../../../shared/models/course_schedule.dart';
import '../../../shared/widgets/app_button.dart';

const _days = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

class EditCourseScreen extends StatefulWidget {
  final Course course;
  const EditCourseScreen({super.key, required this.course});

  @override
  State<EditCourseScreen> createState() => _EditCourseScreenState();
}

class _EditCourseScreenState extends State<EditCourseScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _venueController;
  late final TextEditingController _thresholdController;

  late String _day;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late bool _recurring;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: widget.course.title);
    _venueController =
        TextEditingController(text: widget.course.schedule.venue);
    _thresholdController = TextEditingController(
      text: widget.course.attendanceThreshold.toStringAsFixed(0),
    );

    // Normalize the incoming day.
    final rawDay = widget.course.schedule.day.trim();
    _day = _days.firstWhere(
      (d) => d.toLowerCase() == rawDay.toLowerCase(),
      orElse: () => _days.first,
    );

    // Parse the incoming times — fall back to sane defaults on failure.
    _startTime = _parseTime(widget.course.schedule.startTime) ??
        const TimeOfDay(hour: 10, minute: 0);
    _endTime = _parseTime(widget.course.schedule.endTime) ??
        const TimeOfDay(hour: 12, minute: 0);
    _recurring = widget.course.schedule.recurringWeekly;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _venueController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────
  // TIME HELPERS
  // ─────────────────────────────────────────────────────────────────────

  /// Parses "10:00 AM", "10:00AM", "22:00", "10:00" into a TimeOfDay.
  /// Returns null if the string is empty or unparseable.
  TimeOfDay? _parseTime(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    // Match "H:MM AM/PM" or "HH:MM AM/PM"
    final amPm = RegExp(r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$').firstMatch(s);
    if (amPm != null) {
      var hour = int.parse(amPm.group(1)!);
      final minute = int.parse(amPm.group(2)!);
      final isPm = amPm.group(3)!.toLowerCase() == 'pm';
      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    }

    // Match "HH:MM" (24-hour)
    final h24 = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s);
    if (h24 != null) {
      return TimeOfDay(
        hour: int.parse(h24.group(1)!),
        minute: int.parse(h24.group(2)!),
      );
    }

    return null;
  }

  /// Formats a TimeOfDay as "H:MM AM/PM" to match the existing backend
  /// format.
  String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isStart ? 'Select start time' : 'Select end time',
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────
  // SUBMIT
  // ─────────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Guard against an inverted time range.
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be after start time.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final courseHandler = context.read<CourseController>();

    final updated = Course(
      id: widget.course.id,
      code: widget.course.code,
      title: _titleController.text.trim(),
      description: widget.course.description,
      lecturerName: widget.course.lecturerName,
      creditUnits: widget.course.creditUnits,
      department: widget.course.department,
      schedule: CourseSchedule(
        day: _day,
        startTime: _formatTime(_startTime),
        endTime: _formatTime(_endTime),
        recurringWeekly: _recurring,
        venue: _venueController.text.trim(),
      ),
      maxStudents: widget.course.maxStudents,
      enrolledStudents: widget.course.enrolledStudents,
      classesHeld: widget.course.classesHeld,
      classesAttended: widget.course.classesAttended,
      attendanceThreshold: double.tryParse(_thresholdController.text) ??
          widget.course.attendanceThreshold,
    ).toAdvancedJson();

    await courseHandler.updateCourse(widget.course.id, updated, context);
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.of(context).pop(true);
  }

  // ─────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: _Hero(course: widget.course),
              ),

              // ── Course details ───────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _Section(
                    title: 'Course details',
                    icon: Icons.menu_book_rounded,
                    child: Column(
                      children: [
                        _Field(
                          label: 'Course title',
                          controller: _titleController,
                          hint: 'e.g. Software Engineering',
                          icon: Icons.title_rounded,
                          textCapitalization: TextCapitalization.words,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Enter a course title'
                                  : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _Field(
                          label: 'Venue',
                          controller: _venueController,
                          hint: 'e.g. Lab 3',
                          icon: Icons.location_on_outlined,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Enter a venue'
                                  : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Schedule ─────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _Section(
                    title: 'Schedule',
                    icon: Icons.calendar_today_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DayPicker(
                          selected: _day,
                          onChanged: (d) => setState(() => _day = d),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: _TimeTile(
                                label: 'Start time',
                                time: _formatTime(_startTime),
                                icon: Icons.schedule_rounded,
                                onTap: () => _pickTime(isStart: true),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _TimeTile(
                                label: 'End time',
                                time: _formatTime(_endTime),
                                icon: Icons.schedule_rounded,
                                onTap: () => _pickTime(isStart: false),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _RecurringToggle(
                          value: _recurring,
                          onChanged: (v) =>
                              setState(() => _recurring = v),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Attendance ───────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _Section(
                    title: 'Attendance',
                    icon: Icons.insights_rounded,
                    child: _Field(
                      label: 'Attendance threshold (%)',
                      controller: _thresholdController,
                      hint: 'Between 1 and 100',
                      icon: Icons.flag_outlined,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        if (n == null || n <= 0 || n > 100) {
                          return 'Enter a value between 1–100';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
              ),

              // ── Submit ───────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                sliver: SliverToBoxAdapter(
                  child: SizedBox(
                    height: 52,
                    child: AppButton(
                      label: 'Save Changes',
                      icon: Icons.check_rounded,
                      isLoading: _isLoading,
                      onPressed: _submit,
                      width: double.infinity,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// HERO
// ─────────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  final Course course;
  const _Hero({required this.course});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        topPadding + AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryLight.withValues(alpha: .16),
            AppColors.primaryLight.withValues(alpha: .04),
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (Navigator.of(context).canPop())
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.textPrimary,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 22,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: .25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.edit_outlined,
              color: AppColors.onPrimary,
              size: 24,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Edit Course',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Update details for ${course.code}.',
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: .9),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// SECTION WRAPPER
// ─────────────────────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// FIELD
// ─────────────────────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.icon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          validator: validator,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: icon != null
                ? Icon(icon, size: 18, color: AppColors.textTertiary)
                : null,
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.4),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide:
                  const BorderSide(color: AppColors.error, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// DAY PICKER
// ─────────────────────────────────────────────────────────────────────
class _DayPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _DayPicker({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Teaching day',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _days.map((day) {
            final isSelected = day == selected;
            final short = day.substring(0, 3);
            return Material(
              color: isSelected ? AppColors.primary : AppColors.background,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: () => onChanged(day),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.outline,
                    ),
                  ),
                  child: Text(
                    short,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.onPrimary
                          : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// TIME TILE
// ─────────────────────────────────────────────────────────────────────
class _TimeTile extends StatelessWidget {
  final String label;
  final String time;
  final IconData icon;
  final VoidCallback onTap;

  const _TimeTile({
    required this.label,
    required this.time,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.outline),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: AppColors.textTertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      time,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// RECURRING TOGGLE
// ─────────────────────────────────────────────────────────────────────
class _RecurringToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _RecurringToggle({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: value
          ? AppColors.primary.withValues(alpha: .06)
          : AppColors.background,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: value
                  ? AppColors.primary.withValues(alpha: .3)
                  : AppColors.outline,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.repeat_rounded,
                size: 18,
                color: value ? AppColors.primary : AppColors.textTertiary,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recurring weekly',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Repeats every week at this time',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
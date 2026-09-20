import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/models/course.dart';
import '../../../shared/models/course_schedule.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';

const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

class EditCourseScreen extends StatefulWidget {
  final Course course;
  const EditCourseScreen({super.key, required this.course});

  @override
  State<EditCourseScreen> createState() => _EditCourseScreenState();
}

class _EditCourseScreenState extends State<EditCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(text: widget.course.title);
  late final _venueController = TextEditingController(text: widget.course.schedule.venue);
  late final _thresholdController =
      TextEditingController(text: widget.course.attendanceThreshold.toStringAsFixed(0));
  late String _day = widget.course.schedule.day;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _venueController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

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
        startTime: widget.course.schedule.startTime,
        endTime: widget.course.schedule.endTime,
        recurringWeekly: widget.course.schedule.recurringWeekly,
        venue: _venueController.text.trim(),
      ),
      maxStudents: widget.course.maxStudents,
      enrolledStudents: widget.course.enrolledStudents,
      classesHeld: widget.course.classesHeld,
      classesAttended: widget.course.classesAttended,
      attendanceThreshold: double.tryParse(_thresholdController.text) ?? widget.course.attendanceThreshold,
    );

    await context.read<AppState>().courseService.updateCourse(updated);
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit ${widget.course.code}')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  label: 'Course Title',
                  controller: _titleController,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a course title' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Venue',
                  controller: _venueController,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a venue' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  value: _day,
                  decoration: const InputDecoration(labelText: 'Day'),
                  items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) => setState(() => _day = v ?? _day),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Attendance Threshold (%)',
                  controller: _thresholdController,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    if (n == null || n <= 0 || n > 100) return 'Enter a value between 1–100';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Save Changes',
                  isLoading: _isLoading,
                  onPressed: _submit,
                  width: double.infinity,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

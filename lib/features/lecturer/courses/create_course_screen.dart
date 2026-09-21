import 'package:attendx/controllers/course_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/course.dart';
import '../../../shared/models/course_schedule.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';

const _days = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday'
];

class CreateCourseScreen extends StatefulWidget {
  const CreateCourseScreen({super.key});

  @override
  State<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _unitsController = TextEditingController(text: '3');
  final _departmentController = TextEditingController(text: 'Computer Science');
  final _venueController = TextEditingController();
  final _maxStudentsController = TextEditingController(text: '100');

  String _day = _days.first;
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 12, minute: 0);
  bool _recurring = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _unitsController.dispose();
    _departmentController.dispose();
    _venueController.dispose();
    _maxStudentsController.dispose();
    super.dispose();
  }

  String _fmt(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
        context: context, initialTime: isStart ? _startTime : _endTime);
    if (picked != null) {
      setState(() => isStart ? _startTime = picked : _endTime = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final courseHandler = context.read<CourseController>();

    final course = Course(
      id: 'c_${DateTime.now().millisecondsSinceEpoch}',
      code: _codeController.text.trim().toUpperCase(),
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      lecturerName: 'You',
      creditUnits: int.tryParse(_unitsController.text) ?? 3,
      department: _departmentController.text.trim(),
      schedule: CourseSchedule(
        day: _day,
        startTime: _fmt(_startTime),
        endTime: _fmt(_endTime),
        recurringWeekly: _recurring,
        venue: _venueController.text.trim(),
      ),
      maxStudents: int.tryParse(_maxStudentsController.text) ?? 100,
      enrolledStudents: 0,
      classesHeld: 0,
      classesAttended: 0,
    ).toAdvancedJson();
  
    await courseHandler.createCourse(course, context);
    //await context.read<AppState>().courseService.createCourse(course);
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Course')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  label: 'Course Code',
                  controller: _codeController,
                  hint: 'e.g. CSC 416',
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter a course code'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Course Title',
                  controller: _titleController,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter a course title'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                    label: 'Description',
                    controller: _descController,
                    maxLines: 3),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Credit Units',
                        controller: _unitsController,
                        keyboardType: TextInputType.number,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppTextField(
                        label: 'Max Students',
                        controller: _maxStudentsController,
                        keyboardType: TextInputType.number,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Department',
                  controller: _departmentController,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter department'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Venue',
                  controller: _venueController,
                  hint: 'e.g. Lab 3',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter a venue' : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Schedule',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  value: _day,
                  decoration: const InputDecoration(labelText: 'Day'),
                  items: _days
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) => setState(() => _day = v ?? _day),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickTime(true),
                        child: Text('Start: ${_fmt(_startTime)}'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickTime(false),
                        child: Text('End: ${_fmt(_endTime)}'),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Recurring weekly'),
                  value: _recurring,
                  onChanged: (v) => setState(() => _recurring = v),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Create Course',
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

class CourseSchedule {
  final String day; // e.g. "Monday"
  final String startTime; // e.g. "10:00 AM"
  final String endTime; // e.g. "12:00 PM"
  final bool recurringWeekly;
  final String venue;

  const CourseSchedule({
    required this.day,
    required this.startTime,
    required this.endTime,
    this.recurringWeekly = true,
    required this.venue,
  });

  String get timeRangeLabel => '$startTime – $endTime';
}

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

  factory CourseSchedule.fromJson(Map<String, dynamic> json) {
    return CourseSchedule(
      day: json['day'] as String,
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      recurringWeekly: json['recurringWeekly'] as bool? ?? true,
      venue: json['venue'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day': day,
      'startTime': startTime,
      'endTime': endTime,
      'recurringWeekly': recurringWeekly,
      'venue': venue,
    };
  }

  String get timeRangeLabel => '$startTime – $endTime';
}
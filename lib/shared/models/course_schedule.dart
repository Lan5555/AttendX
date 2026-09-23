class CourseSchedule {
  final String day;
  final String startTime;
  final String endTime;
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
      day: json['day']?.toString() ?? '',
      startTime: json['startTime']?.toString() ?? '',
      endTime: json['endTime']?.toString() ?? '',
      recurringWeekly: json['recurringWeekly'] as bool? ?? true,
      venue: json['venue']?.toString() ?? 'TBA',
    );
  }

  Map<String, dynamic> toJson() => {
        'day': day,
        'startTime': startTime,
        'endTime': endTime,
        'recurringWeekly': recurringWeekly,
        'venue': venue,
      };

  /// Human-readable time range for UI display.
  /// Handles partial data gracefully so the chip never renders empty.
  String get timeRangeLabel {
    final s = startTime.trim();
    final e = endTime.trim();
    if (s.isEmpty && e.isEmpty) return 'Time TBA';
    if (s.isEmpty) return e;
    if (e.isEmpty) return s;
    return '$s – $e';
  }

  CourseSchedule copyWith({
    String? day,
    String? startTime,
    String? endTime,
    bool? recurringWeekly,
    String? venue,
  }) {
    return CourseSchedule(
      day: day ?? this.day,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      recurringWeekly: recurringWeekly ?? this.recurringWeekly,
      venue: venue ?? this.venue,
    );
  }
}
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/course.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/attendance_progress.dart';

/// One row of a student's attendance history, passed in by the caller.
class StudentAttendanceEntry {
  final DateTime date;
  final String time;
  final bool present;

  const StudentAttendanceEntry({
    required this.date,
    required this.time,
    required this.present,
  });

  factory StudentAttendanceEntry.fromJson(dynamic json) {
  return StudentAttendanceEntry(
    date: json.date,
    time: json.time,
    present: json.present,
  );
}

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'time': time,
        'present': present,
      };
}

/// One attendance roster row for a course, used by the records screen.
class RosterRecord {
  final String name;
  final String id;
  final DateTime date;
  final String time;
  final bool present;
  final String sessionId;

  const RosterRecord({
    required this.name,
    required this.id,
    required this.date,
    required this.time,
    required this.present,
    required this.sessionId,
  });

  factory RosterRecord.fromJson(Map<String, dynamic> json) {
    final dateRaw = json['date'] as String?;
    final date = (dateRaw != null ? DateTime.tryParse(dateRaw) : null) ??
        DateTime.now();
    return RosterRecord(
      name: json['studentName'] as String? ?? 'Unknown student',
      id: json['studentId'] as String? ?? '',
      date: date,
      time: json['time'] as String? ?? DateFormat('h:mm a').format(date),
      present: json['present'] as bool? ?? false,
      sessionId: json['sessionId'] as String? ?? '',
    );
  }
}

class StudentAttendanceDetailScreen extends StatelessWidget {
  final String studentName;
  final String studentId;
  final Course course;
  final List<StudentAttendanceEntry> records;

  const StudentAttendanceDetailScreen({
    super.key,
    required this.studentName,
    required this.studentId,
    required this.course,
    this.records = const [],
  });

  int get _presentCount => records.where((r) => r.present).length;
  int get _absentCount => records.length - _presentCount;
  double get _rate =>
      records.isEmpty ? 0 : (_presentCount / records.length) * 100;

  AttendanceEligibility get _eligibility {
    if (records.isEmpty) return AttendanceEligibility.eligible;
    if (_rate >= course.attendanceThreshold) {
      return AttendanceEligibility.eligible;
    }
    if (_rate >= course.attendanceThreshold - 15) {
      return AttendanceEligibility.atRisk;
    }
    return AttendanceEligibility.ineligible;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List<StudentAttendanceEntry>.from(records)
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: _Hero(
                studentName: studentName,
                studentId: studentId,
                course: course,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: _AttendanceCard(
                  rate: _rate,
                  threshold: course.attendanceThreshold,
                  eligibility: _eligibility,
                  presentCount: _presentCount,
                  absentCount: _absentCount,
                  totalCount: records.length,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: _CourseInfoCard(course: course),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    const Text(
                      'Attendance History',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${records.length}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (sorted.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                sliver: SliverToBoxAdapter(child: _EmptyHistory()),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                sliver: SliverList.separated(
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) => _HistoryTile(entry: sorted[i]),
                ),
              ),
            const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.xl),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// HERO
// ─────────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  final String studentName;
  final String studentId;
  final Course course;

  const _Hero({
    required this.studentName,
    required this.studentId,
    required this.course,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final initial =
        studentName.isNotEmpty ? studentName[0].toUpperCase() : '?';

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
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: .3),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.badge_outlined,
                          size: 13,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            studentId,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        course.code,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// ATTENDANCE CARD
// ─────────────────────────────────────────────────────────────────────
class _AttendanceCard extends StatelessWidget {
  final double rate;
  final double threshold;
  final AttendanceEligibility eligibility;
  final int presentCount;
  final int absentCount;
  final int totalCount;

  const _AttendanceCard({
    required this.rate,
    required this.threshold,
    required this.eligibility,
    required this.presentCount,
    required this.absentCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final isEligible = eligibility == AttendanceEligibility.eligible;
    final isAtRisk = eligibility == AttendanceEligibility.atRisk;
    final color = isEligible
        ? AppColors.success
        : isAtRisk
            ? AppColors.warning
            : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            color.withValues(alpha: .04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: color.withValues(alpha: .22),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              AttendanceProgress(
                percentage: rate,
                threshold: threshold,
                size: 96,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance Rate',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalCount == 0
                          ? 'No sessions held yet for this course.'
                          : isEligible
                              ? 'On track to stay eligible.'
                              : isAtRisk
                                  ? 'Attend upcoming classes to stay eligible.'
                                  : 'Below the required threshold.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                    ),
                    const SizedBox(height: 10),
                    StatusBadge(
                      label: switch (eligibility) {
                        AttendanceEligibility.eligible => 'Eligible',
                        AttendanceEligibility.atRisk => 'At Risk',
                        AttendanceEligibility.ineligible => 'Ineligible',
                      },
                      tone: switch (eligibility) {
                        AttendanceEligibility.eligible => StatusTone.success,
                        AttendanceEligibility.atRisk => StatusTone.warning,
                        AttendanceEligibility.ineligible => StatusTone.error,
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Present',
                  value: '$presentCount',
                  color: AppColors.success,
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: AppColors.outline.withValues(alpha: .5),
              ),
              Expanded(
                child: _MiniStat(
                  icon: Icons.cancel_outlined,
                  label: 'Absent',
                  value: '$absentCount',
                  color: AppColors.error,
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: AppColors.outline.withValues(alpha: .5),
              ),
              Expanded(
                child: _MiniStat(
                  icon: Icons.event_available_rounded,
                  label: 'Total',
                  value: '$totalCount',
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// COURSE INFO CARD
// ─────────────────────────────────────────────────────────────────────
class _CourseInfoCard extends StatelessWidget {
  final Course course;
  const _CourseInfoCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.menu_book_rounded,
            label: 'Course',
            value: '${course.code} — ${course.title}',
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.outline,
            indent: 56,
          ),
          _InfoRow(
            icon: Icons.flag_outlined,
            label: 'Threshold',
            value: '${course.attendanceThreshold.toStringAsFixed(0)}%',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 14,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textTertiary),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// HISTORY TILE
// ─────────────────────────────────────────────────────────────────────
class _HistoryTile extends StatelessWidget {
  final StudentAttendanceEntry entry;
  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final present = entry.present;
    final color = present ? AppColors.success : AppColors.error;
    final bg = present ? AppColors.successBg : AppColors.errorBg;
    final icon = present ? Icons.check_circle_rounded : Icons.cancel_rounded;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, d MMMM yyyy').format(entry.date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 12,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      entry.time,
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              present ? 'Present' : 'Absent',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// EMPTY HISTORY
// ─────────────────────────────────────────────────────────────────────
class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xl,
        horizontal: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history_rounded,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'No attendance history',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'This student has no attendance records for this course yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../models/attendance_record.dart';
import 'status_badge.dart';

/// Row card for a single attendance history record.
class AttendanceRecordCard extends StatefulWidget {
  final AttendanceRecord record;
  final bool showCourse;
  final VoidCallback? onTap;
  final bool compact;

  const AttendanceRecordCard({
    super.key,
    required this.record,
    this.showCourse = true,
    this.onTap,
    this.compact = false,
  });

  @override
  State<AttendanceRecordCard> createState() => _AttendanceRecordCardState();
}

class _AttendanceRecordCardState extends State<AttendanceRecordCard> {
  bool _isPressed = false;

  AttendanceRecord get record => widget.record;
  bool get _verified => record.verification == RecordVerification.verified;

  (Color bg, Color fg, IconData icon) get _statusVisuals {
    if (_verified) {
      return (
        AppColors.successBg,
        AppColors.success,
        Icons.check_circle_rounded,
      );
    }
    return (AppColors.errorBg, AppColors.error, Icons.error_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final (bgColor, fgColor, statusIcon) = _statusVisuals;
    final theme = Theme.of(context);

    return AnimatedScale(
      scale: _isPressed ? 0.985 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: fgColor.withValues(alpha: .15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: widget.onTap == null
                ? null
                : (_) => setState(() => _isPressed = true),
            onTapUp: widget.onTap == null
                ? null
                : (_) => setState(() => _isPressed = false),
            onTapCancel: widget.onTap == null
                ? null
                : () => setState(() => _isPressed = false),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Padding(
              padding: EdgeInsets.all(
                widget.compact ? AppSpacing.sm : AppSpacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Status Icon ──────────────────────────────
                  _StatusIcon(
                    icon: statusIcon,
                    backgroundColor: bgColor,
                    foregroundColor: fgColor,
                    size: widget.compact ? 36 : 44,
                  ),
                  SizedBox(width: widget.compact ? 10 : AppSpacing.sm + 2),

                  // ── Content ──────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Course code / student name row
                        if (widget.showCourse || record.studentName != null)
                          _TitleRow(
                            record: record,
                            showCourse: widget.showCourse,
                            compact: widget.compact,
                          ),

                        // Date + time row
                        const SizedBox(height: 4),
                        _MetaRow(
                          record: record,
                          compact: widget.compact,
                        ),

                        // Location (only if present)
                        if (_hasLocation(record)) ...[
                          const SizedBox(height: 4),
                          _LocationRow(
                            record: record,
                            compact: widget.compact,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // ── Status Column ────────────────────────────
                  _StatusColumn(
                    verified: _verified,
                    syncStatus: record.syncStatus,
                    compact: widget.compact,
                  ),

                  // Chevron (only when tappable)
                  if (widget.onTap != null) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _hasLocation(AttendanceRecord record) {
    // Best-effort: check for optional location fields via dynamic access
    // so we don't break if the model doesn't define them yet.
    try {
      final dynamic r = record;
      final venue = r.venue as String?;
      final room = r.room as String?;
      return (venue != null && venue.isNotEmpty) ||
          (room != null && room.isNotEmpty);
    } catch (_) {
      return false;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Status Icon with subtle ring
// ─────────────────────────────────────────────────────────────
class _StatusIcon extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final double size;

  const _StatusIcon({
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(size / 3.5),
        border: Border.all(
          color: foregroundColor.withValues(alpha: .2),
          width: 1,
        ),
      ),
      child: Icon(icon, color: foregroundColor, size: size * 0.5),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Title Row (course code + optional student name)
// ─────────────────────────────────────────────────────────────
class _TitleRow extends StatelessWidget {
  final AttendanceRecord record;
  final bool showCourse;
  final bool compact;

  const _TitleRow({
    required this.record,
    required this.showCourse,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Both course code and student name -> stacked
    if (showCourse && record.studentName != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            record.courseCode,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            record.studentName!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    // Only one of them
    final primary = showCourse ? record.courseCode : (record.studentName ?? '');
    if (primary.isEmpty) return const SizedBox.shrink();

    return Text(
      primary,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: AppColors.textPrimary,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Meta Row (date + time)
// ─────────────────────────────────────────────────────────────
class _MetaRow extends StatelessWidget {
  final AttendanceRecord record;
  final bool compact;

  const _MetaRow({required this.record, required this.compact});

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEE, d MMM yyyy').format(record.date);
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _MetaChip(
          icon: Icons.calendar_today_rounded,
          text: dateLabel,
          compact: compact,
        ),
        _MetaChip(
          icon: Icons.access_time_rounded,
          text: record.time,
          compact: compact,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Location Row
// ─────────────────────────────────────────────────────────────
class _LocationRow extends StatelessWidget {
  final AttendanceRecord record;
  final bool compact;

  const _LocationRow({required this.record, required this.compact});

  @override
  Widget build(BuildContext context) {
    String location = '';
    try {
      final dynamic r = record;
      final venue = r.venue as String?;
      final room = r.room as String?;
      if (venue != null && venue.isNotEmpty && room != null && room.isNotEmpty) {
        location = '$venue • $room';
      } else if (venue != null && venue.isNotEmpty) {
        location = venue;
      } else if (room != null && room.isNotEmpty) {
        location = room;
      }
    } catch (_) {
      return const SizedBox.shrink();
    }

    if (location.isEmpty) return const SizedBox.shrink();

    return _MetaChip(
      icon: Icons.location_on_outlined,
      text: location,
      compact: compact,
      maxWidth: 220,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Small meta chip (icon + text)
// ─────────────────────────────────────────────────────────────
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool compact;
  final double? maxWidth;

  const _MetaChip({
    required this.icon,
    required this.text,
    required this.compact,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: compact ? 11 : 12,
                  height: 1.2,
                ),
          ),
        ),
      ],
    );

    if (maxWidth == null) return chip;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth!),
      child: chip,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Status Column (verified badge + sync status)
// ─────────────────────────────────────────────────────────────
class _StatusColumn extends StatelessWidget {
  final bool verified;
  final SyncStatus syncStatus;
  final bool compact;

  const _StatusColumn({
    required this.verified,
    required this.syncStatus,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Compact mode: icon-only primary status ──
        if (compact)
          _CompactStatusDot(verified: verified)
        else
          StatusBadge(
            label: verified ? 'Verified' : 'Failed',
            tone: verified ? StatusTone.success : StatusTone.error,
            icon: verified
                ? Icons.verified_rounded
                : Icons.close_rounded,
          ),
        const SizedBox(height: 6),
        _syncLabel(syncStatus, compact),
      ],
    );
  }

  Widget _syncLabel(SyncStatus status, bool compact) {
    switch (status) {
      case SyncStatus.synced:
        return StatusBadge(
          label: compact ? 'Synced' : 'Synced',
          tone: StatusTone.info,
          icon: Icons.cloud_done_rounded,
        );
      case SyncStatus.savedOffline:
        return StatusBadge(
          label: compact ? 'Local' : 'Saved locally',
          tone: StatusTone.warning,
          icon: Icons.cloud_off_rounded,
        );
      case SyncStatus.syncing:
        return const _SyncingBadge();
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Compact status dot (icon-only)
// ─────────────────────────────────────────────────────────────
class _CompactStatusDot extends StatelessWidget {
  final bool verified;

  const _CompactStatusDot({required this.verified});

  @override
  Widget build(BuildContext context) {
    final color = verified ? AppColors.success : AppColors.error;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Icon(
        verified ? Icons.check_rounded : Icons.close_rounded,
        size: 14,
        color: color,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Animated syncing badge with rotating icon
// ─────────────────────────────────────────────────────────────
class _SyncingBadge extends StatefulWidget {
  const _SyncingBadge();

  @override
  State<_SyncingBadge> createState() => _SyncingBadgeState();
}

class _SyncingBadgeState extends State<_SyncingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline.withValues(alpha: .5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: _controller,
            child: const Icon(
              Icons.sync_rounded,
              size: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Syncing',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
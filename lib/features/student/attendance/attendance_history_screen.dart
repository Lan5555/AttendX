import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/models/attendance_record.dart';
import '../../../shared/widgets/attendance_card.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/offline_banner.dart';

/// Filter options for the history list.
enum AttendanceFilter { all, verified, failed, pendingSync }

/// A single month group with its records.
class _MonthGroup {
  final String label;
  final DateTime monthDate;
  final List<AttendanceRecord> records;

  const _MonthGroup({
    required this.label,
    required this.monthDate,
    required this.records,
  });

  int get verifiedCount =>
      records.where((r) => r.verification == RecordVerification.verified).length;
  int get failedCount => records.length - verifiedCount;
}

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<AttendanceRecord> _records = [];

  // UI state
  AttendanceFilter _filter = AttendanceFilter.all;
  String _query = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _load();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final records =
        await context.read<AppState>().attendanceService.getStudentHistory();
    if (!mounted) return;
    setState(() {
      _records = records;
      _isLoading = false;
    });
    _fadeController.forward();
  }

  // ── Filtering + grouping ──────────────────────────────────
  List<AttendanceRecord> get _filteredRecords {
    Iterable<AttendanceRecord> list = _records;

    // Filter chip
    switch (_filter) {
      case AttendanceFilter.all:
        break;
      case AttendanceFilter.verified:
        list = list.where(
          (r) => r.verification == RecordVerification.verified,
        );
        break;
      case AttendanceFilter.failed:
        list = list.where(
          (r) => r.verification != RecordVerification.verified,
        );
        break;
      case AttendanceFilter.pendingSync:
        list = list.where((r) => r.syncStatus != SyncStatus.synced);
        break;
    }

    // Search query
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      list = list.where((r) {
        final code = r.courseCode.toLowerCase();
        final name = (r.studentName ?? '').toLowerCase();
        return code.contains(q) || name.contains(q);
      });
    }

    final result = list.toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // newest first
    return result;
  }

  List<_MonthGroup> get _grouped {
    final map = <String, List<AttendanceRecord>>{};
    final dates = <String, DateTime>{};

    for (final r in _filteredRecords) {
      final key = DateFormat('MMMM yyyy').format(r.date);
      map.putIfAbsent(key, () => []).add(r);
      dates.putIfAbsent(key, () => DateTime(r.date.year, r.date.month));
    }

    final groups = map.entries.map((e) {
      return _MonthGroup(
        label: e.key,
        monthDate: dates[e.key]!,
        records: e.value,
      );
    }).toList()
      ..sort((a, b) => b.monthDate.compareTo(a.monthDate));

    return groups;
  }

  // ── Stats ─────────────────────────────────────────────────
  int get _totalCount => _records.length;
  int get _verifiedCount => _records
      .where((r) => r.verification == RecordVerification.verified)
      .length;
  int get _failedCount => _totalCount - _verifiedCount;
  double get _verificationRate =>
      _totalCount == 0 ? 0 : (_verifiedCount / _totalCount) * 100;
  int get _pendingSyncCount =>
      _records.where((r) => r.syncStatus != SyncStatus.synced).length;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: _isSearching
            ? _SearchField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                onClose: () {
                  setState(() {
                    _isSearching = false;
                    _query = '';
                    _searchController.clear();
                  });
                },
              )
            : const Text('Attendance History'),
        actions: [
          if (!_isSearching && !_isLoading && _records.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.search_rounded),
              tooltip: 'Search',
              onPressed: () => setState(() => _isSearching = true),
            ),
        ],
      ),
      body: Column(
        children: [
          OfflineBanner(isOnline: appState.isOnline),
          Expanded(
            child: _isLoading
                ? const LoadingState(message: 'Loading attendance history…')
                : _records.isEmpty
                    ? const EmptyState(
                        icon: Icons.fact_check_outlined,
                        title: 'No attendance records yet',
                        message:
                            'Records will appear here once you start marking attendance.',
                      )
                    : FadeTransition(
                        opacity: _fadeAnimation,
                        child: RefreshIndicator(
                          onRefresh: _load,
                          color: AppColors.primary,
                          child: CustomScrollView(
                            slivers: [
                              // ── Summary card ────────────────
                              SliverToBoxAdapter(
                                child: _SummaryCard(
                                  total: _totalCount,
                                  verified: _verifiedCount,
                                  failed: _failedCount,
                                  rate: _verificationRate,
                                  pendingSync: _pendingSyncCount,
                                ),
                              ),

                              // ── Filter chips ────────────────
                              SliverToBoxAdapter(
                                child: _FilterChips(
                                  selected: _filter,
                                  onChanged: (f) =>
                                      setState(() => _filter = f),
                                  counts: {
                                    AttendanceFilter.all: _totalCount,
                                    AttendanceFilter.verified: _verifiedCount,
                                    AttendanceFilter.failed: _failedCount,
                                    AttendanceFilter.pendingSync:
                                        _pendingSyncCount,
                                  },
                                ),
                              ),

                              // ── Empty filter result ─────────
                              if (_grouped.isEmpty)
                                SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: _NoResultsState(
                                    query: _query,
                                    filter: _filter,
                                    onClear: () {
                                      setState(() {
                                        _query = '';
                                        _filter = AttendanceFilter.all;
                                        _searchController.clear();
                                      });
                                    },
                                  ),
                                )
                              else
                                // ── Month groups + records ──
                                ..._grouped.expand((group) sync* {
                                  yield SliverToBoxAdapter(
                                    child: _MonthHeader(group: group),
                                  );

                                  yield SliverPadding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.lg,
                                    ),
                                    sliver: SliverList.builder(
                                      itemCount: group.records.length,
                                      itemBuilder: (context, i) {
                                        final r = group.records[i];
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: AppSpacing.sm,
                                          ),
                                          child: _AnimatedRecordItem(
                                            index: i,
                                            child: AttendanceRecordCard(
                                              record: r,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                }),

                              // Bottom breathing room
                              const SliverToBoxAdapter(
                                child: SizedBox(height: AppSpacing.xl),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Search field (in AppBar)
// ─────────────────────────────────────────────────────────────
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Search by course code or name…',
        border: InputBorder.none,
        hintStyle: TextStyle(
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w400,
        ),
        suffixIcon: IconButton(
          icon: const Icon(Icons.close_rounded, size: 20),
          onPressed: onClose,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Summary Card
// ─────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final int total;
  final int verified;
  final int failed;
  final double rate;
  final int pendingSync;

  const _SummaryCard({
    required this.total,
    required this.verified,
    required this.failed,
    required this.rate,
    required this.pendingSync,
  });

  @override
  Widget build(BuildContext context) {
    final rateColor = rate >= 75
        ? AppColors.success
        : rate >= 50
            ? AppColors.warning
            : AppColors.error;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.surface,
              rateColor.withValues(alpha: .04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: rateColor.withValues(alpha: .2), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: rateColor.withValues(alpha: .06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Rate dial
                _RateDial(rate: rate, color: rateColor),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verification Rate',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rate >= 75
                            ? 'Great job! Most of your records are verified.'
                            : rate >= 50
                                ? 'Some records need attention.'
                                : 'Many records failed verification.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
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
                    icon: Icons.fact_check_outlined,
                    label: 'Total',
                    value: '$total',
                    color: AppColors.textSecondary,
                  ),
                ),
                _MiniStatDivider(),
                Expanded(
                  child: _MiniStat(
                    icon: Icons.verified_rounded,
                    label: 'Verified',
                    value: '$verified',
                    color: AppColors.success,
                  ),
                ),
                _MiniStatDivider(),
                Expanded(
                  child: _MiniStat(
                    icon: Icons.close_rounded,
                    label: 'Failed',
                    value: '$failed',
                    color: AppColors.error,
                  ),
                ),
                if (pendingSync > 0) ...[
                  _MiniStatDivider(),
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.cloud_off_rounded,
                      label: 'Pending',
                      value: '$pendingSync',
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RateDial extends StatelessWidget {
  final double rate;
  final Color color;

  const _RateDial({required this.rate, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      height: 68,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 68,
            height: 68,
            child: CircularProgressIndicator(
              value: rate / 100,
              strokeWidth: 6,
              backgroundColor: color.withValues(alpha: .12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            '${rate.toStringAsFixed(0)}%',
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _MiniStatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: AppColors.outline.withValues(alpha: .4),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Filter Chips Row
// ─────────────────────────────────────────────────────────────
class _FilterChips extends StatelessWidget {
  final AttendanceFilter selected;
  final ValueChanged<AttendanceFilter> onChanged;
  final Map<AttendanceFilter, int> counts;

  const _FilterChips({
    required this.selected,
    required this.onChanged,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          _chip(
            context,
            label: 'All',
            filter: AttendanceFilter.all,
            icon: Icons.list_alt_rounded,
          ),
          _chip(
            context,
            label: 'Verified',
            filter: AttendanceFilter.verified,
            icon: Icons.verified_rounded,
          ),
          _chip(
            context,
            label: 'Failed',
            filter: AttendanceFilter.failed,
            icon: Icons.close_rounded,
          ),
          if ((counts[AttendanceFilter.pendingSync] ?? 0) > 0)
            _chip(
              context,
              label: 'Pending sync',
              filter: AttendanceFilter.pendingSync,
              icon: Icons.cloud_off_rounded,
            ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required AttendanceFilter filter,
    required IconData icon,
  }) {
    final isSelected = selected == filter;
    final count = counts[filter] ?? 0;
    final color = isSelected ? AppColors.primary : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: isSelected,
        onSelected: (_) => onChanged(filter),
        showCheckmark: false,
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primary.withValues(alpha: .12),
        side: BorderSide(
          color: isSelected
              ? AppColors.primary.withValues(alpha: .4)
              : AppColors.outline.withValues(alpha: .5),
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: .15)
                    : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Month Group Header
// ─────────────────────────────────────────────────────────────
class _MonthHeader extends StatelessWidget {
  final _MonthGroup group;

  const _MonthHeader({required this.group});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              size: 14,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              group.label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Attendance summary for month
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CountPill(
                count: group.verifiedCount,
                color: AppColors.success,
                icon: Icons.check_rounded,
              ),
              if (group.failedCount > 0) ...[
                const SizedBox(width: 6),
                _CountPill(
                  count: group.failedCount,
                  color: AppColors.error,
                  icon: Icons.close_rounded,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  final int count;
  final Color color;
  final IconData icon;

  const _CountPill({
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// No Results (filtered empty)
// ─────────────────────────────────────────────────────────────
class _NoResultsState extends StatelessWidget {
  final String query;
  final AttendanceFilter filter;
  final VoidCallback onClear;

  const _NoResultsState({
    required this.query,
    required this.filter,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
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
                Icons.search_off_rounded,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No matching records',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              query.isNotEmpty
                  ? 'No records match "$query".'
                  : 'No records match the current filter.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Clear filters'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Staggered list item animation
// ─────────────────────────────────────────────────────────────
class _AnimatedRecordItem extends StatefulWidget {
  final int index;
  final Widget child;

  const _AnimatedRecordItem({required this.index, required this.child});

  @override
  State<_AnimatedRecordItem> createState() => _AnimatedRecordItemState();
}

class _AnimatedRecordItemState extends State<_AnimatedRecordItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    final delay = (widget.index * 40).clamp(0, 400);
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
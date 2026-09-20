import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Small non-intrusive banner shown when the device has no connection.
/// Wire this up to a real connectivity stream later; for now it is
/// driven by [AppState.isOnline].
class OfflineBanner extends StatelessWidget {
  final bool isOnline;
  final bool isSyncing;

  const OfflineBanner({super.key, required this.isOnline, this.isSyncing = false});

  @override
  Widget build(BuildContext context) {
    if (isOnline && !isSyncing) return const SizedBox.shrink();

    final label = isSyncing ? 'Syncing attendance…' : "You're offline";
    final color = isSyncing ? AppColors.info : AppColors.warning;
    final bg = isSyncing ? AppColors.infoBg : AppColors.warningBg;
    final icon = isSyncing ? Icons.sync_rounded : Icons.cloud_off_rounded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

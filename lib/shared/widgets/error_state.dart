import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'app_button.dart';

class ErrorState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    this.icon = Icons.error_outline_rounded,
    required this.title,
    required this.message,
    this.retryLabel = 'Try Again',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl, horizontal: AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(color: AppColors.errorBg, shape: BoxShape.circle),
            child: Icon(icon, size: 34, color: AppColors.error),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(message, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(label: retryLabel, onPressed: onRetry, variant: AppButtonVariant.outlined, icon: Icons.refresh_rounded),
          ],
        ],
      ),
    );
  }
}

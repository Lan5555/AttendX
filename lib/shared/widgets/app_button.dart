import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum AppButtonVariant { primary, outlined, text, danger }

/// Reusable branded button with a built-in loading state.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;
  final IconData? icon;
  final double? width;
  final double? fontSize;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.width,
    this.fontSize
  });

  @override
  Widget build(BuildContext context) {
    final disabled = isLoading || onPressed == null;
    final child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(
                variant == AppButtonVariant.outlined ||
                        variant == AppButtonVariant.text
                    ? AppColors.primary
                    : Colors.white,
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(fontSize: fontSize),
              ),
            ],
          );

    Widget button;
    switch (variant) {
      case AppButtonVariant.primary:
        button = ElevatedButton(
            onPressed: disabled ? null : onPressed, child: child);
        break;
      case AppButtonVariant.danger:
        button = ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: disabled ? null : onPressed,
          child: child,
        );
        break;
      case AppButtonVariant.outlined:
        button = OutlinedButton(
            onPressed: disabled ? null : onPressed, child: child);
        break;
      case AppButtonVariant.text:
        button =
            TextButton(onPressed: disabled ? null : onPressed, child: child);
        break;
    }

    return SizedBox(width: width, child: button);
  }
}

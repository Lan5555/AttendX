import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'liveness_capture_screen.dart';

/// Branded card that runs the liveness challenge, stores the captured
/// image on the device, and reports the generated key back to the caller.
///
/// The key is what the caller sends to the backend. The image stays on
/// the device. Later, given the key, the caller can resolve the local
/// file with [LivenessCaptureCard.resolveImage].
class LivenessCaptureCard extends StatefulWidget {
  /// Called when a capture completes and the user confirms it.
  /// [key] is the UUID used as the filename on disk.
  /// [image] is the captured image file.
  final void Function(String key, File image)? onCaptured;

  /// Called if the user cancels or the capture fails.
  final VoidCallback? onCancelled;

  /// Optional: show the captured image as a preview.
  final bool showPreview;

  /// Requires liveness check from backend
  final bool requiredCheck;

  const LivenessCaptureCard({
    super.key,
    this.onCaptured,
    this.onCancelled,
    this.showPreview = true,
    required this.requiredCheck
  });

  @override
  State<LivenessCaptureCard> createState() => _LivenessCaptureCardState();

  /// Resolves the local file for a given key. Returns null if the file
  /// doesn't exist (e.g. after a reinstall).
  static Future<File?> resolveImage(String? key) async {
    if (key == null || key.isEmpty) return null;
    final docs = await getApplicationDocumentsDirectory();
    final file = File('${docs.path}/liveness/$key.jpg');
    return await file.exists() ? file : null;
  }
}

class _LivenessCaptureCardState extends State<LivenessCaptureCard> {
  bool _capturing = false;
  bool _confirmed = false;
  String? _key;
  File? _image;
  String? _errorMessage;
  bool _cameraAvailable = true;

  @override
  void initState() {
    super.initState();
    _checkCamera();
  }

  Future<void> _checkCamera() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      setState(() => _cameraAvailable = cameras.isNotEmpty);
    } catch (_) {
      if (!mounted) return;
      setState(() => _cameraAvailable = false);
    }
  }

  Future<void> _capture() async {
    setState(() {
      _capturing = true;
      _confirmed = false;
      _errorMessage = null;
    });

    final result = await Navigator.of(context).push<LivenessResult>(
      MaterialPageRoute(
        builder: (_) =>  LivenessCaptureScreen(
          requiredBlinks: 2,
          timeout:const Duration(seconds: 30),
          requireCheck: widget.requiredCheck,
        ),
      ),
    );

    if (!mounted) return;

    // User backed out or the challenge failed.
    if (result == null || !result.passed || result.imagePath == null) {
      setState(() {
        _capturing = false;
        if (result?.failure != null) {
          _errorMessage = _failureMessage(result!.failure!);
        }
      });
      widget.onCancelled?.call();
      return;
    }

    try {
      // Persist the captured image permanently.
      final key = const Uuid().v4();
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/liveness');
      if (!await dir.exists()) await dir.create(recursive: true);

      final destFile = File('${dir.path}/$key.jpg');
      await File(result.imagePath!).copy(destFile.path);

      // Best-effort cleanup of the temp file.
      try {
        await File(result.imagePath!).delete();
      } catch (_) {}

      if (!mounted) return;

      setState(() {
        _key = key;
        _image = destFile;
        _capturing = false;
      });
    } catch (e) {
      debugPrint('[Liveness] save error: $e');
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _errorMessage = 'Could not save the captured image.';
      });
      widget.onCancelled?.call();
    }
  }

  String _failureMessage(LivenessFailure failure) {
    switch (failure) {
      case LivenessFailure.cameraUnavailable:
        return 'Camera is not available on this device.';
      case LivenessFailure.cancelled:
        return 'Liveness check was cancelled.';
      case LivenessFailure.internal:
        return 'Something went wrong. Please try again.';
    }
  }

  void _confirm() {
    final key = _key;
    final image = _image;
    if (key == null || image == null) return;

    setState(() => _confirmed = true);
    widget.onCaptured?.call(key, image);
  }

  Future<void> _retake() async {
    if (_image != null && await _image!.exists()) {
      await _image!.delete();
    }
    setState(() {
      _key = null;
      _image = null;
      _confirmed = false;
      _errorMessage = null;
    });
    await _capture();
  }

  @override
  Widget build(BuildContext context) {
    final hasCapture = _key != null && _image != null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: hasCapture
              ? AppColors.success.withValues(alpha: .3)
              : AppColors.outline,
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: hasCapture
                      ? AppColors.successBg
                      : AppColors.primary.withValues(alpha: .1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  hasCapture
                      ? Icons.verified_user_rounded
                      : Icons.face_retouching_natural_rounded,
                  color: hasCapture ? AppColors.success : AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasCapture
                          ? _confirmed
                              ? 'Liveness confirmed'
                              : 'Liveness captured'
                          : 'Liveness check',
                      style: TextStyle(
                        color: hasCapture
                            ? AppColors.success
                            : AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasCapture
                          ? _confirmed
                              ? 'Saved to your account'
                              : 'Review and confirm your photo'
                          : 'Verify you are a real person',
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasCapture)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 22,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Body ────────────────────────────────────────────────
          if (!_cameraAvailable)
            _infoBanner(
              icon: Icons.videocam_off_rounded,
              color: AppColors.warning,
              bg: AppColors.warningBg,
              message:
                  'No camera detected on this device. Liveness capture is not available.',
            )
          else if (_errorMessage != null)
            _infoBanner(
              icon: Icons.error_outline_rounded,
              color: AppColors.error,
              bg: AppColors.errorBg,
              message: _errorMessage!,
            )
          else if (hasCapture && widget.showPreview)
            _preview()
          else
            Text(
              'Complete a quick blink challenge to verify you are a real '
              'person. Your photo stays on this device.',
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: .9),
                fontSize: 12.5,
                height: 1.45,
              ),
            ),

          const SizedBox(height: AppSpacing.md),

          // ── Actions ─────────────────────────────────────────────
          if (_cameraAvailable) ...[
            if (hasCapture && !_confirmed)
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: _capturing ? null : _retake,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.outline),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text(
                          'Retake',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: _capturing ? null : _confirm,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text(
                          'Continue',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else if (hasCapture && _confirmed)
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: _capturing ? null : _retake,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: .3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    'Retake liveness check',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  onPressed: _capturing ? null : _capture,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  icon: _capturing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(
                          Icons.camera_front_rounded,
                          size: 18,
                        ),
                  label: Text(
                    _capturing ? 'Capturing…' : 'Start liveness check',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _preview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              _image!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.surfaceAlt,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            if (!_confirmed)
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.face_retouching_natural_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Looks good? Confirm to continue',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoBanner({
    required IconData icon,
    required Color color,
    required Color bg,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:attendx/services/liveness_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────
// PUBLIC API
// ─────────────────────────────────────────────────────────────────────

class LivenessResult {
  final String? imagePath;
  final bool passed;
  final LivenessFailure? failure;

  const LivenessResult._({
    required this.imagePath,
    required this.passed,
    required this.failure,
  });

  factory LivenessResult.success(String imagePath) => LivenessResult._(
        imagePath: imagePath,
        passed: true,
        failure: null,
      );

  factory LivenessResult.failed(LivenessFailure reason) => LivenessResult._(
        imagePath: null,
        passed: false,
        failure: reason,
      );
}

enum LivenessFailure {
  cameraUnavailable,
  cancelled,
  internal,
}

// ─────────────────────────────────────────────────────────────────────
// PALETTE — self-contained so the screen has zero external dependencies
// ─────────────────────────────────────────────────────────────────────

class _L {
  static const blue = Color(0xFF1E6FE8);
  static const success = Color(0xFF16A34A);
  static const black = Color(0xFF000000);
  static const white = Color(0xFFFFFFFF);
}

// ─────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────

/// Mock liveness screen: real camera, real capture, simulated blink
/// challenge. The user taps "I blinked" to advance each step. On
/// completion, the screen pops with a [LivenessResult].
///
/// Public API matches the eventual ML Kit implementation, so the caller
/// doesn't change when you swap the internals.
class LivenessCaptureScreen extends StatefulWidget {
  final int requiredBlinks;
  final Duration timeout;
  final bool requireCheck;

  const LivenessCaptureScreen({
    super.key,
    this.requiredBlinks = 2,
    this.timeout = const Duration(seconds: 30),
    required this.requireCheck
  });

  @override
  State<LivenessCaptureScreen> createState() => _LivenessCaptureScreenState();
}

class _LivenessCaptureScreenState extends State<LivenessCaptureScreen> {
  CameraController? _controller;
  bool _cameraReady = false;
  bool _finishing = false;

  int _blinkCount = 0;
  bool _awaitingBlink = false;
  Timer? _introTimer;
  bool allowVerify = true;
  final LivenessService _livenessService = LivenessService();

  @override
  void initState() {
    super.initState();
    _setupCamera();
    _checkCurrentState();
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  //==================================//
  Future<void> _checkCurrentState() async {
    final res = await _livenessService.checkLivenessState();
    if (res.success) {
      final verify = res.data['data'] == null ? false : res.data['allowVerify'];

      setState(() {
        allowVerify = verify;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.message),
        backgroundColor: Colors.red,
      ));
    }
  }

  //==================================//
  // ─────────────────────────────────────────────────────────────────
  // CAMERA
  // ─────────────────────────────────────────────────────────────────

  Future<void> _setupCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _popWith(LivenessResult.failed(LivenessFailure.cameraUnavailable));
        return;
      }

      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }

      _controller = controller;
      setState(() => _cameraReady = true);

      // Brief pause so the user can settle, then start the challenge.
      _introTimer = Timer(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        setState(() => _awaitingBlink = true);
      });
    } catch (e) {
      debugPrint('[Liveness] setup error: $e');
      _popWith(LivenessResult.failed(LivenessFailure.cameraUnavailable));
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // BLINK CHALLENGE
  // ─────────────────────────────────────────────────────────────────

  void _onBlinkTapped() {
    if (!_awaitingBlink || _finishing) return;

    HapticFeedback.selectionClick();

    _blinkCount++;

    if (_blinkCount >= widget.requiredBlinks) {
      setState(() => _awaitingBlink = false);
      if (allowVerify || !widget.requireCheck) {
        _captureAndFinish();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Invalid User please try again!'),
          backgroundColor: Colors.red,
        ));
        setState(() {
          Navigator.pop(context);
        });
      }
      return;
    }

    // Brief lockout so the user can't spam-tap through the steps.
    setState(() => _awaitingBlink = false);
    Timer(const Duration(milliseconds: 450), () {
      if (!mounted || _finishing) return;
      setState(() => _awaitingBlink = true);
    });
  }

  // ─────────────────────────────────────────────────────────────────
  // CAPTURE
  // ─────────────────────────────────────────────────────────────────

  Future<void> _captureAndFinish() async {
    if (_finishing) return;
    _finishing = true;

    try {
      final file = await _controller?.takePicture();
      if (file == null) {
        _popWith(LivenessResult.failed(LivenessFailure.internal));
        return;
      }
      _popWith(LivenessResult.success(file.path));
    } catch (e) {
      debugPrint('[Liveness] capture error: $e');
      _popWith(LivenessResult.failed(LivenessFailure.internal));
    }
  }

  void _onCancel() {
    if (_finishing) return;
    _finishing = true;
    _popWith(LivenessResult.failed(LivenessFailure.cancelled));
  }

  void _popWith(LivenessResult result) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop(result);
    });
  }

  // ─────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _L.black,
        body: !_cameraReady
            ? const _PreparingView()
            : Stack(
                fit: StackFit.expand,
                children: [
                  // ── Camera preview (mirrored) ──────────────────────
                  Positioned.fill(
                    child: Transform.scale(
                      scaleX: -1,
                      child: CameraPreview(_controller!),
                    ),
                  ),

                  // ── Vignette mask ──────────────────────────────────
                  const Positioned.fill(
                    child: CustomPaint(
                      painter: _VignettePainter(circleFraction: 0.66),
                    ),
                  ),

                  // ── Top bar: title + cancel ────────────────────────
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _onCancel,
                            icon: const Icon(
                              Icons.close_rounded,
                              color: _L.white,
                              size: 26,
                            ),
                            tooltip: 'Cancel',
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _L.black.withValues(alpha: .5),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Liveness',
                              style: TextStyle(
                                color: _L.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                  ),

                  // ── Face circle + progress ring ────────────────────
                  Center(
                    child: _FaceFrame(
                      blinkCount: _blinkCount,
                      requiredBlinks: widget.requiredBlinks,
                      awaiting: _awaitingBlink,
                    ),
                  ),

                  // ── Status text ────────────────────────────────────
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 180,
                    child: _StatusText(
                      awaiting: _awaitingBlink,
                      blinkCount: _blinkCount,
                      requiredBlinks: widget.requiredBlinks,
                    ),
                  ),

                  // ── Step dots ──────────────────────────────────────
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 132,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        widget.requiredBlinks,
                        (i) => _StepDot(
                          filled: i < _blinkCount,
                        ),
                      ),
                    ),
                  ),

                  // ── Action button ──────────────────────────────────
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 36,
                    child: _BlinkButton(
                      enabled: _awaitingBlink && !_finishing,
                      onPressed: _onBlinkTapped,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// PREPARING
// ─────────────────────────────────────────────────────────────────────

class _PreparingView extends StatelessWidget {
  const _PreparingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation(_L.white),
            ),
          ),
          SizedBox(height: 18),
          Text(
            'Preparing camera…',
            style: TextStyle(
              color: _L.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// FACE FRAME
// ─────────────────────────────────────────────────────────────────────

class _FaceFrame extends StatelessWidget {
  final int blinkCount;
  final int requiredBlinks;
  final bool awaiting;

  const _FaceFrame({
    required this.blinkCount,
    required this.requiredBlinks,
    required this.awaiting,
  });

  @override
  Widget build(BuildContext context) {
    final done = blinkCount >= requiredBlinks;
    final progress = (blinkCount / requiredBlinks).clamp(0.0, 1.0);

    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Progress ring.
          SizedBox(
            width: 296,
            height: 296,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 5,
              backgroundColor: _L.white.withValues(alpha: .15),
              valueColor: AlwaysStoppedAnimation(
                done ? _L.success : _L.blue,
              ),
            ),
          ),

          // Face circle.
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
            width: 262,
            height: 262,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: done ? _L.success : _L.white,
                width: done ? 5 : 3.5,
              ),
              boxShadow: [
                if (done)
                  BoxShadow(
                    color: _L.success.withValues(alpha: .4),
                    blurRadius: 28,
                    spreadRadius: 6,
                  ),
                if (awaiting && !done)
                  BoxShadow(
                    color: _L.blue.withValues(alpha: .25),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: done
                ? Center(
                    child: Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: _L.success.withValues(alpha: .18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: _L.success,
                        size: 56,
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// STATUS TEXT
// ─────────────────────────────────────────────────────────────────────

class _StatusText extends StatelessWidget {
  final bool awaiting;
  final int blinkCount;
  final int requiredBlinks;

  const _StatusText({
    required this.awaiting,
    required this.blinkCount,
    required this.requiredBlinks,
  });

  String get _title {
    if (blinkCount >= requiredBlinks) return 'Verifying…';
    if (awaiting) return 'Blink your eyes now';
    return 'Hold still…';
  }

  String get _subtitle {
    if (blinkCount >= requiredBlinks) {
      return 'Capturing your photo';
    }
    if (awaiting) {
      return 'Tap the button below when you blink';
    }
    return 'Get ready';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            _title,
            key: ValueKey(_title),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _L.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            _subtitle,
            key: ValueKey(_subtitle),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _L.white.withValues(alpha: .65),
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// STEP DOT
// ─────────────────────────────────────────────────────────────────────

class _StepDot extends StatelessWidget {
  final bool filled;

  const _StepDot({required this.filled});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: filled ? 16 : 10,
      height: filled ? 16 : 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? _L.success : _L.white.withValues(alpha: .3),
        boxShadow: [
          if (filled)
            BoxShadow(
              color: _L.success.withValues(alpha: .5),
              blurRadius: 12,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// BLINK BUTTON
// ─────────────────────────────────────────────────────────────────────

class _BlinkButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _BlinkButton({
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: enabled ? 1.0 : 0.4,
      child: SizedBox(
        height: 56,
        child: FilledButton.icon(
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: _L.white,
            foregroundColor: _L.black,
            disabledBackgroundColor: _L.white,
            disabledForegroundColor: _L.black,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.visibility_rounded, size: 20),
          label: const Text(
            'I blinked',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// VIGNETTE PAINTER
// ─────────────────────────────────────────────────────────────────────

class _VignettePainter extends CustomPainter {
  final double circleFraction;

  const _VignettePainter({required this.circleFraction});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * circleFraction / 2;

    final path = Path()
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;

    final paint = Paint()
      ..color = _L.black.withValues(alpha: .6)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _VignettePainter old) =>
      old.circleFraction != circleFraction;
}

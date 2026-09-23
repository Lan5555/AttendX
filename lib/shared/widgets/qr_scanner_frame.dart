import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Visual scanner frame with animated scan-line, used on the QR
/// scanning screen. Purely presentational — the actual camera
/// pipeline is mocked/simulated by the calling screen.
class QrScannerFrame extends StatefulWidget {
  final double size;
  const QrScannerFrame({super.key, this.size = 260});

  @override
  State<QrScannerFrame> createState() => _QrScannerFrameState();
}

class _QrScannerFrameState extends State<QrScannerFrame> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          _CornerFrame(size: size),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Positioned(
                top: 8 + (_controller.value * (size - 16)),
                left: 8,
                right: 8,
                child: Container(
                  height: 2.4,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(color: AppColors.securityAccent.withValues(alpha: 0.8), blurRadius: 8),
                    ],
                    gradient: LinearGradient(
                      colors: [
                        AppColors.securityAccent.withValues(alpha: 0),
                        AppColors.securityAccent,
                        AppColors.securityAccent.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CornerFrame extends StatelessWidget {
  final double size;
  const _CornerFrame({required this.size});

  @override
  Widget build(BuildContext context) {
    const cornerLen = 28.0;
    const thickness = 4.0;
    Widget corner({required bool top, required bool left}) {
      return Positioned(
        top: top ? 0 : null,
        bottom: top ? null : 0,
        left: left ? 0 : null,
        right: left ? null : 0,
        child: SizedBox(
          width: cornerLen,
          height: cornerLen,
          child: CustomPaint(
            painter: _CornerPainter(top: top, left: left, thickness: thickness, color: AppColors.securityAccent),
          ),
        ),
      );
    }

    return Stack(
      children: [
        corner(top: true, left: true),
        corner(top: true, left: false),
        corner(top: false, left: true),
        corner(top: false, left: false),
      ],
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool top;
  final bool left;
  final double thickness;
  final Color color;
  _CornerPainter({required this.top, required this.left, required this.thickness, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;
    final path = Path();
    if (top && left) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (top && !left) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!top && left) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

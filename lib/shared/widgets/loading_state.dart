import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────
// Loading State (full-screen centered)
// ─────────────────────────────────────────────────────────────
class LoadingState extends StatelessWidget {
  final String? message;
  final LoadingSize size;
  final bool showPulse;

  const LoadingState({
    super.key,
    this.message,
    this.size = LoadingSize.medium,
    this.showPulse = true,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PulsingLoader(size: size, animate: showPulse),
            if (message != null) ...[
              SizedBox(height: size == LoadingSize.large ? 20 : 14),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: size == LoadingSize.large ? 14 : 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum LoadingSize { small, medium, large }

class _PulsingLoader extends StatefulWidget {
  final LoadingSize size;
  final bool animate;

  const _PulsingLoader({required this.size, required this.animate});

  @override
  State<_PulsingLoader> createState() => _PulsingLoaderState();
}

class _PulsingLoaderState extends State<_PulsingLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  double get _diameter {
    switch (widget.size) {
      case LoadingSize.small:
        return 22;
      case LoadingSize.medium:
        return 28;
      case LoadingSize.large:
        return 40;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.animate) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.animate ? _scaleAnimation.value : 1.0,
          child: Opacity(
            opacity: widget.animate ? _opacityAnimation.value : 1.0,
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: _diameter,
        height: _diameter,
        child: CircularProgressIndicator(
          strokeWidth: widget.size == LoadingSize.large ? 3.0 : 2.6,
          color: AppColors.primary,
          strokeCap: StrokeCap.round,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shimmer Effect (shared animation driver)
// ─────────────────────────────────────────────────────────────
class ShimmerEffect extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerEffect({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.baseColor ?? AppColors.surfaceAlt;
    final highlight = widget.highlightColor ??
        Color.lerp(AppColors.surfaceAlt, Colors.white, 0.7) ??
        AppColors.surfaceAlt;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final dx = bounds.width * (_controller.value * 2 - 1);
            return LinearGradient(
              colors: [base, highlight, base],
              stops: const [0.35, 0.5, 0.65],
              begin: const Alignment(-1.0, 0),
              end: const Alignment(1.0, 0),
              transform: _SlidingGradientTransform(_controller.value),
            ).createShader(
              Rect.fromLTWH(dx, 0, bounds.width, bounds.height),
            );
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform(this.slidePercent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * (slidePercent * 2 - 1),
      0.0,
      0.0,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Skeleton Box (base building block)
// ─────────────────────────────────────────────────────────────
class SkeletonBox extends StatelessWidget {
  final double height;
  final double? width;
  final double borderRadius;
  final bool shimmer;
  final BoxShape shape;

  const SkeletonBox({
    super.key,
    this.height = 16,
    this.width,
    this.borderRadius = 6,
    this.shimmer = true,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        shape: shape,
        borderRadius: shape == BoxShape.rectangle
            ? BorderRadius.circular(borderRadius)
            : null,
      ),
    );

    if (!shimmer) return box;
    return ShimmerEffect(child: box);
  }
}

// ─────────────────────────────────────────────────────────────
// Skeleton Circle (avatars, icons)
// ─────────────────────────────────────────────────────────────
class SkeletonCircle extends StatelessWidget {
  final double size;
  final bool shimmer;

  const SkeletonCircle({
    super.key,
    this.size = 40,
    this.shimmer = true,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      height: size,
      width: size,
      shape: BoxShape.circle,
      shimmer: shimmer,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Skeleton Text (multiple lines, varying widths)
// ─────────────────────────────────────────────────────────────
class SkeletonText extends StatelessWidget {
  final int lines;
  final double lineHeight;
  final double spacing;
  final double lastLineWidthFactor;
  final bool shimmer;

  const SkeletonText({
    super.key,
    this.lines = 3,
    this.lineHeight = 12,
    this.spacing = 8,
    this.lastLineWidthFactor = 0.6,
    this.shimmer = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lines, (i) {
        final isLast = i == lines - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : spacing),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: isLast ? lastLineWidthFactor : 1.0,
            child: SkeletonBox(
              height: lineHeight,
              shimmer: shimmer,
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Skeleton Card (generic placeholder card)
// ─────────────────────────────────────────────────────────────
class SkeletonCard extends StatelessWidget {
  final double height;
  final EdgeInsets padding;
  final bool shimmer;

  const SkeletonCard({
    super.key,
    this.height = 96,
    this.padding = const EdgeInsets.all(16),
    this.shimmer = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline.withValues(alpha: .4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              SkeletonBox(width: 60, height: 14, shimmer: shimmer),
              const Spacer(),
              SkeletonBox(
                width: 70,
                height: 20,
                borderRadius: 10,
                shimmer: shimmer,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SkeletonBox(width: 180, height: 12, shimmer: shimmer),
          const SizedBox(height: 8),
          SkeletonBox(width: 120, height: 10, shimmer: shimmer),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Skeleton List (rows of avatar + text)
// ─────────────────────────────────────────────────────────────
class SkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final bool showAvatar;
  final bool shimmer;

  const SkeletonList({
    super.key,
    this.itemCount = 4,
    this.itemHeight = 64,
    this.showAvatar = true,
    this.shimmer = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(itemCount, (i) {
        return Padding(
          padding: EdgeInsets.only(bottom: i == itemCount - 1 ? 0 : 12),
          child: SizedBox(
            height: itemHeight,
            child: Row(
              children: [
                if (showAvatar) ...[
                  SkeletonCircle(size: 44, shimmer: shimmer),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 140, height: 12, shimmer: shimmer),
                      const SizedBox(height: 8),
                      SkeletonBox(width: 90, height: 10, shimmer: shimmer),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Skeleton Grid (e.g., stat cards)
// ─────────────────────────────────────────────────────────────
class SkeletonGrid extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;
  final double tileHeight;
  final double spacing;
  final bool shimmer;

  const SkeletonGrid({
    super.key,
    this.itemCount = 4,
    this.crossAxisCount = 2,
    this.tileHeight = 110,
    this.spacing = 12,
    this.shimmer = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth =
            (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                crossAxisCount;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(itemCount, (i) {
            return SizedBox(
              width: tileWidth,
              height: tileHeight,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: AppColors.outline.withValues(alpha: .4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonBox(
                      width: 28,
                      height: 28,
                      borderRadius: 8,
                      shimmer: shimmer,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 50, height: 16, shimmer: shimmer),
                        const SizedBox(height: 6),
                        SkeletonBox(width: 70, height: 10, shimmer: shimmer),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Skeleton Dashboard (composite for StudentHomeScreen)
// ─────────────────────────────────────────────────────────────
class SkeletonDashboard extends StatelessWidget {
  const SkeletonDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting row
          const Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 180, height: 18),
                    SizedBox(height: 8),
                    SkeletonBox(width: 120, height: 12),
                  ],
                ),
              ),
              SkeletonBox(width: 52, height: 52, borderRadius: 16),
            ],
          ),
          const SizedBox(height: 24),

          // Overall attendance card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: AppColors.outline.withValues(alpha: .4)),
            ),
            child: const Row(
              children: [
                SkeletonCircle(size: 88),
                SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 140, height: 14),
                      SizedBox(height: 10),
                      SkeletonBox(width: double.infinity, height: 10),
                      SizedBox(height: 6),
                      SkeletonBox(width: 180, height: 10),
                      SizedBox(height: 12),
                      SkeletonBox(
                        width: 130,
                        height: 22,
                        borderRadius: 11,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section header
          const SkeletonBox(width: 160, height: 18),
          const SizedBox(height: 12),

          // Class cards
          const SkeletonCard(height: 100),
          const SizedBox(height: 12),
          const SkeletonCard(height: 100),
          const SizedBox(height: 24),

          // Section header
          const SkeletonBox(width: 150, height: 18),
          const SizedBox(height: 12),

          // Stat grid
          const SkeletonGrid(itemCount: 4, crossAxisCount: 2, tileHeight: 110),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Inline Loading (for buttons / small contexts)
// ─────────────────────────────────────────────────────────────
class InlineLoader extends StatelessWidget {
  final double size;
  final Color? color;
  final double strokeWidth;

  const InlineLoader({
    super.key,
    this.size = 16,
    this.color,
    this.strokeWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: color ?? AppColors.primary,
        strokeCap: StrokeCap.round,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Loading Overlay (blocks interaction while loading)
// ─────────────────────────────────────────────────────────────
class LoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String? message;

  const LoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: AbsorbPointer(
              child: Container(
                color: Colors.black.withValues(alpha: .25),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .15),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const LoadingState(
                          size: LoadingSize.medium,
                          showPulse: true,
                        ),
                        if (message != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            message!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
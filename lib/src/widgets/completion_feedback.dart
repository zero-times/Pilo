import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/dashboard_tokens.dart';

class CompletionFeedback extends StatefulWidget {
  const CompletionFeedback({
    super.key,
    required this.visible,
    this.message = '训练完成，继续保持！',
  });

  final bool visible;
  final String message;

  @override
  State<CompletionFeedback> createState() => _CompletionFeedbackState();
}

class _CompletionFeedbackState extends State<CompletionFeedback>
    with SingleTickerProviderStateMixin {
  static const _accent = DashboardTokens.accent;
  static const _success = DashboardTokens.success;
  static const _textPrimary = DashboardTokens.textPrimary;

  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _opacityAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.4,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(covariant CompletionFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: AnimatedOpacity(
        opacity: widget.visible ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _accent.withValues(
                          alpha: 0.12 * (1 - _controller.value),
                        ),
                      ),
                    ),
                  );
                },
              ),
              CustomPaint(
                size: const Size(200, 200),
                painter: _ParticlesPainter(progress: _controller.value),
              ),
              FadeTransition(
                opacity: _opacityAnimation,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: DashboardTokens.surface,
                    borderRadius: BorderRadius.circular(
                      DashboardTokens.cardRadius,
                    ),
                    border: Border.all(color: DashboardTokens.successSoft),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x140F172A),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: _success, size: 32),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: _textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParticlesPainter extends CustomPainter {
  const _ParticlesPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    const particleCount = 14;
    final radius = 26 + (progress * 54);

    for (var i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 6.28318530718;
      final particleCenter = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      paint.color = _CompletionFeedbackState._accent.withValues(
        alpha: 1 - progress,
      );
      canvas.drawCircle(particleCenter, 3.5 - (progress * 1.5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

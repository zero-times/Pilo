import 'package:flutter/material.dart';

enum TimerButtonStatus { idle, running, paused, completed }

class AnimatedTimerButton extends StatefulWidget {
  const AnimatedTimerButton({
    super.key,
    required this.duration,
    this.autoStartSignal = 0,
    this.onTick,
    this.onStatusChanged,
    this.onCompleted,
  });

  final Duration duration;
  final int autoStartSignal;
  final ValueChanged<int>? onTick;
  final ValueChanged<TimerButtonStatus>? onStatusChanged;
  final VoidCallback? onCompleted;

  @override
  State<AnimatedTimerButton> createState() => _AnimatedTimerButtonState();
}

class _AnimatedTimerButtonState extends State<AnimatedTimerButton>
    with SingleTickerProviderStateMixin {
  static const _accent = Color(0xFFF97316);
  static const _textPrimary = Color(0xFF0F172A);

  late final AnimationController _controller;
  TimerButtonStatus _status = TimerButtonStatus.idle;
  int _remainingSeconds = 0;
  late int _handledAutoStartSignal;
  late int _lastTickSeconds;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.duration.inSeconds;
    _lastTickSeconds = _remainingSeconds;
    _handledAutoStartSignal = widget.autoStartSignal;
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addListener(_handleTick)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _status = TimerButtonStatus.completed;
            _remainingSeconds = 0;
          });
          _emitTick(0);
          widget.onStatusChanged?.call(_status);
          widget.onCompleted?.call();
        }
      });
    if (widget.autoStartSignal > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _status != TimerButtonStatus.idle) {
          return;
        }
        _start();
      });
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedTimerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoStartSignal == _handledAutoStartSignal) {
      return;
    }
    _handledAutoStartSignal = widget.autoStartSignal;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _status != TimerButtonStatus.idle) {
        return;
      }
      _start();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTick() {
    if (_status != TimerButtonStatus.running) {
      return;
    }
    _emitTick(_durationLeft());
  }

  void _emitTick(int seconds) {
    if (seconds == _lastTickSeconds) {
      return;
    }
    _lastTickSeconds = seconds;
    widget.onTick?.call(seconds);
  }

  void _toggle() {
    switch (_status) {
      case TimerButtonStatus.idle:
        _start();
      case TimerButtonStatus.running:
        _pause();
      case TimerButtonStatus.paused:
        _resume();
      case TimerButtonStatus.completed:
        _reset();
    }
  }

  void _start() {
    _controller.forward(from: 0);
    _remainingSeconds = widget.duration.inSeconds;
    _emitTick(_remainingSeconds);
    setState(() => _status = TimerButtonStatus.running);
    widget.onStatusChanged?.call(_status);
  }

  void _pause() {
    _controller.stop();
    setState(() {
      _status = TimerButtonStatus.paused;
      _remainingSeconds = _durationLeft();
    });
    _emitTick(_remainingSeconds);
    widget.onStatusChanged?.call(_status);
  }

  void _resume() {
    _controller.forward();
    setState(() => _status = TimerButtonStatus.running);
    widget.onStatusChanged?.call(_status);
  }

  void _reset() {
    _controller.reset();
    setState(() {
      _status = TimerButtonStatus.idle;
      _remainingSeconds = widget.duration.inSeconds;
    });
    _emitTick(_remainingSeconds);
    widget.onStatusChanged?.call(_status);
  }

  int _durationLeft() {
    final left = (widget.duration.inSeconds * (1 - _controller.value)).round();
    return left.clamp(0, widget.duration.inSeconds);
  }

  String _formatClock(int seconds) {
    final safeSeconds = seconds.clamp(0, 99 * 3600);
    final hours = safeSeconds ~/ 3600;
    final minutes = (safeSeconds % 3600) ~/ 60;
    final secs = safeSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String get _label {
    switch (_status) {
      case TimerButtonStatus.idle:
        return '开始';
      case TimerButtonStatus.running:
        return '暂停';
      case TimerButtonStatus.paused:
        return '继续';
      case TimerButtonStatus.completed:
        return '重置';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final seconds = _status == TimerButtonStatus.running
            ? _durationLeft()
            : _remainingSeconds;
        final isCompleted = _status == TimerButtonStatus.completed;
        final buttonStyle = isCompleted
            ? FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                backgroundColor: const Color(0xFFF1F5F9),
                foregroundColor: _textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              )
            : FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              );

        return Column(
          children: [
            SizedBox(
              height: 112,
              width: 112,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    color: _accent,
                    backgroundColor: const Color(0xFFE5EAF0),
                  ),
                  isCompleted
                      ? Icon(Icons.check_circle, color: _accent, size: 36)
                      : Semantics(
                          label: '剩余 ${_formatClock(seconds)}',
                          child: Text(
                            _formatClock(seconds),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: _textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _toggle,
              style: buttonStyle,
              child: Text(_label),
            ),
          ],
        );
      },
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Сброс таймера при любом действии пользователя (мышь / клавиатура).
class InactivityWatcher extends StatefulWidget {
  final Duration timeout;
  final Duration warningBefore;
  final VoidCallback onTimeout;
  final void Function(Duration remaining)? onWarning;
  final VoidCallback? onActivity;
  final Widget child;

  const InactivityWatcher({
    super.key,
    required this.timeout,
    required this.warningBefore,
    required this.onTimeout,
    this.onWarning,
    this.onActivity,
    required this.child,
  });

  @override
  State<InactivityWatcher> createState() => _InactivityWatcherState();
}

class _InactivityWatcherState extends State<InactivityWatcher> {
  Timer? _timer;
  Timer? _warningTimer;
  bool _warningShown = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    _restart();
  }

  bool _onKey(KeyEvent event) {
    _restart();
    return false;
  }

  void _restart() {
    widget.onActivity?.call();
    _timer?.cancel();
    _warningTimer?.cancel();
    _warningShown = false;

    final warnAfter = widget.timeout - widget.warningBefore;
    if (warnAfter > Duration.zero && widget.onWarning != null) {
      _warningTimer = Timer(warnAfter, () {
        if (!_warningShown) {
          _warningShown = true;
          widget.onWarning!(widget.warningBefore);
        }
      });
    }

    _timer = Timer(widget.timeout, widget.onTimeout);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _timer?.cancel();
    _warningTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _restart(),
      onPointerMove: (_) => _restart(),
      onPointerSignal: (_) => _restart(),
      child: widget.child,
    );
  }
}

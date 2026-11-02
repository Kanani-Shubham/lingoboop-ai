import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/floating_pet_avatar.dart';
import '../companion/presentation/companion_state.dart';
import 'poly_card_widget.dart';

/// Unified Floating Pet Companion & Sticky PolyCard Stack
/// Directly mirrors the autonomous roaming, drag, and docking physics
/// from lines 116-139 of `polypet-demo.html`.
class FloatingPetOverlayStack extends ConsumerStatefulWidget {
  final Widget child;

  const FloatingPetOverlayStack({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<FloatingPetOverlayStack> createState() =>
      _FloatingPetOverlayStackState();
}

class _FloatingPetOverlayStackState extends ConsumerState<FloatingPetOverlayStack>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  double _x = 120.0;
  double _y = 0.0;
  double _tx = 120.0;
  String _mode = 'idle';
  int _until = 0; // Epoch milliseconds until state change
  double _face = 0.5; // Rotation heading angle
  String _side = 'r'; // 'r' or 'l'
  bool _isDragging = false;
  Offset _dragStart = Offset.zero;
  Offset _dragOffset = Offset.zero;
  bool _hasMovedSignificantly = false;

  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  int get _nowMs => DateTime.now().millisecondsSinceEpoch;

  double _floor(double screenHeight) =>
      (screenHeight - 64.0 - 34.0 - 150.0).clamp(100.0, screenHeight - 248.0);

  void _setMode(String m, [int ms = 0]) {
    setState(() {
      _mode = m;
      _until = _nowMs + ms;
    });
    ref.read(companionProvider.notifier).setPetMode(m);
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final dtSeconds = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;
    final dt = dtSeconds.clamp(0.0, 0.1);

    final size = MediaQuery.of(context).size;
    final screenW = size.width;
    final screenH = size.height;
    final floorY = _floor(screenH);
    final isCardOpen = ref.read(companionProvider).isCardOpen;

    bool needsSetState = false;

    // Gravity: smoothly pull back down to floor when not dragging
    if (!_isDragging) {
      final oldY = _y;
      _y += (floorY - _y) * math.min(1.0, dt * 7.0);
      if (_mode == 'drag' && (floorY - _y).abs() < 3.0) {
        _setMode('idle', 1500);
      }
      if ((oldY - _y).abs() > 0.01) needsSetState = true;
    }

    // Walking physics
    if (_mode == 'walk' && !_isDragging) {
      final d = _tx - _x;
      if (d.abs() < 4.0 || _nowMs > _until) {
        _setMode('idle', 1500 + (_random.nextDouble() * 2500).toInt());
      } else {
        final sign = d.sign;
        _x += sign * 58.0 * dt;
        _face = sign * math.pi / 2.0;
        needsSetState = true;
      }
    }
    // Autonomous roaming when idle & card closed & not dragging
    else if (!isCardOpen &&
        !_isDragging &&
        (_mode == 'idle' || _mode == 'dance') &&
        _nowMs > _until) {
      final r = _random.nextDouble();
      if (r < 0.6) {
        // 60% chance to wander to random x
        _tx = _random.nextDouble() * (screenW - 110.0) - 20.0;
        _setMode('walk', 9000);
      } else if (r < 0.8) {
        // 20% chance to dance
        _setMode('dance', 2600);
      } else {
        // 20% chance to remain idle
        _setMode('idle', 2000 + (_random.nextDouble() * 3000).toInt());
      }
    }

    // Stationary facing direction
    if (_mode != 'walk') {
      _face = isCardOpen ? (_side == 'r' ? 0.9 : -0.9) : 0.5;
    }

    if (needsSetState) {
      setState(() {});
    }
  }

  void _openCard(double screenWidth) {
    _side = (_x + 75.0 < screenWidth / 2.0) ? 'r' : 'l';
    _tx = (_side == 'r') ? -24.0 : (screenWidth - 126.0);
    _setMode('walk', 4000);
    ref.read(companionProvider.notifier).openCard();
  }

  void _closeCard() {
    ref.read(companionProvider.notifier).closeCard();
    _setMode('idle', 1200);
  }

  void _toggleCard(double screenWidth) {
    final isOpen = ref.read(companionProvider).isCardOpen;
    if (isOpen) {
      _closeCard();
    } else {
      _openCard(screenWidth);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenW = size.width;
    final screenH = size.height;
    final companionState = ref.watch(companionProvider);
    final isCardOpen = companionState.isCardOpen;

    // Floor fallback for initial layout
    if (_y == 0.0) {
      _y = _floor(screenH);
    }

    return Stack(
      children: [
        // Underlying screen content
        widget.child,

        // Stage Overlay: Sticky PolyCard (#cd)
        if (isCardOpen)
          Positioned(
            bottom: 76, // Exact prototype bottom: 76px
            left: _side == 'r' ? 108 : null, // Exact prototype: side==='r'?'108px':'auto'
            right: _side == 'r' ? null : 108, // Exact prototype: side==='r'?'auto':'108px'
            child: PolyCardWidget(
              onClose: _closeCard,
            ),
          ),

        // Stage Overlay: 3D Pet Canvas (#pw / #cv)
        Positioned(
          left: _x,
          top: _y,
          child: GestureDetector(
            onPanDown: (details) {
              _isDragging = true;
              _hasMovedSignificantly = false;
              _dragStart = details.globalPosition;
              _dragOffset = Offset(
                details.globalPosition.dx - _x,
                details.globalPosition.dy - _y,
              );
            },
            onPanUpdate: (details) {
              final dist = (details.globalPosition - _dragStart).distance;
              if (dist > 6.0 && !_hasMovedSignificantly) {
                _hasMovedSignificantly = true;
                if (isCardOpen) _closeCard();
              }
              if (_hasMovedSignificantly) {
                setState(() {
                  _x = (details.globalPosition.dx - _dragOffset.dx).clamp(-40.0, screenW - 110.0);
                  _y = (details.globalPosition.dy - _dragOffset.dy).clamp(0.0, screenH - 160.0);
                });
                _setMode('drag');
              }
            },
            onPanEnd: (_) {
              if (_isDragging && !_hasMovedSignificantly) {
                _toggleCard(screenW);
              }
              _isDragging = false;
            },
            onPanCancel: () {
              _isDragging = false;
            },
            child: FloatingPetAvatar(
              character: companionState.activePet,
              mode: _mode,
              showHint: !isCardOpen,
              size: 150.0,
              facing: _face,
              isCardOpen: isCardOpen,
              dockSide: _side,
              onTap: () => _toggleCard(screenW),
              onDragUpdate: (_) {},
              onDragEnd: () {},
            ),
          ),
        ),
      ],
    );
  }
}

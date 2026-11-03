import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/overlay_service.dart';
import '../../../core/services/user_data_service.dart';
import '../../../core/widgets/floating_pet_avatar.dart';
import '../../../core/widgets/polypet_bottom_nav.dart';
import '../../achievements/presentation/achievements_screen.dart';
import '../../companion/presentation/companion_state.dart';
import '../../companion/presentation/lingo_card_widget.dart';
import '../../settings/presentation/pet_settings_sheet.dart';
import '../../home/presentation/main_companion_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../progress/presentation/progress_screen.dart';

class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  Offset _petPos = const Offset(120, 520);
  double _tx = 120.0;
  int _until = 0;
  double _facing = 0.5;
  String _side = 'r';
  bool _hasTappedPet = false;
  bool _isCustomPositioned = false;

  late Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  final math.Random _random = math.Random();
  StreamSubscription? _overlaySubscription;

  final List<Widget> _screens = const [
    MainCompanionScreen(showFloatingPet: false),
    ProgressScreen(),
    AchievementsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _initOverlayListener();
    _restoreSavedPosition();
  }

  void _initOverlayListener() {
    try {
      _overlaySubscription = OverlayService.instance.overlayEvents.listen((event) {
        if (!mounted) return;
        if (event is Map) {
          final ev = event['event'];
          if (ev == 'open_card_requested' || ev == 'pet_tapped') {
            final size = MediaQuery.of(context).size;
            _openCard(size.width);
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _restoreSavedPosition() async {
    try {
      final prefs = await UserDataService.instance.getPreferences();
      if (prefs != null && mounted) {
        final normX = (prefs['overlay_position_x'] as num?)?.toDouble();
        final normY = (prefs['overlay_position_y'] as num?)?.toDouble();
        if (normX != null && normY != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final size = MediaQuery.of(context).size;
            final restoredX = (normX * size.width).clamp(-30.0, size.width - 120.0);
            final restoredY = (normY * size.height).clamp(40.0, size.height - 180.0);
            setState(() {
              _petPos = Offset(restoredX, restoredY);
              _side = (restoredX + 75.0 < size.width / 2.0) ? 'r' : 'l';
              _isCustomPositioned = true;
            });
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _ticker.dispose();
    _overlaySubscription?.cancel();
    super.dispose();
  }

  int get _nowMs => DateTime.now().millisecondsSinceEpoch;

  double _floor(double screenHeight) =>
      (screenHeight - 64.0 - 34.0 - 150.0).clamp(100.0, screenHeight - 248.0);

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final dtSeconds = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;
    final dt = dtSeconds.clamp(0.0, 0.1);

    final size = MediaQuery.of(context).size;
    final screenW = size.width;
    final screenH = size.height;
    final floorY = _floor(screenH);
    final companionState = ref.read(companionProvider);
    final isCardOpen = companionState.isCardOpen;
    final currentMode = companionState.petMode;

    bool needsUpdate = false;
    double newX = _petPos.dx;
    double newY = _petPos.dy;

    // Gravity: smoothly pull back down to floor on initial placement before user moves it
    if (!_isCustomPositioned && currentMode != 'drag') {
      newY += (floorY - newY) * math.min(1.0, dt * 7.0);
      if ((newY - _petPos.dy).abs() > 0.05) needsUpdate = true;
    }

    // Walking physics towards target tx
    if (currentMode == 'walk') {
      final d = _tx - newX;
      if (d.abs() < 4.0 || _nowMs > _until) {
        newX = _tx;
        ref.read(companionProvider.notifier).setPetMode('idle');
        _until = _nowMs + 1500 + (_random.nextDouble() * 2500).toInt();
        needsUpdate = true;
      } else {
        final sign = d.sign;
        newX += sign * 58.0 * dt;
        _facing = sign * math.pi / 2.0;
        needsUpdate = true;
      }
    }
    // Autonomous roaming when idle & card closed & not dragging
    else if (!isCardOpen &&
        currentMode != 'drag' &&
        (currentMode == 'idle' || currentMode == 'dance') &&
        _nowMs > _until) {
      final r = _random.nextDouble();
      if (r < 0.6) {
        // 60% chance to pick random target and wander
        _tx = (_random.nextDouble() * (screenW - 110.0) - 20.0).clamp(0.0, screenW - 150.0);
        ref.read(companionProvider.notifier).setPetMode('walk');
        _until = _nowMs + 9000;
      } else if (r < 0.8) {
        // 20% chance to dance
        ref.read(companionProvider.notifier).setPetMode('dance');
        _until = _nowMs + 2600;
      } else {
        // 20% chance to stay idle
        ref.read(companionProvider.notifier).setPetMode('idle');
        _until = _nowMs + 2000 + (_random.nextDouble() * 3000).toInt();
      }
    }

    // Facing angle when stationary
    if (currentMode != 'walk') {
      _facing = isCardOpen ? (_side == 'r' ? 0.9 : -0.9) : 0.5;
    }

    if (needsUpdate) {
      setState(() {
        _petPos = Offset(newX, newY);
      });
    }
  }

  void _openCard(double screenWidth) {
    _isCustomPositioned = false;
    _side = (_petPos.dx + 75.0 < screenWidth / 2.0) ? 'r' : 'l';
    _tx = (_side == 'r') ? -24.0 : (screenWidth - 126.0);
    ref.read(companionProvider.notifier).setPetMode('walk');
    _until = _nowMs + 4000;
    ref.read(companionProvider.notifier).openCard();
  }

  void _closeCard() {
    ref.read(companionProvider.notifier).closeCard();
    ref.read(companionProvider.notifier).setPetMode('idle');
    _facing = 0.5;
    _until = _nowMs + 1200;
  }

  void _toggleCard(double screenWidth) {
    setState(() => _hasTappedPet = true);
    final isOpen = ref.read(companionProvider).isCardOpen;
    if (isOpen) {
      _closeCard();
    } else {
      _openCard(screenWidth);
    }
  }

  @override
  Widget build(BuildContext context) {
    final companionState = ref.watch(companionProvider);
    final notifier = ref.read(companionProvider.notifier);
    final size = MediaQuery.of(context).size;
    final screenW = size.width;
    final screenH = size.height;

    ref.listen<CompanionState>(companionProvider, (previous, current) {
      if (current.isCardOpen && !(previous?.isCardOpen ?? false)) {
        _isCustomPositioned = false;
        _side = (_petPos.dx + 75.0 < screenW / 2.0) ? 'r' : 'l';
        _tx = (_side == 'r') ? -24.0 : (screenW - 126.0);
        notifier.setPetMode('walk');
        _until = _nowMs + 4000;
      } else if (!current.isCardOpen && (previous?.isCardOpen ?? false)) {
        setState(() {
          _facing = 0.5;
        });
      }
    });

    if (_petPos.dy == 520.0 && screenH > 0) {
      _petPos = Offset(_petPos.dx, _floor(screenH));
    }

    return Scaffold(
      backgroundColor: AppColors.phoneBackground,
      body: Stack(
        children: [
          // 1. Current Tab Content
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),

          // Dismissal barrier when PolyCard is open
          if (companionState.isCardOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeCard,
              ),
            ),

          // 2. Persistent Settings Sheet Dropdown
          if (companionState.isSettingsOpen)
            Positioned(
              top: 60,
              left: 12,
              right: 12,
              child: const PetSettingsSheet(),
            ),

          // 3. Persistent Floating PolyCard Dialogue (#cd) matching exact prototype docking
          if (companionState.isCardOpen)
            Positioned(
              left: _side == 'r' ? 108.0 : null,
              right: _side == 'r' ? null : 108.0,
              bottom: 76.0 + MediaQuery.of(context).viewInsets.bottom,
              child: const LingoCardWidget(),
            ),

          // 4. Persistent Draggable Floating 3D Pet Companion across ALL tabs
          Positioned(
            left: _petPos.dx,
            top: _petPos.dy,
            child: FloatingPetAvatar(
              character: companionState.activePet,
              mode: companionState.petMode,
              showHint: !_hasTappedPet && !companionState.isCardOpen,
              size: 150.0,
              facing: _facing,
              isCardOpen: companionState.isCardOpen,
              dockSide: _side,
              onTap: () => _toggleCard(screenW),
              onDragUpdate: (delta) {
                if (companionState.isCardOpen) {
                  _closeCard();
                }
                _isCustomPositioned = true;
                final newX = (_petPos.dx + delta.dx).clamp(-30.0, screenW - 120.0);
                final newY = (_petPos.dy + delta.dy).clamp(40.0, screenH - 180.0);
                final newSide = (newX + 75.0 < screenW / 2.0) ? 'r' : 'l';
                setState(() {
                  _petPos = Offset(newX, newY);
                  _side = newSide;
                  _facing = 0.5;
                });
                notifier.setPetMode('drag');
              },
              onDragEnd: () {
                notifier.finishPetDrag();
                if (screenW > 0 && screenH > 0) {
                  final normX = (_petPos.dx / screenW).clamp(0.0, 1.0);
                  final normY = (_petPos.dy / screenH).clamp(0.0, 1.0);
                  UserDataService.instance.savePreferences(
                    overlayPositionX: normX,
                    overlayPositionY: normY,
                  );
                }
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: PolyPetBottomNav(
        currentIndex: _currentIndex,
        activeAccentColor: companionState.activePet.accentColor,
        onTabSelected: (index) {
          if (companionState.isCardOpen) {
            _closeCard();
          }
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}

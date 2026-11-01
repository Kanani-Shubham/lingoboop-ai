import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../constants/app_colors.dart';
import '../constants/character_data.dart';

class FloatingPetAvatar extends StatefulWidget {
  final CharacterModel character;
  final String mode; // 'idle', 'walk', 'dance', 'think', 'talk', 'listen', 'drag'
  final VoidCallback onTap;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;
  final bool showHint;
  final double size;

  const FloatingPetAvatar({
    super.key,
    required this.character,
    required this.mode,
    required this.onTap,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.showHint = true,
    this.size = 150.0,
  });

  @override
  State<FloatingPetAvatar> createState() => _FloatingPetAvatarState();
}

class _FloatingPetAvatarState extends State<FloatingPetAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _idleController;
  WebViewController? _webController;
  bool _isWebViewReady = false;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _initWeb3DViewer();
  }

  void _initWeb3DViewer() {
    if (WebViewPlatform.instance == null) {
      return; // Headless unit tests or environments without native webview platform
    }
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (url) {
              if (mounted) {
                setState(() => _isWebViewReady = true);
                _updatePetInViewer(widget.character.key);
                _updateModeInViewer(widget.mode);
              }
            },
          ),
        )
        ..loadFlutterAsset('assets/web/pet_viewer.html');
      _webController = controller;
    } catch (e) {
      debugPrint('WebView 3D viewer notice: $e');
    }
  }

  void _updatePetInViewer(String petKey) {
    if (_isWebViewReady && _webController != null) {
      _webController?.runJavaScript("if (window.setPet) window.setPet('$petKey');");
    }
  }

  void _updateModeInViewer(String mode) {
    if (_isWebViewReady && _webController != null) {
      _webController?.runJavaScript("if (window.setMode) window.setMode('$mode');");
    }
  }

  @override
  void didUpdateWidget(covariant FloatingPetAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.character.key != widget.character.key) {
      _updatePetInViewer(widget.character.key);
    }
    if (oldWidget.mode != widget.mode) {
      _updateModeInViewer(widget.mode);
    }
  }

  @override
  void dispose() {
    _idleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onPanUpdate: (details) => widget.onDragUpdate(details.delta),
      onPanEnd: (_) => widget.onDragEnd(),
      child: AnimatedBuilder(
        animation: _idleController,
        builder: (context, child) {
          double floatY = 0;
          double tilt = 0;
          double scaleY = 1.0;

          if (widget.mode == 'idle') {
            floatY = math.sin(_idleController.value * math.pi) * 6;
          } else if (widget.mode == 'dance') {
            floatY = math.sin(_idleController.value * math.pi * 3) * 12;
            tilt = math.cos(_idleController.value * math.pi * 3) * 0.15;
          } else if (widget.mode == 'listen') {
            tilt = 0.16; // Head tilt matching prototype tilt=0.16
          } else if (widget.mode == 'talk') {
            scaleY = 1.0 + math.sin(_idleController.value * math.pi * 4) * 0.08;
          }

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // 3D Pet Character Preview with physical animation transforms
              Transform.translate(
                offset: Offset(0, floatY),
                child: Transform.rotate(
                  angle: tilt,
                  child: Transform.scale(
                    scaleY: scaleY,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.character.accentColor.withValues(alpha: 0.22),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _webController != null && !kIsWeb
                            ? IgnorePointer(
                                child: WebViewWidget(controller: _webController!),
                              )
                            : Image.asset(
                                widget.character.previewAsset,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                      ),
                    ),
                  ),
                ),
              ),

              // "Tap me to talk" Hint pill matching prototype .hint
              if (widget.showHint)
                Positioned(
                  top: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                        bottomLeft: Radius.circular(3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x20000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Tap me to talk',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../constants/app_colors.dart';
import '../constants/character_data.dart';

/// Exact 3D Floating Pet Canvas matching #pw and #cv in `polypet-demo.html`
class FloatingPetAvatar extends StatefulWidget {
  final CharacterModel character;
  final String mode; // 'idle', 'walk', 'dance', 'think', 'talk', 'listen', 'drag', 'oops', 'cheer'
  final VoidCallback onTap;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;
  final bool showHint;
  final double size;
  final double? facing; // Rotation angle in radians
  final bool isCardOpen;
  final String dockSide; // 'r' or 'l'

  const FloatingPetAvatar({
    super.key,
    required this.character,
    required this.mode,
    required this.onTap,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.showHint = true,
    this.size = 150.0,
    this.facing,
    this.isCardOpen = false,
    this.dockSide = 'r',
  });

  @override
  State<FloatingPetAvatar> createState() => _FloatingPetAvatarState();
}

class _FloatingPetAvatarState extends State<FloatingPetAvatar> {
  WebViewController? _webController;
  bool _isWebViewReady = false;

  @override
  void initState() {
    super.initState();
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
                _updateDockInViewer(widget.isCardOpen, widget.dockSide);
                if (widget.facing != null) {
                  _updateFacingInViewer(widget.facing!);
                }
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

  void _updateFacingInViewer(double facing) {
    if (_isWebViewReady && _webController != null) {
      _webController?.runJavaScript("if (window.setFacing) window.setFacing($facing);");
    }
  }

  void _updateDockInViewer(bool open, String side) {
    if (_isWebViewReady && _webController != null) {
      _webController?.runJavaScript("if (window.setCardDock) window.setCardDock($open, '$side');");
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
    if (oldWidget.isCardOpen != widget.isCardOpen || oldWidget.dockSide != widget.dockSide) {
      _updateDockInViewer(widget.isCardOpen, widget.dockSide);
    }
    if (widget.facing != null && widget.facing != oldWidget.facing) {
      _updateFacingInViewer(widget.facing!);
    }
  }

  double _totalPanDistance = 0.0;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: (details) {
        _totalPanDistance = 0.0;
        _isDragging = false;
      },
      onPanUpdate: (details) {
        _totalPanDistance += details.delta.distance;
        if (_totalPanDistance > 6.0) {
          _isDragging = true;
          widget.onDragUpdate(details.delta);
        }
      },
      onPanEnd: (_) {
        if (_isDragging) {
          widget.onDragEnd();
        } else {
          widget.onTap();
        }
        _isDragging = false;
        _totalPanDistance = 0.0;
      },
      onPanCancel: () {
        if (_isDragging) {
          widget.onDragEnd();
        }
        _isDragging = false;
        _totalPanDistance = 0.0;
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        color: Colors.transparent, // Ensures 100% opaque hit test surface
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // 3D Pet Character Preview (unclipped, fully transparent canvas)
            SizedBox(
              width: widget.size,
              height: widget.size,
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

            // "Tap me to talk" Hint pill matching prototype .hint
            if (widget.showHint && !widget.isCardOpen)
              Positioned(
                top: 8,
                left: widget.size / 2 - 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                        color: Color(0x33000000), // 0 4px 12px #0003
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    'Tap me to talk',
                    style: GoogleFonts.fredoka(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

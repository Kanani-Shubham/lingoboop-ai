import 'package:flutter/material.dart';

class PolyPetMicButton extends StatefulWidget {
  final bool isListening;
  final VoidCallback onTap;
  final Color accentColor;

  const PolyPetMicButton({
    super.key,
    required this.isListening,
    required this.onTap,
    required this.accentColor,
  });

  @override
  State<PolyPetMicButton> createState() => _PolyPetMicButtonState();
}

class _PolyPetMicButtonState extends State<PolyPetMicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isListening) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PolyPetMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !oldWidget.isListening) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isListening && oldWidget.isListening) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              if (widget.isListening)
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.35),
                  spreadRadius: _pulseAnimation.value,
                  blurRadius: 0,
                ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onTap,
              child: Center(
                child: Icon(
                  widget.isListening ? Icons.mic : Icons.mic_none,
                  color: widget.accentColor,
                  size: 26,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

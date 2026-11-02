import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/widgets/karaoke_lyrics_view.dart';
import '../companion/presentation/companion_state.dart';

/// Exact PolyCard implementation matching DOM & CSS lines 36-52 of `polypet-demo.html`
class PolyCardWidget extends ConsumerStatefulWidget {
  final VoidCallback? onClose;

  const PolyCardWidget({super.key, this.onClose});

  @override
  ConsumerState<PolyCardWidget> createState() => _PolyCardWidgetState();
}

class _PolyCardWidgetState extends ConsumerState<PolyCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _popController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  final TextEditingController _textController = TextEditingController();
  final TextEditingController _editTranscriptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    // Pop animation: scale .88 -> 1.0, opacity 0.0 -> 1.0 matching @keyframes pop
    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _popController, curve: Curves.easeOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _popController, curve: Curves.easeOut),
    );

    _popController.forward();
  }

  @override
  void dispose() {
    _popController.dispose();
    _textController.dispose();
    _editTranscriptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(companionProvider);
    final notifier = ref.read(companionProvider.notifier);

    final langPair =
        '${state.sourceLanguage.name.split(' ')[0]} → ${state.targetLanguage.name}';

    return AnimatedBuilder(
      animation: _popController,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        );
      },
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 228,
          maxWidth: 250,
        ),
        width: 232, // Exact prototype width: 232px
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), // Exact prototype padding
        decoration: BoxDecoration(
          color: state.activePet.accentColor, // background: var(--acc)
          borderRadius: BorderRadius.circular(22), // border-radius: 22px
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000), // box-shadow: 0 18px 40px #0005
              blurRadius: 40,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // .ch: Header row with pet name, language pair, and close button
            Row(
              children: [
                Text(
                  state.activePet.name,
                  style: GoogleFonts.fredoka(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    langPair,
                    style: GoogleFonts.fredoka(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xD9FFFFFF), // opacity: .85
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // #x: 30x30 circle close button with #fff3 background
                InkWell(
                  onTap: () {
                    widget.onClose?.call();
                    notifier.closeCard();
                  },
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: Color(0x33FFFFFF), // #fff3
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '×',
                        style: GoogleFonts.fredoka(
                          fontSize: 18,
                          height: 1.0,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // #said: Spoken source transcript (with tap-to-edit)
            if (state.spokenText.isNotEmpty) ...[
              const SizedBox(height: 8),
              if (state.isEditingTranscript) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _editTranscriptController..text = state.spokenText,
                          style: GoogleFonts.fredoka(fontSize: 13, color: Colors.white),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSubmitted: (val) {
                            notifier.setEditingTranscript(false);
                            notifier.stopListeningAndProcess(val.trim());
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check, size: 16, color: Colors.white),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          final val = _editTranscriptController.text.trim();
                          notifier.setEditingTranscript(false);
                          if (val.isNotEmpty) {
                            notifier.stopListeningAndProcess(val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ] else ...[
                GestureDetector(
                  onTap: () {
                    _editTranscriptController.text = state.spokenText;
                    notifier.setEditingTranscript(true);
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          state.spokenText,
                          style: GoogleFonts.fredoka(
                            fontSize: 14,
                            color: const Color(0xD9FFFFFF), // opacity: .85
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit, size: 12, color: Color(0x88FFFFFF)),
                    ],
                  ),
                ),
              ],
            ],

            // #lyr: Karaoke lyrics view
            const SizedBox(height: 4),
            KaraokeLyricsView(words: state.words),

            // AI correction / tip
            if (state.correction != null && state.correction!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x33000000),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '💡 ${state.correction!}',
                  style: GoogleFonts.fredoka(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],

            // #nt: Note / evaluation status
            if (state.statusNote.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                state.statusNote,
                style: GoogleFonts.fredoka(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],

            const SizedBox(height: 8),

            // .row: Control strip with Play, Slow, Repeat, and pulsing Mic
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // #play: circle #fff3 button
                  InkWell(
                    onTap: () => notifier.playKaraoke(1.0),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Color(0x33FFFFFF), // #fff3
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.play_arrow, color: Colors.white, size: 19),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // #slow: pill button
                  InkWell(
                    onTap: () => notifier.playKaraoke(0.75),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0x33FFFFFF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Center(
                        child: Text(
                          'Slow',
                          style: GoogleFonts.fredoka(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // #rep: pill button
                  InkWell(
                    onTap: () {
                      if (state.isListening && state.isRepeatPracticing) {
                        notifier.stopRepeatPractice();
                      } else {
                        notifier.startRepeatPractice();
                      }
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: state.isRepeatPracticing
                            ? Colors.white
                            : const Color(0x33FFFFFF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Center(
                        child: Text(
                          state.isRepeatPracticing ? 'Done' : 'Repeat',
                          style: GoogleFonts.fredoka(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: state.isRepeatPracticing
                                ? state.activePet.accentColor
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // #mic: circle with white background, accent icon, pulsing when active
                  _PulsingMicButton(
                    isListening: state.isListening,
                    accentColor: state.activePet.accentColor,
                    onTap: () {
                      if (state.isListening) {
                        if (state.isRepeatPracticing) {
                          notifier.stopRepeatPractice();
                        } else {
                          notifier.stopListeningAndProcess();
                        }
                      } else {
                        notifier.startListening();
                      }
                    },
                  ),
                ],
              ),
            ),

            // #tf & #ti: 36px height input field with #0003 background
            const SizedBox(height: 10),
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0x33000000), // #0003
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: GoogleFonts.fredoka(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Or type a sentence',
                        hintStyle: GoogleFonts.fredoka(
                          fontSize: 14,
                          color: const Color(0xBBFFFFFF), // #ffffffbb
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          notifier.submitTypedText(val.trim());
                          _textController.clear();
                        }
                      },
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      final val = _textController.text.trim();
                      if (val.isNotEmpty) {
                        notifier.submitTypedText(val);
                        _textController.clear();
                      }
                    },
                    child: const Icon(Icons.arrow_upward, size: 18, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pulsing microphone button matching `#mic.on` in prototype
class _PulsingMicButton extends StatefulWidget {
  final bool isListening;
  final Color accentColor;
  final VoidCallback onTap;

  const _PulsingMicButton({
    required this.isListening,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_PulsingMicButton> createState() => _PulsingMicButtonState();
}

class _PulsingMicButtonState extends State<_PulsingMicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.isListening) _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PulsingMicButton oldWidget) {
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
      animation: _pulseController,
      builder: (context, child) {
        final shadowSpread = widget.isListening ? _pulseController.value * 9.0 : 0.0;
        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                if (widget.isListening)
                  BoxShadow(
                    color: const Color(0x44FFFFFF), // #fff4 pulse
                    spreadRadius: shadowSpread,
                    blurRadius: 4,
                  ),
              ],
            ),
            child: Center(
              child: Icon(
                widget.isListening ? Icons.mic : Icons.mic_none,
                color: widget.accentColor,
                size: 24,
              ),
            ),
          ),
        );
      },
    );
  }
}

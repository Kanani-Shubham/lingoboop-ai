import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

enum WordEvaluationState { none, ok, miss }

class KaraokeWord {
  final String text;
  final bool isHighlighted;
  final WordEvaluationState evaluation;

  const KaraokeWord({
    required this.text,
    this.isHighlighted = false,
    this.evaluation = WordEvaluationState.none,
  });

  KaraokeWord copyWith({bool? isHighlighted, WordEvaluationState? evaluation}) {
    return KaraokeWord(
      text: text,
      isHighlighted: isHighlighted ?? this.isHighlighted,
      evaluation: evaluation ?? this.evaluation,
    );
  }
}

class KaraokeLyricsView extends StatelessWidget {
  final List<KaraokeWord> words;

  const KaraokeLyricsView({super.key, required this.words});

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) {
      return SizedBox(
        height: 62, // min-height: 62px
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Tap mic and speak…',
            style: GoogleFonts.fredoka(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.wordKaraokeDim,
            ),
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 62),
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: words.map((w) {
          final isLit = w.isHighlighted;
          final isOk = w.evaluation == WordEvaluationState.ok;
          final isMiss = w.evaluation == WordEvaluationState.miss;

          BoxDecoration? decoration;
          if (isOk) {
            decoration = BoxDecoration(
              color: AppColors.practiceMatchOk,
              borderRadius: BorderRadius.circular(6),
            );
          }

          final style = GoogleFonts.fredoka(
            fontSize: 25, // Exact prototype font-size: 25px
            fontWeight: FontWeight.w600,
            height: 1.22, // Exact prototype line-height: 1.22
            color: isLit ? AppColors.wordKaraokeLit : AppColors.wordKaraokeDim,
            decoration: isMiss ? TextDecoration.underline : TextDecoration.none,
            decorationColor: isMiss ? AppColors.practiceMissUnderline : null,
            decorationStyle: isMiss ? TextDecorationStyle.wavy : null,
          );

          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: isOk
                ? const EdgeInsets.symmetric(horizontal: 5, vertical: 2)
                : EdgeInsets.zero,
            decoration: decoration,
            child: Text(w.text, style: style),
          );
        }).toList(),
      ),
    );
  }
}

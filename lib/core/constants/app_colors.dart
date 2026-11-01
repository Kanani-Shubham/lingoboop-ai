import 'package:flutter/material.dart';

/// Exact color palette defined in `polypet-demo.html`
class AppColors {
  AppColors._();

  // Primary backgrounds & surfaces
  static const Color outerStage = Color(0xFF13201E);
  static const Color phoneBackground = Color(0xFFEAF0EC);
  static const Color cardSurface = Color(0xFFFFFFFF);

  // Typography & Content
  static const Color textDark = Color(0xFF1D2B29);
  static const Color textMuted = Color(0xFF62746F);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color captionText = Color(0xFF9DB5AE);

  // Borders & Accents
  static const Color border = Color(0xFFC5D3CD);
  static const Color borderSoft = Color(0xFFD5E0DB);
  static const Color inputBackground = Color(0x33000000); // #0003

  // Karaoke & Evaluation States
  static const Color wordKaraokeDim = Color(0x6BFFFFFF); // opacity .42
  static const Color wordKaraokeLit = Color(0xFFFFFFFF);
  static const Color practiceMatchOk = Color(0x33FFFFFF); // #fff3
  static const Color practiceMissUnderline = Color(0xFFFFD9C9);

  // Character-specific Accent Colors (--acc)
  static const Color foxMaru = Color(0xFFC4571C);
  static const Color catMimi = Color(0xFF6A4CC4);
  static const Color pandaPano = Color(0xFF2C6E5E);
  static const Color bunnyBun = Color(0xFFC23D7B);
  static const Color penguinPip = Color(0xFF2C62C4);
  static const Color lionLeo = Color(0xFF9A6A06);
}


import 'package:flutter/material.dart';
import '../../pet_overlay/poly_card_widget.dart';

/// Backward-compatible wrapper exposing the exact prototype PolyCardWidget
class LingoCardWidget extends StatelessWidget {
  const LingoCardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const PolyCardWidget();
  }
}

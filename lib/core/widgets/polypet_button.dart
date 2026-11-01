import 'package:flutter/material.dart';

class PolyPetButton extends StatelessWidget {
  final String? label;
  final Widget? icon;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final double height;
  final EdgeInsetsGeometry padding;

  const PolyPetButton({
    super.key,
    this.label,
    this.icon,
    this.onPressed,
    this.backgroundColor = const Color(0x33FFFFFF), // #fff3
    this.foregroundColor = Colors.white,
    this.height = 40.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 14),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Container(
          height: height,
          padding: padding,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?icon,
              if (icon != null && label != null) const SizedBox(width: 6),
              if (label != null)
                Text(
                  label!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: foregroundColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

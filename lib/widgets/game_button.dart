import 'package:flutter/material.dart';
import 'stealth_components.dart';

class GameButton extends StatelessWidget {
  const GameButton(
      {super.key, required this.label, required this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: StealthButton(
          label: label,
          icon: icon ?? Icons.play_arrow_rounded,
          onPressed: onPressed,
        ),
      );
}

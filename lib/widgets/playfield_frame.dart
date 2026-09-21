import 'dart:math';

import 'package:flutter/widgets.dart';

import '../config/game_balance.dart';

/// Keeps every gameplay layer in one height-driven coordinate space.
class PlayfieldFrame extends StatelessWidget {
  const PlayfieldFrame({
    super.key,
    required this.child,
    this.aspectRatio = GameBalance.playfieldAspectRatio,
  });

  final Widget child;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width =
              min(constraints.maxWidth, constraints.maxHeight * aspectRatio);
          final height = min(constraints.maxHeight, width / aspectRatio);
          return Center(
            child: SizedBox(width: width, height: height, child: child),
          );
        },
      );
}

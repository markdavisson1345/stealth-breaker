import 'package:flutter/material.dart';
import '../theme/stealth_theme.dart';
import 'game_icons.dart';

enum StealthButtonStyle { primary, secondary, subdued, danger }

class StealthButton extends StatefulWidget {
  const StealthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.gameIcon,
    this.style = StealthButtonStyle.primary,
    this.expanded = true,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final GameIconType? gameIcon;
  final StealthButtonStyle style;
  final bool expanded;

  @override
  State<StealthButton> createState() => _StealthButtonState();
}

class _StealthButtonState extends State<StealthButton> {
  bool pressed = false;

  Color get accent => switch (widget.style) {
        StealthButtonStyle.primary => StealthColors.cyan,
        StealthButtonStyle.danger => StealthColors.red,
        StealthButtonStyle.secondary => StealthColors.border,
        StealthButtonStyle.subdued => Colors.transparent,
      };

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final content = AnimatedScale(
      scale: pressed ? .975 : 1,
      duration: StealthMotion.quick,
      child: AnimatedContainer(
        duration: StealthMotion.quick,
        constraints: const BoxConstraints(minHeight: 52),
        decoration: BoxDecoration(
          color: widget.style == StealthButtonStyle.primary
              ? StealthColors.surfaceRaised
              : StealthColors.surface,
          borderRadius: BorderRadius.circular(StealthRadii.medium),
          border: Border.all(
              color: enabled ? accent : StealthColors.disabled,
              width: widget.style == StealthButtonStyle.primary ? 1.6 : 1),
          boxShadow: enabled && widget.style == StealthButtonStyle.primary
              ? [
                  BoxShadow(
                      color: StealthColors.cyan
                          .withValues(alpha: pressed ? .23 : .12),
                      blurRadius: pressed ? 14 : 9)
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            onTapDown: enabled ? (_) => setState(() => pressed = true) : null,
            onTapCancel: enabled ? () => setState(() => pressed = false) : null,
            onTapUp: enabled ? (_) => setState(() => pressed = false) : null,
            borderRadius: BorderRadius.circular(StealthRadii.medium),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.gameIcon != null)
                      GameIcon(widget.gameIcon!,
                          size: 23,
                          color: enabled
                              ? (widget.style == StealthButtonStyle.danger
                                  ? StealthColors.red
                                  : StealthColors.cyan)
                              : StealthColors.disabled)
                    else if (widget.icon != null)
                      Icon(widget.icon,
                          size: 22,
                          color: enabled
                              ? (widget.style == StealthButtonStyle.danger
                                  ? StealthColors.red
                                  : StealthColors.cyan)
                              : StealthColors.disabled),
                    if (widget.icon != null || widget.gameIcon != null)
                      const SizedBox(width: 10),
                    Flexible(
                        child: Text(widget.label.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: StealthTextStyles.title.copyWith(
                                fontSize: 15,
                                letterSpacing: 1.5,
                                color: enabled
                                    ? StealthColors.textPrimary
                                    : StealthColors.disabled))),
                  ]),
            ),
          ),
        ),
      ),
    );
    return widget.expanded
        ? SizedBox(width: double.infinity, child: content)
        : content;
  }
}

class StealthCard extends StatelessWidget {
  const StealthCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16),
      this.accent,
      this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final Color? accent;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: StealthColors.surface.withValues(alpha: .96),
          borderRadius: BorderRadius.circular(StealthRadii.medium),
          border: Border.all(
              color: accent?.withValues(alpha: .7) ?? StealthColors.border),
        ),
        child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(StealthRadii.medium),
              child: Padding(padding: padding, child: child),
            )),
      );
}

class StealthScreenBackground extends StatelessWidget {
  const StealthScreenBackground(
      {super.key, required this.child, this.safeArea = true});
  final Widget child;
  final bool safeArea;
  @override
  Widget build(BuildContext context) {
    final body = Stack(children: [
      const Positioned.fill(child: ColoredBox(color: StealthColors.background)),
      const Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _GridPainter()))),
      Positioned.fill(child: child),
    ]);
    return safeArea ? SafeArea(child: body) : body;
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = StealthColors.cyan.withValues(alpha: .025)
      ..strokeWidth = 1;
    const gap = 34.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StealthHeader extends StatelessWidget {
  const StealthHeader(
      {super.key,
      required this.title,
      this.subtitle,
      this.trailing,
      this.showBack = true});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showBack;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
        child: Row(children: [
          if (showBack)
            IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back'),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title.toUpperCase(),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(letterSpacing: 1.6)),
                if (subtitle != null)
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ])),
          if (trailing != null) trailing!,
        ]),
      );
}

class StealthSectionHeader extends StatelessWidget {
  const StealthSectionHeader(this.label, {super.key, this.trailing});
  final String label;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Text(label.toUpperCase(),
              style: StealthTextStyles.label
                  .copyWith(color: StealthColors.cyanSoft)),
          const Spacer(),
          if (trailing != null) trailing!,
        ]),
      );
}

class StealthStatTile extends StatelessWidget {
  const StealthStatTile(
      {super.key,
      required this.label,
      required this.value,
      required this.icon,
      this.accent = StealthColors.cyan});
  final String label;
  final String value;
  final GameIconType icon;
  final Color accent;
  @override
  Widget build(BuildContext context) => StealthCard(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          GameIcon(icon, color: accent, size: 27),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(value,
                    style: StealthTextStyles.title.copyWith(fontSize: 17)),
                Text(label.toUpperCase(),
                    style: StealthTextStyles.label.copyWith(fontSize: 10)),
              ])),
        ]),
      );
}

class StealthProgressBar extends StatelessWidget {
  const StealthProgressBar(
      {super.key, required this.value, this.color = StealthColors.cyan});
  final double value;
  final Color color;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0, 1)),
          duration: StealthMotion.reveal,
          builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 7,
              color: color,
              backgroundColor: StealthColors.surfaceRaised),
        ),
      );
}

class AchievementBadge extends StatelessWidget {
  const AchievementBadge(
      {super.key,
      required this.state,
      this.color = StealthColors.cyan,
      this.size = 50});
  final GameIconType state;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: .65))),
        alignment: Alignment.center,
        child: GameIcon(state, size: size * .58, color: color),
      );
}

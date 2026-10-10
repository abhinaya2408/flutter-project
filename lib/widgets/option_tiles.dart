import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';

/// `.option-card` — a flavour card: image (`aspect-ratio: 4/3`), title,
/// description and "From ₹…" price, with the coral check badge when selected.
class FlavorOptionCard extends StatefulWidget {
  const FlavorOptionCard({
    required this.title,
    required this.description,
    required this.price,
    required this.image,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String title;
  final String description;
  final int price;
  final Widget image;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<FlavorOptionCard> createState() => _FlavorOptionCardState();
}

class _FlavorOptionCardState extends State<FlavorOptionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: AppRadius.md,
            border: Border.all(
              color: widget.selected ? AppColors.coral : AppColors.border,
              width: AppBorders.regular,
            ),
            boxShadow: widget.selected
                ? const <BoxShadow>[
                    BoxShadow(color: AppColors.coralLight, spreadRadius: 3),
                  ]
                : (_hovered ? AppShadows.sm : null),
          ),
          child: ClipRRect(
            borderRadius: AppRadius.md,
            child: Stack(
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AspectRatio(
                      aspectRatio: AppLayout.cakeImageAspect,
                      child: widget.image,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.sp3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(widget.title, style: AppText.optionCardTitle),
                          const SizedBox(height: 4),
                          Text(
                            widget.description,
                            style: AppText.meta,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'From ₹${widget.price}',
                            style: AppText.inter(
                              size: 13.5,
                              weight: FontWeight.w700,
                              color: AppColors.coralDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (widget.selected)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.coral,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '✓',
                        style: AppText.inter(
                          size: 13,
                          weight: FontWeight.w700,
                          color: AppColors.white,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `.pill-option` — the size / cream / cake-type tiles.
class PillOption extends StatefulWidget {
  const PillOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.sub,
    super.key,
  });

  final String icon;
  final String label;
  final String? sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<PillOption> createState() => _PillOptionState();
}

class _PillOptionState extends State<PillOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sp3,
            vertical: AppSpacing.sp4,
          ),
          decoration: BoxDecoration(
            color: widget.selected ? AppColors.coralLight : AppColors.white,
            borderRadius: AppRadius.md,
            border: Border.all(
              color: widget.selected ? AppColors.coral : AppColors.border,
              width: AppBorders.regular,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(widget.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 6),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: AppText.inter(
                  size: 14.5,
                  weight: FontWeight.w700,
                  color: AppColors.charcoal,
                  height: 1.3,
                ),
              ),
              if (widget.sub != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  widget.sub!,
                  textAlign: TextAlign.center,
                  style: AppText.inter(
                    size: 12,
                    color: AppColors.textMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// `.deco-option` — the decoration tile with icon, label and `+₹` price.
class DecorationOption extends StatelessWidget {
  const DecorationOption({
    required this.icon,
    required this.label,
    required this.price,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String icon;
  final String label;
  final int price;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(AppSpacing.sp3),
          decoration: BoxDecoration(
            color: selected ? AppColors.coralLight : AppColors.white,
            borderRadius: AppRadius.md,
            border: Border.all(
              color: selected ? AppColors.coral : AppColors.border,
              width: AppBorders.regular,
            ),
          ),
          child: Row(
            children: <Widget>[
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: AppSpacing.sp2),
              Expanded(
                child: Text(
                  label,
                  style: AppText.inter(
                    size: 13.5,
                    weight: FontWeight.w600,
                    color: AppColors.text,
                    height: 1.35,
                  ),
                ),
              ),
              Text(
                '+₹$price',
                style: AppText.inter(
                  size: 12,
                  color: AppColors.textMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

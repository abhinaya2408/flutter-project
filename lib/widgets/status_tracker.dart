import 'package:flutter/material.dart';

import '../data/order_status.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';

/// `renderTracker()` in `college-bakery/js/orders.js` — the horizontal
/// five-step status tracker, plus the two-step rejected variant.
///
/// Rendering rules reproduced exactly:
/// * the dot is coral when the step is done or current, otherwise the border
///   colour with the step number;
/// * the current dot gets the `0 0 0 4px var(--color-coral-light)` ring;
/// * the connecting line is drawn by each step (`left: -50%; width: 100%`) and
///   is coral only for a step carrying the `done` class;
/// * labels are charcoal for done/current steps and muted otherwise.
class StatusTracker extends StatelessWidget {
  const StatusTracker({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sp5),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Order Status', style: AppText.detailCardTitle),
          const SizedBox(height: AppSpacing.sp3),
          if (status == OrderStatus.rejected)
            _buildSteps(
              labels: const <String>['Order Placed', 'Rejected'],
              icons: const <String>['✓', '✕'],
              backgrounds: const <Color>[AppColors.coral, AppColors.danger],
              currentIndex: -1,
              doneIndex: 1,
              afterStep: Text(
                'Unfortunately this order was not accepted. Please contact the bakery for details.',
                textAlign: TextAlign.center,
                style: AppText.meta.copyWith(fontSize: 13.5),
              ),
            )
          else
            _buildSteps(
              labels: OrderStatus.trackerLabels,
              icons: _stepIcons(),
              backgrounds: _stepBackgrounds(),
              currentIndex: _currentIndex,
              doneIndex: _currentIndex,
            ),
        ],
      ),
    );
  }

  /// `"COLLECTED"` is treated as `COMPLETED`; an unknown status yields `-1`
  /// (the CSS then leaves every step in its default state).
  int get _currentIndex {
    final String normalised =
        status == 'COLLECTED' ? OrderStatus.completed : status;
    return OrderStatus.steps.indexOf(normalised);
  }

  List<String> _stepIcons() => <String>[
        for (int i = 0; i < OrderStatus.trackerLabels.length; i++)
          i <= _currentIndex ? '✓' : '${i + 1}',
      ];

  List<Color> _stepBackgrounds() => <Color>[
        for (int i = 0; i < OrderStatus.trackerLabels.length; i++)
          i <= _currentIndex ? AppColors.coral : AppColors.border,
      ];

  Widget _buildSteps({
    required List<String> labels,
    required List<String> icons,
    required List<Color> backgrounds,
    required int currentIndex,
    required int doneIndex,
    Widget? afterStep,
  }) {
    return Column(
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double stepWidth = constraints.maxWidth / labels.length;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (int i = 0; i < labels.length; i++)
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        SizedBox(
                          height: 32,
                          width: double.infinity,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: <Widget>[
                              if (i > 0)
                                Positioned(
                                  left: -stepWidth / 2,
                                  top: 14.5,
                                  width: stepWidth,
                                  height: 3,
                                  child: Container(
                                    color: i < doneIndex
                                        ? AppColors.coral
                                        : AppColors.border,
                                  ),
                                ),
                              Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: backgrounds[i],
                                  shape: BoxShape.circle,
                                  boxShadow: i == currentIndex
                                      ? const <BoxShadow>[
                                          BoxShadow(
                                            color: AppColors.coralLight,
                                            spreadRadius: 4,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  icons[i],
                                  style: AppText.inter(
                                    size: 14,
                                    weight: FontWeight.w700,
                                    color: AppColors.white,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sp2),
                        Text(
                          labels[i],
                          textAlign: TextAlign.center,
                          style: AppText.inter(
                            size: 12,
                            weight: FontWeight.w600,
                            color: i <= doneIndex && doneIndex >= 0
                                ? AppColors.charcoal
                                : AppColors.textMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        if (afterStep != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sp1),
          afterStep,
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatters.dart';
import 'cake_image.dart';
import 'status_pill.dart';

/// `.order-card` — the row used by "My Orders".
class OrderCard extends StatefulWidget {
  const OrderCard({required this.order, required this.onTap, super.key});

  final Order order;
  final VoidCallback onTap;

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Order order = widget.order;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.translationValues(0, _hovered ? -1 : 0, 0),
          padding: const EdgeInsets.all(AppSpacing.sp4),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: AppRadius.md,
            border: Border.all(color: AppColors.border),
            boxShadow: _hovered ? AppShadows.sm : null,
          ),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact = constraints.maxWidth < 520;
              final Widget thumb = ClipRRect(
                borderRadius: AppRadius.sm,
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: CakeImage(
                    imageUrl: order.referenceImage,
                    flavor: order.flavor,
                  ),
                ),
              );

              final Widget info = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Order #${order.orderId}',
                    style: AppText.metaStrong,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${order.flavor} Cake · ${order.size}',
                    style: AppText.poppins(size: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Required: ${Formatters.formatDate(order.requiredDate)} · '
                    '${Formatters.formatTime(order.requiredTime)}',
                    style: AppText.meta,
                  ),
                ],
              );

              final Widget side = Column(
                crossAxisAlignment: compact
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: <Widget>[
                  StatusPill(status: order.status),
                  const SizedBox(height: AppSpacing.sp2),
                  Text(
                    '₹${order.estimatedPrice}',
                    style: AppText.inter(
                      size: 14,
                      weight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        thumb,
                        const SizedBox(width: AppSpacing.sp3),
                        Expanded(child: info),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sp3),
                    Row(
                      children: <Widget>[
                        StatusPill(status: order.status),
                        const Spacer(),
                        Text(
                          '₹${order.estimatedPrice}',
                          style: AppText.inter(
                            size: 14,
                            weight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  thumb,
                  const SizedBox(width: AppSpacing.sp3),
                  Expanded(child: info),
                  const SizedBox(width: AppSpacing.sp3),
                  side,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

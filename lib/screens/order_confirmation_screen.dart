import 'package:flutter/material.dart';

import '../data/catalog.dart';
import '../models/order.dart';
import '../services/order_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatters.dart';
import '../widgets/app_button.dart';
import '../widgets/cake_image.dart';
import '../widgets/detail_row.dart';
import '../widgets/empty_state.dart';
import '../widgets/page_container.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/status_pill.dart';

/// `order-confirmation.html` — `initOrderConfirmationPage()` in `js/orders.js`.
class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return StudentPageScaffold(
      body: SingleChildScrollView(
        child: PageContainer(
          maxWidth: 640,
          top: AppSpacing.sp7,
          bottom: AppSpacing.sp8,
          child: StreamBuilder<Order?>(
            stream: OrderService().watchOrder(orderId),
            builder: (BuildContext context, AsyncSnapshot<Order?> snapshot) {
              final Order? order = snapshot.data;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Column(
                    children: <Widget>[
                      Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        margin: const EdgeInsets.only(
                          bottom: AppSpacing.sp3,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '✓',
                          style: AppText.inter(
                            size: 32,
                            weight: FontWeight.w700,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                      Text(
                        'Your cake order is confirmed!',
                        textAlign: TextAlign.center,
                        // `h1` scales to 32px below the 900px breakpoint.
                        style: MediaQuery.sizeOf(context).width <= 900
                            ? AppText.h1Mobile
                            : AppText.h1,
                      ),
                      const SizedBox(height: AppSpacing.sp2),
                      Text(
                        'Your request has been sent to the bakery.',
                        textAlign: TextAlign.center,
                        style: AppText.paragraph,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sp5),
                  if (order == null)
                    EmptyState(
                      emoji: '🎂',
                      title: 'Order not found',
                      message:
                          "We couldn't find that order. It may have been removed.",
                      actionLabel: 'Customize a Cake',
                      onAction: () =>
                          Navigator.of(context).pushNamed('/customize'),
                    )
                  else
                    _ConfirmationCard(order: order),
                  if (order != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.sp5),
                    Center(
                      child: AppButton(
                        label: 'Track My Order',
                        onPressed: () => Navigator.of(context).pushNamed(
                          '/order-details',
                          arguments: order.orderId,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ConfirmationCard extends StatelessWidget {
  const _ConfirmationCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sp5),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ClipRRect(
            borderRadius: AppRadius.md,
            child: AspectRatio(
              aspectRatio: AppLayout.cakeImageAspect,
              child: CakeImage(
                imageUrl: order.referenceImage,
                flavor: order.flavor,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sp4),
          DetailRow(label: 'Order ID', value: order.orderId),
          DetailRow(label: 'Cake', value: '${order.flavor} · ${order.size}'),
          DetailRow(label: 'Cake Type', value: order.cakeType),
          DetailRow(label: 'Cream', value: order.cream),
          DetailRow(
            label: 'Decorations',
            value: order.decorations.isEmpty
                ? 'None'
                : order.decorations.join(', '),
          ),
          DetailRow(
            label: 'Pickup Date',
            value: Formatters.formatDate(order.requiredDate),
          ),
          DetailRow(
            label: 'Pickup Time',
            value: Formatters.formatTime(order.requiredTime),
          ),
          DetailRow(
            label: 'Estimated Price',
            value: '₹${order.estimatedPrice}',
          ),
          DetailRow(
            label: 'Status',
            isLast: true,
            valueWidget: StatusPill(status: order.status),
          ),
        ],
      ),
    );
  }
}

/// Kept for parity with the original flavour image helper.
String confirmationFlavorImage(String flavor) => flavorImage(flavor);

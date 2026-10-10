import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../models/student_profile.dart';
import '../services/order_service.dart';
import '../state/session_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatters.dart';
import '../widgets/cake_image.dart';
import '../widgets/detail_row.dart';
import '../widgets/empty_state.dart';
import '../widgets/page_container.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/status_tracker.dart';

/// `order-details.html` — `initOrderDetailsPage()` in `js/orders.js`.
class OrderDetailsScreen extends StatelessWidget {
  const OrderDetailsScreen({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    final StudentProfile? student = context.watch<SessionController>().student;

    return StudentPageScaffold(
      body: SingleChildScrollView(
        child: PageContainer(
          top: AppSpacing.sp6,
          bottom: AppSpacing.sp8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              InkWell(
                onTap: () => Navigator.of(context)
                    .pushReplacementNamed('/my-orders'),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sp4),
                  child: Text(
                    '← Back to My Orders',
                    style: AppText.inter(
                      size: 13.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
              if (student == null)
                const SizedBox.shrink()
              else
                StreamBuilder<Order?>(
                  stream: OrderService().watchOrder(orderId),
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<Order?> snapshot,
                  ) {
                    final Order? order = snapshot.data;

                    // `!order || order.studentId !== student.studentId`
                    if (order == null || order.studentId != student.studentId) {
                      return EmptyState(
                        emoji: '🎂',
                        title: 'Order not found',
                        message:
                            "Invalid order ID or this order doesn't belong to your account.",
                        actionLabel: 'Back to My Orders',
                        onAction: () => Navigator.of(context)
                            .pushReplacementNamed('/my-orders'),
                      );
                    }

                    return _OrderDetailsBody(order: order);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderDetailsBody extends StatelessWidget {
  const _OrderDetailsBody({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.sp3,
            bottom: AppSpacing.sp4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Order #${order.orderId}', style: AppText.dashboardHeader),
              const SizedBox(height: 2),
              Text(
                'Placed on ${Formatters.formatIsoDate(order.createdAt)}',
                style: AppText.paragraph,
              ),
            ],
          ),
        ),
        StatusTracker(status: order.status),
        const SizedBox(height: AppSpacing.sp5),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool stacked = constraints.maxWidth <= 900;
            final Widget left = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _CakeDetailsCard(order: order),
                if (order.cakeMessage.isNotEmpty)
                  _SimpleCard(
                    title: 'Cake Message',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sp3),
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius: AppRadius.sm,
                      ),
                      child: Text(
                        '"${order.cakeMessage}"',
                        style: AppText.inter(
                          size: 14,
                          color: AppColors.text,
                          height: 1.45,
                        ).copyWith(fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),
                if (order.specialInstructions.isNotEmpty)
                  _SimpleCard(
                    title: 'Special Instructions',
                    child: Text(
                      order.specialInstructions,
                      style: AppText.paragraph,
                    ),
                  ),
              ],
            );

            final Widget right = _SimpleCard(
              title: 'Reference Image',
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
                  if (order.referenceImage.isEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.sp2),
                    Text(
                      'No reference photo uploaded — showing a sample '
                      '${order.flavor.toLowerCase()} cake image.',
                      style: AppText.meta,
                    ),
                  ],
                ],
              ),
            );

            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  left,
                  right,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: left),
                const SizedBox(width: AppSpacing.sp6),
                Expanded(child: right),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CakeDetailsCard extends StatelessWidget {
  const _CakeDetailsCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return _SimpleCard(
      title: 'Cake Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DetailRow(label: 'Flavor', value: order.flavor),
          DetailRow(label: 'Cake Type', value: order.cakeType),
          DetailRow(label: 'Size', value: order.size),
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
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _SimpleCard extends StatelessWidget {
  const _SimpleCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sp4),
      padding: const EdgeInsets.all(AppSpacing.sp5),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title, style: AppText.detailCardTitle),
          const SizedBox(height: AppSpacing.sp3),
          child,
        ],
      ),
    );
  }
}

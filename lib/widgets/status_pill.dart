import 'package:flutter/material.dart';

import '../data/order_status.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatters.dart';

/// `.pill` + `.pill-<status>` + `.dot` — the status chip used on order cards,
/// detail rows and the owner table.
class StatusPill extends StatelessWidget {
  const StatusPill({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final Color background = OrderStatus.pillBackground(status);
    final Color foreground = OrderStatus.pillForeground(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: foreground,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            Formatters.statusLabel(status),
            style: AppText.pill.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

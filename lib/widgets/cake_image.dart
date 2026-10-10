import 'package:flutter/material.dart';

import '../data/catalog.dart';
import '../theme/app_colors.dart';

/// Cake imagery.
///
/// Every screen in the original renders `order.referenceImage ||
/// getFlavorImage(order.flavor)`; this widget applies the same fallback: an
/// uploaded reference photo when there is one, otherwise the sample photo for
/// the chosen flavour.
class CakeImage extends StatelessWidget {
  const CakeImage({
    required this.imageUrl,
    this.flavor,
    this.fit = BoxFit.cover,
    super.key,
  });

  /// `order.referenceImage` (a Storage download URL, or empty).
  final String? imageUrl;

  /// `order.flavor` — used when [imageUrl] is empty.
  final String? flavor;

  final BoxFit fit;

  String get resolvedUrl {
    if (imageUrl != null && imageUrl!.isNotEmpty) return imageUrl!;
    if (flavor != null && flavor!.isNotEmpty) return flavorImage(flavor!);
    return CakeImages.hero;
  }

  @override
  Widget build(BuildContext context) {
    return Image.network(
      resolvedUrl,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (
        BuildContext context,
        Widget child,
        ImageChunkEvent? progress,
      ) {
        if (progress == null) return child;
        return Container(color: AppColors.coralLight);
      },
      errorBuilder: (
        BuildContext context,
        Object error,
        StackTrace? stackTrace,
      ) =>
          Container(
        color: AppColors.coralLight,
        alignment: Alignment.center,
        child: const Text('🎂', style: TextStyle(fontSize: 32)),
      ),
    );
  }
}

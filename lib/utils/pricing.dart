import '../data/catalog.dart';

/// The result of `calculatePrice()` in `college-bakery/js/app.js`.
class PriceBreakdown {
  const PriceBreakdown({
    required this.basePrice,
    required this.decorPrice,
    required this.total,
  });

  final int basePrice;
  final int decorPrice;
  final int total;
}

/// Pricing — identical maths to `calculatePrice()` in `js/app.js`:
///
/// ```text
/// basePrice  = SIZE_PRICES[size] + flavorSurcharge(flavor)
/// decorPrice = Σ DECORATION_PRICES[decoration]
/// total      = basePrice + decorPrice
/// ```
PriceBreakdown calculatePrice({
  String? flavor,
  String? size,
  List<String> decorations = const <String>[],
}) {
  final int basePrice = (kSizePrices[size] ?? 0) + flavorSurcharge(flavor);
  final int decorPrice = decorations.fold<int>(
    0,
    (int sum, String decoration) => sum + (kDecorationPrices[decoration] ?? 0),
  );
  return PriceBreakdown(
    basePrice: basePrice,
    decorPrice: decorPrice,
    total: basePrice + decorPrice,
  );
}

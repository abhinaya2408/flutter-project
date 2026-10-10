import 'package:college_bakery_flutter/data/catalog.dart';
import 'package:college_bakery_flutter/utils/pricing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calculatePrice — matches calculatePrice() in js/app.js', () {
    test('size price only', () {
      final PriceBreakdown price = calculatePrice(
        flavor: 'Chocolate',
        size: '1 Kg',
      );
      expect(price.basePrice, 550);
      expect(price.decorPrice, 0);
      expect(price.total, 550);
    });

    test('adds the flavour surcharge and decoration prices', () {
      final PriceBreakdown price = calculatePrice(
        flavor: 'Red Velvet',
        size: '1.5 Kg',
        decorations: <String>['Fresh Flowers'],
      );
      expect(price.basePrice, 800); // 750 + 50
      expect(price.decorPrice, 50);
      expect(price.total, 850);
    });

    test('unknown flavour and size fall back to zero', () {
      final PriceBreakdown price = calculatePrice(
        flavor: 'Unknown',
        size: 'nope',
        decorations: <String>['Nope'],
      );
      expect(price.total, 0);
    });

    test('empty selection is zero', () {
      expect(calculatePrice().total, 0);
    });

    test('seeded order CK1001 (Chocolate · 1 Kg · Sprinkles + Birthday Theme)',
        () {
      final PriceBreakdown price = calculatePrice(
        flavor: 'Chocolate',
        size: '1 Kg',
        decorations: <String>['Sprinkles', 'Birthday Theme'],
      );
      expect(price.total, 550 + 30 + 100);
    });

    test('seeded order CK1002 (Red Velvet · 1.5 Kg · Fresh Flowers)', () {
      expect(
        calculatePrice(
          flavor: 'Red Velvet',
          size: '1.5 Kg',
          decorations: <String>['Fresh Flowers'],
        ).total,
        850,
      );
    });

    test('seeded order CK1003 (Butterscotch · 500g · none)', () {
      expect(
        calculatePrice(flavor: 'Butterscotch', size: '500g').total,
        340,
      );
    });

    test('seeded order CK1004 (Black Forest · 2 Kg · choc + fruits)', () {
      expect(
        calculatePrice(
          flavor: 'Black Forest',
          size: '2 Kg',
          decorations: <String>['Chocolate Decorations', 'Fruits'],
        ).total,
        1240,
      );
    });

    test('seeded order CK1005 (Strawberry · 1 Kg · flowers + sprinkles)', () {
      expect(
        calculatePrice(
          flavor: 'Strawberry',
          size: '1 Kg',
          decorations: <String>['Fresh Flowers', 'Sprinkles'],
        ).total,
        680,
      );
    });
  });

  group('catalog constants', () {
    test('size prices', () {
      expect(kSizePrices, <String, int>{
        '500g': 300,
        '1 Kg': 550,
        '1.5 Kg': 750,
        '2 Kg': 1000,
      });
    });

    test('decoration prices', () {
      expect(kDecorationPrices['Fresh Flowers'], 50);
      expect(kDecorationPrices['Chocolate Decorations'], 100);
      expect(kDecorationPrices['Sprinkles'], 30);
      expect(kDecorationPrices['Fruits'], 80);
      expect(kDecorationPrices['Birthday Theme'], 100);
      expect(kDecorationPrices['Custom Decoration'], 150);
    });

    test('the six flavours keep their order and surcharges', () {
      expect(
        kFlavors.map((Flavor flavor) => flavor.id).toList(),
        <String>[
          'Chocolate',
          'Vanilla',
          'Red Velvet',
          'Black Forest',
          'Butterscotch',
          'Strawberry',
        ],
      );
      expect(kFlavors.map((Flavor flavor) => flavor.base).toList(),
          <int>[0, 0, 50, 60, 40, 50]);
    });

    test('flavorStartingPrice uses the 1 Kg price', () {
      expect(flavorStartingPrice(kFlavors.first), 550);
      expect(flavorStartingPrice(kFlavors[2]), 600);
      expect(flavorStartingPrice(kFlavors[3]), 610);
    });
  });
}

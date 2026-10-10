// Static application data — direct ports of the constants in
// `college-bakery/js/app.js`, `js/customize.js` and `customize.html`.

/// A cake flavour (`FLAVORS` in `js/app.js`).
class Flavor {
  const Flavor({
    required this.id,
    required this.key,
    required this.desc,
    required this.base,
  });

  /// `id` — displayed name, e.g. `Chocolate`.
  final String id;

  /// `key` — image key inside [CakeImages].
  final String key;

  /// `desc` — the copy shown on the flavour card.
  final String desc;

  /// `base` — flavour surcharge added to the size price.
  final int base;
}

/// `FLAVORS` — order matters, it drives the landing page and the flavour grid.
const List<Flavor> kFlavors = <Flavor>[
  Flavor(
    id: 'Chocolate',
    key: 'chocolate',
    desc: 'Rich, moist chocolate sponge with creamy chocolate frosting.',
    base: 0,
  ),
  Flavor(
    id: 'Vanilla',
    key: 'vanilla',
    desc: 'Classic vanilla sponge with silky vanilla buttercream.',
    base: 0,
  ),
  Flavor(
    id: 'Red Velvet',
    key: 'redVelvet',
    desc: 'Velvety cocoa sponge with tangy cream cheese frosting.',
    base: 50,
  ),
  Flavor(
    id: 'Black Forest',
    key: 'blackForest',
    desc: 'Chocolate sponge, cherries and whipped cream layers.',
    base: 60,
  ),
  Flavor(
    id: 'Butterscotch',
    key: 'butterscotch',
    desc: 'Caramel-kissed sponge with crunchy praline bits.',
    base: 40,
  ),
  Flavor(
    id: 'Strawberry',
    key: 'strawberry',
    desc: 'Light sponge layered with fresh strawberry cream.',
    base: 50,
  ),
];

/// `SIZE_PRICES` — keeps insertion order (`500g`, `1 Kg`, `1.5 Kg`, `2 Kg`).
const Map<String, int> kSizePrices = <String, int>{
  '500g': 300,
  '1 Kg': 550,
  '1.5 Kg': 750,
  '2 Kg': 1000,
};

/// `DECORATION_PRICES` — optional add-ons, order preserved.
const Map<String, int> kDecorationPrices = <String, int>{
  'Fresh Flowers': 50,
  'Chocolate Decorations': 100,
  'Sprinkles': 30,
  'Fruits': 80,
  'Birthday Theme': 100,
  'Custom Decoration': 150,
};

/// `CREAM_ICONS` in `js/customize.js`.
const Map<String, String> kCreamIcons = <String, String>{
  'Chocolate': '🍫',
  'Vanilla': '🍦',
  'Strawberry': '🍓',
  'Butterscotch': '🧈',
};

/// `DECO_ICONS` in `js/customize.js`.
const Map<String, String> kDecorationIcons = <String, String>{
  'Fresh Flowers': '🌸',
  'Chocolate Decorations': '🍫',
  'Sprinkles': '✨',
  'Fruits': '🍒',
  'Birthday Theme': '🎉',
  'Custom Decoration': '🎨',
};

/// The two cake types rendered directly in `customize.html`.
class CakeTypeOption {
  const CakeTypeOption({
    required this.value,
    required this.icon,
    required this.sub,
  });

  final String value;
  final String icon;
  final String sub;
}

const List<CakeTypeOption> kCakeTypes = <CakeTypeOption>[
  CakeTypeOption(value: 'Egg', icon: '🥚', sub: 'Classic preparation'),
  CakeTypeOption(
    value: 'Eggless',
    icon: '🌿',
    sub: 'Vegetarian-friendly',
  ),
];

/// `cakeImages` in `js/app.js` — the same image URLs the web app uses.
class CakeImages {
  CakeImages._();

  static const String chocolate =
      'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?auto=format&fit=crop&w=800&q=80';
  static const String vanilla =
      'https://images.unsplash.com/photo-1519869325930-281384150729?auto=format&fit=crop&w=800&q=80';
  static const String redVelvet =
      'https://images.unsplash.com/photo-1586788680434-30d324b2d46f?auto=format&fit=crop&w=800&q=80';
  static const String blackForest =
      'https://images.unsplash.com/photo-1571115177098-24ec42ed204d?auto=format&fit=crop&w=800&q=80';
  static const String butterscotch =
      'https://images.unsplash.com/photo-1587248720327-8eb72564be1e?auto=format&fit=crop&w=800&q=80';
  static const String strawberry =
      'https://images.unsplash.com/photo-1565958011703-44f9829ba187?auto=format&fit=crop&w=800&q=80';
  static const String birthday =
      'https://images.unsplash.com/photo-1464349095431-e9a21285b5f3?auto=format&fit=crop&w=1200&q=80';
  static const String hero =
      'https://images.unsplash.com/photo-1578985545062-69928b1d9587?auto=format&fit=crop&w=1400&q=80';
  static const String custom =
      'https://images.unsplash.com/photo-1550617931-e17a7b70dce2?auto=format&fit=crop&w=800&q=80';
  static const String chocolateDecoration =
      'https://images.unsplash.com/photo-1541599468348-e96984315921?auto=format&fit=crop&w=800&q=80';
  static const String fruitDecoration =
      'https://images.unsplash.com/photo-1587668178277-295251f900ce?auto=format&fit=crop&w=800&q=80';
  static const String flowerDecoration =
      'https://images.unsplash.com/photo-1519340241574-2cec6aef0c01?auto=format&fit=crop&w=800&q=80';

  /// `cakeImages[key]`
  static String byKey(String key) {
    const Map<String, String> map = <String, String>{
      'chocolate': chocolate,
      'vanilla': vanilla,
      'redVelvet': redVelvet,
      'blackForest': blackForest,
      'butterscotch': butterscotch,
      'strawberry': strawberry,
      'birthday': birthday,
      'hero': hero,
      'custom': custom,
      'chocolateDecoration': chocolateDecoration,
      'fruitDecoration': fruitDecoration,
      'flowerDecoration': flowerDecoration,
    };
    return map[key] ?? hero;
  }
}

/// `getFlavorImage()` in `js/orders.js` — flavour name → image URL.
String flavorImage(String flavorName) {
  for (final Flavor flavor in kFlavors) {
    if (flavor.id == flavorName) return CakeImages.byKey(flavor.key);
  }
  return CakeImages.hero;
}

/// `flavorSurcharge()` in `js/app.js`.
int flavorSurcharge(String? flavorName) {
  if (flavorName == null) return 0;
  for (final Flavor flavor in kFlavors) {
    if (flavor.id == flavorName) return flavor.base;
  }
  return 0;
}

/// The "From ₹…" price shown on flavour cards and the landing page:
/// `SIZE_PRICES["1 Kg"] + f.base`.
int flavorStartingPrice(Flavor flavor) => kSizePrices['1 Kg']! + flavor.base;

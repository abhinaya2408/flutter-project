import 'package:college_bakery_flutter/state/customize_controller.dart';
import 'package:college_bakery_flutter/utils/formatters.dart';
import 'package:college_bakery_flutter/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CustomizeController controller;

  setUp(() => controller = CustomizeController());

  test('starts empty with the Chocolate placeholder preview', () {
    expect(controller.previewTitle, 'Chocolate Cake');
    expect(
      controller.previewTags,
      'Select your options to see a live preview',
    );
    expect(controller.previewMessage, isNull);
    expect(controller.total, 0);
  });

  test('live preview tag line follows the CSS join order', () {
    controller.selectFlavor('Red Velvet');
    controller.selectSize('1.5 Kg');
    controller.selectCakeType('Eggless');
    controller.selectCream('Vanilla');
    controller.toggleDecoration('Fresh Flowers');
    controller.toggleDecoration('Sprinkles');

    expect(controller.previewTitle, 'Red Velvet Cake');
    expect(
      controller.previewTags,
      '1.5 Kg · Eggless · Vanilla Cream · Fresh Flowers, Sprinkles',
    );
  });

  test('cake message is quoted and trimmed in the preview', () {
    controller.setCakeMessage('  Happy Birthday Priya!  ');
    expect(controller.previewMessage, '"Happy Birthday Priya!"');
  });

  test('toggling a decoration twice removes it', () {
    controller.toggleDecoration('Sprinkles');
    expect(controller.price.decorPrice, 30);
    controller.toggleDecoration('Sprinkles');
    expect(controller.price.decorPrice, 0);
  });

  test('summary totals match calculatePrice', () {
    controller.selectFlavor('Black Forest');
    controller.selectSize('2 Kg');
    controller.toggleDecoration('Chocolate Decorations');
    controller.toggleDecoration('Fruits');
    expect(controller.basePrice, 1060);
    expect(controller.decorPrice, 180);
    expect(controller.total, 1240);
  });

  group('validate() — placeOrder() validation', () {
    test('lists every missing required field', () {
      final PlaceOrderValidation result = controller.validate();
      expect(result.isValid, isFalse);
      expect(
        result.formError,
        'Please complete: cake flavor, cake type (Egg/Eggless), cake size, '
        'cream, required date, required time.',
      );
      expect(result.dateError, Validators.dateRequired);
      expect(result.timeError, Validators.timeRequired);
    });

    test('flags a date before today', () {
      final String yesterday = Formatters.dateOnly(
        DateTime.now().subtract(const Duration(days: 1)),
      );
      controller.selectFlavor('Chocolate');
      controller.selectCakeType('Egg');
      controller.selectSize('1 Kg');
      controller.selectCream('Chocolate');
      controller.setRequiredDate(yesterday);
      controller.setRequiredTime('16:00');

      final PlaceOrderValidation result = controller.validate();
      expect(result.dateError, Validators.dateInPast);
      expect(
        result.formError,
        'Please complete: valid required date.',
      );
    });

    test('accepts a complete valid selection', () {
      controller.selectFlavor('Chocolate');
      controller.selectCakeType('Eggless');
      controller.selectSize('1 Kg');
      controller.selectCream('Chocolate');
      controller.setRequiredDate(Formatters.today());
      controller.setRequiredTime('16:00');

      final PlaceOrderValidation result = controller.validate();
      expect(result.isValid, isTrue);
      expect(result.formError, isNull);
      expect(result.dateError, isNull);
      expect(result.timeError, isNull);
    });
  });
}

import 'package:flutter/foundation.dart';

import '../models/customization_draft.dart';
import '../utils/pricing.dart';
import '../utils/validators.dart';

/// The `placeOrder()` validation result — `formError`, `dateError` and
/// `timeError` in `js/customize.js`.
class PlaceOrderValidation {
  const PlaceOrderValidation({
    required this.formError,
    required this.dateError,
    required this.timeError,
  });

  final String? formError;
  final String? dateError;
  final String? timeError;

  bool get isValid => formError == null;
}

/// Drives the "Customize Your Cake" page — the Flutter equivalent of the
/// `customizeState` object plus `updatePreview()`, `updateSummary()` and the
/// validation half of `placeOrder()`.
class CustomizeController extends ChangeNotifier {
  CustomizeController({CustomizationDraft? draft})
      : draft = draft ?? CustomizationDraft();

  final CustomizationDraft draft;

  String? _imageError;

  String? get imageError => _imageError;

  // ---------- Live preview (`updatePreview()`) ----------
  String get previewTitle => '${draft.previewFlavor} Cake';
  String get previewTags => draft.previewTags;
  String? get previewMessage => draft.cakeMessage.trim().isEmpty
      ? null
      : '"${draft.cakeMessage.trim()}"';

  // ---------- Order summary (`updateSummary()`) ----------
  PriceBreakdown get price => calculatePrice(
        flavor: draft.flavor,
        size: draft.size,
        decorations: draft.decorations,
      );

  int get basePrice => price.basePrice;
  int get decorPrice => price.decorPrice;
  int get total => price.total;

  // ---------- Selections ----------
  void selectFlavor(String flavor) {
    draft.flavor = flavor;
    notifyListeners();
  }

  void selectCakeType(String cakeType) {
    draft.cakeType = cakeType;
    notifyListeners();
  }

  void selectSize(String size) {
    draft.size = size;
    notifyListeners();
  }

  void selectCream(String cream) {
    draft.cream = cream;
    notifyListeners();
  }

  void toggleDecoration(String decoration) {
    draft.toggleDecoration(decoration);
    notifyListeners();
  }

  void setCakeMessage(String value) {
    draft.cakeMessage = value;
    notifyListeners();
  }

  void setSpecialInstructions(String value) {
    draft.specialInstructions = value;
    notifyListeners();
  }

  void setRequiredDate(String? value) {
    draft.requiredDate = value;
    notifyListeners();
  }

  void setRequiredTime(String? value) {
    draft.requiredTime = value;
    notifyListeners();
  }

  // ---------- Reference image ----------
  void setImageError(String? message) {
    _imageError = message;
    notifyListeners();
  }

  void setReferenceImage(ReferenceImageFile? file) {
    draft.referenceImage = file;
    _imageError = null;
    notifyListeners();
  }

  /// `removeBtn` handler — clears the pick without touching the other fields.
  void removeReferenceImage() {
    draft.clearReferenceImage();
    _imageError = null;
    notifyListeners();
  }

  /// The validation block of `placeOrder()`.
  PlaceOrderValidation validate() {
    final List<String> missing = <String>[];
    String? dateError;
    String? timeError;

    if (draft.flavor == null) missing.add('cake flavor');
    if (draft.cakeType == null) missing.add('cake type (Egg/Eggless)');
    if (draft.size == null) missing.add('cake size');
    if (draft.cream == null) missing.add('cream');

    if (draft.requiredDate == null || draft.requiredDate!.isEmpty) {
      missing.add('required date');
      dateError = Validators.dateRequired;
    } else {
      final String today = _today();
      if (draft.requiredDate!.compareTo(today) < 0) {
        missing.add('valid required date');
        dateError = Validators.dateInPast;
      }
    }

    if (draft.requiredTime == null || draft.requiredTime!.isEmpty) {
      missing.add('required time');
      timeError = Validators.timeRequired;
    }

    if (missing.isNotEmpty) {
      return PlaceOrderValidation(
        formError: Validators.missingFieldsMessage(missing),
        dateError: dateError,
        timeError: timeError,
      );
    }

    return const PlaceOrderValidation(
      formError: null,
      dateError: null,
      timeError: null,
    );
  }

  String _today() {
    final DateTime now = DateTime.now();
    final String month = now.month.toString().padLeft(2, '0');
    final String day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }
}

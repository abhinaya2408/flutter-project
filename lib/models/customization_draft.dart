import 'dart:typed_data';

/// The reference photo the student picked, before it is uploaded to Firebase
/// Storage. Mirrors `customizeState.referenceImageMeta` (`{ name, size }`) plus
/// the bytes themselves.
class ReferenceImageFile {
  const ReferenceImageFile({
    required this.name,
    required this.size,
    required this.bytes,
  });

  final String name;
  final int size;
  final Uint8List bytes;
}

/// The customize form state — a 1:1 port of `customizeState` in
/// `college-bakery/js/customize.js` (except that the picked image is held as
/// bytes until the order is placed, then uploaded to Firebase Storage).
class CustomizationDraft {
  String? flavor;
  String? cakeType;
  String? size;
  String? cream;
  List<String> decorations = <String>[];
  String cakeMessage = '';
  String specialInstructions = '';
  ReferenceImageFile? referenceImage;

  /// `YYYY-MM-DD`
  String? requiredDate;

  /// `HH:mm`
  String? requiredTime;

  /// `customizeState` starts empty and the preview falls back to `Chocolate`.
  String get previewFlavor => flavor ?? 'Chocolate';

  /// `updatePreview()` — the tag line under the preview title.
  String get previewTags {
    final List<String> parts = <String>[];
    if (size != null) parts.add(size!);
    if (cakeType != null) parts.add(cakeType!);
    if (cream != null) parts.add('$cream Cream');
    if (decorations.isNotEmpty) parts.add(decorations.join(', '));
    return parts.isEmpty
        ? 'Select your options to see a live preview'
        : parts.join(' · ');
  }

  void toggleDecoration(String decoration) {
    if (decorations.contains(decoration)) {
      decorations = decorations
          .where((String value) => value != decoration)
          .toList();
    } else {
      decorations = <String>[...decorations, decoration];
    }
  }

  void clearReferenceImage() {
    referenceImage = null;
  }
}

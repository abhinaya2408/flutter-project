import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../config/app_config.dart';
import '../models/customization_draft.dart';

/// Reference photos.
///
/// `js/customize.js` read the picked file as a Data URL and stored it inline on
/// the order (`referenceImage`). The Flutter app keeps the identical user
/// experience — same accept list, same 2 MB limit, same preview and remove
/// behaviour — but uploads the file to Firebase Storage and stores the download
/// URL in the same `referenceImage` field.
class ReferenceImageService {
  ReferenceImageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<String> uploadReferenceImage({
    required ReferenceImageFile file,
    required String orderId,
  }) async {
    final Reference reference = _storage
        .ref()
        .child('${AppConfig.referenceImageFolder}/$orderId/${file.name}');
    final Uint8List bytes = file.bytes;
    final UploadTask task = reference.putData(
      bytes,
      SettableMetadata(contentType: contentTypeForName(file.name)),
    );
    final TaskSnapshot snapshot = await task;
    return snapshot.ref.getDownloadURL();
  }

  /// "Clear Demo Data" — removes every uploaded reference photo.
  Future<void> deleteAllReferenceImages() async {
    try {
      final ListResult result =
          await _storage.ref(AppConfig.referenceImageFolder).listAll();
      for (final Reference prefix in result.prefixes) {
        final ListResult nested = await prefix.listAll();
        for (final Reference item in nested.items) {
          await item.delete();
        }
        for (final Reference inner in nested.prefixes) {
          final ListResult files = await inner.listAll();
          for (final Reference item in files.items) {
            await item.delete();
          }
        }
      }
      for (final Reference item in result.items) {
        await item.delete();
      }
    } on FirebaseException {
      // Storage may be empty or unavailable — the reset still completes.
    }
  }

  /// `file.type` equivalent: `image/jpeg` or `image/png`.
  static String contentTypeForName(String name) {
    final String lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    return 'image/jpeg';
  }
}

import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../config/app_config.dart';
import '../models/customization_draft.dart';
import 'cloudinary_image_service.dart';

/// Reference photos.
///
/// `js/customize.js` read the picked file as a Data URL and stored it inline on
/// the order (`referenceImage`). The Flutter app keeps the identical user
/// experience — same accept list, same 2 MB limit, same preview and remove
/// behaviour — and stores a URL in the same `referenceImage` field.
///
/// Uploads go to **Cloudinary** (see [CloudinaryImageService]) because that is
/// the configured provider. The original Firebase Storage upload is kept as a
/// switchable fallback via [AppConfig.useCloudinaryForReferenceImages] so the
/// previous behaviour can be restored without a code change elsewhere.
///
/// Whatever happens, the URL returned from here is one the provider actually
/// issued: a failed upload throws and no order is written with a made-up or
/// empty image URL.
class ReferenceImageService {
  ReferenceImageService({FirebaseStorage? storage, CloudinaryImageService? cloudinary})
      : _storage = storage ?? FirebaseStorage.instance,
        _cloudinary = cloudinary ?? CloudinaryImageService();

  final FirebaseStorage _storage;
  final CloudinaryImageService _cloudinary;

  Future<String> uploadReferenceImage({
    required ReferenceImageFile file,
    required String orderId,
  }) {
    if (AppConfig.useCloudinaryForReferenceImages) {
      // Cloudinary names the asset itself; `orderId` is only needed by the
      // Firebase Storage path below.
      return _cloudinary.uploadReferenceImage(file: file);
    }
    return _uploadToFirebaseStorage(file: file, orderId: orderId);
  }

  Future<String> _uploadToFirebaseStorage({
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

  /// "Clear Demo Data" — removes reference photos left in **Firebase Storage**
  /// by the pre-Cloudinary upload path.
  ///
  /// This cannot clear Cloudinary: an unsigned preset is not allowed to list,
  /// overwrite or delete assets, and a Cloudinary deletion needs a signed
  /// request carrying the API secret, which must never live in the app.
  /// Removing Cloudinary assets therefore requires a trusted backend.
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

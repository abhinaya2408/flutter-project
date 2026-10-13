import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';
import '../models/customization_draft.dart';
import '../utils/validators.dart';

/// A reference-photo upload that did not end in a usable image URL.
///
/// The message is written for the student, not for a log, and the presence of
/// [httpStatus] / [cloudinaryError] keeps the raw cause available to the screen
/// without inventing one.
class CloudinaryUploadException implements Exception {
  CloudinaryUploadException(
    this.message, {
    this.httpStatus,
    this.cloudinaryError,
  });

  final String message;
  final int? httpStatus;

  /// Cloudinary's own `error.message`, when it sent one.
  final String? cloudinaryError;

  @override
  String toString() => message;
}

/// Uploads the optional cake reference photo to Cloudinary.
///
/// This is an **unsigned** upload: the request carries only the public cloud
/// name and an upload preset, both of which are *designed* to ship inside a
/// client app. There is no API key, no API secret and no signed-upload
/// credential anywhere in this file, and there must never be one — a Cloudinary
/// API secret can only live on a trusted backend.
///
/// Unsigned presets cannot delete, overwrite by public id or list assets, so
/// this service deliberately exposes no delete/overwrite operation: cleaning up
/// an orphaned asset needs a signed call from a backend.
class CloudinaryImageService {
  CloudinaryImageService({
    http.Client? client,
    String? cloudName,
    String? uploadPreset,
  })  : _client = client ?? _sharedClient,
        cloudName = cloudName ?? AppConfig.cloudinaryCloudName,
        uploadPreset = uploadPreset ?? AppConfig.cloudinaryUploadPreset;

  /// Shared across uploads so a photo upload does not leak a connection pool.
  static final http.Client _sharedClient = http.Client();

  static const Duration requestTimeout = Duration(seconds: 30);

  final http.Client _client;
  final String cloudName;
  final String uploadPreset;

  /// `https://api.cloudinary.com/v1_1/<cloud_name>/image/upload`
  static Uri endpointFor(String cloudName) =>
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

  /// Uploads [file] and returns Cloudinary's `secure_url`, ready to store in
  /// `Order.referenceImage`.
  ///
  /// Throws [CloudinaryUploadException] for every failure — a rejected upload
  /// never returns a URL, so a failed upload can never be saved as if it
  /// succeeded.
  Future<String> uploadReferenceImage({required ReferenceImageFile file}) async {
    _rejectInvalid(file);

    if (cloudName.isEmpty || uploadPreset.isEmpty) {
      throw CloudinaryUploadException(
        'Photo uploads are not set up yet (the Cloudinary cloud name or upload '
        'preset is missing). You can place the order without a photo.',
      );
    }

    final http.MultipartRequest request =
        http.MultipartRequest('POST', endpointFor(cloudName))
          ..fields['upload_preset'] = uploadPreset
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              file.bytes,
              filename: file.name,
              contentType: _mediaTypeFor(file.name),
            ),
          );

    final http.Response response;
    try {
      final http.StreamedResponse streamed =
          await _client.send(request).timeout(requestTimeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw CloudinaryUploadException(
        'The photo upload timed out. Check your connection and try again.',
      );
    } catch (_) {
      throw CloudinaryUploadException(
        'Could not reach the image service. Check your connection and try '
        'again.',
      );
    }

    final Map<String, dynamic> body = _decodeBody(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudinaryUploadException(
        _errorMessage(body, response.statusCode),
        httpStatus: response.statusCode,
        cloudinaryError: _cloudinaryErrorMessage(body),
      );
    }

    final Object? secureUrl = body['secure_url'];
    if (secureUrl is! String || !_isUsableUrl(secureUrl)) {
      // A 200 without a valid `secure_url` is still a failure: storing an empty
      // or malformed value would silently lose the student's photo.
      throw CloudinaryUploadException(
        'The image service did not return a usable photo URL, so the order was '
        'not placed with a photo.',
        httpStatus: response.statusCode,
      );
    }

    return secureUrl;
  }

  /// Validates what the picker handed us, before any network call.
  void _rejectInvalid(ReferenceImageFile file) {
    if (file.bytes.isEmpty) {
      throw CloudinaryUploadException(Validators.imageReadFailed);
    }
    if (file.size > Validators.maxImageBytes ||
        file.bytes.length > Validators.maxImageBytes) {
      throw CloudinaryUploadException(Validators.imageTooLarge);
    }
    final String extension = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : '';
    if (!Validators.allowedImageExtensions.contains(extension)) {
      throw CloudinaryUploadException(Validators.imageTypeInvalid);
    }
  }

  static MediaType _mediaTypeFor(String fileName) =>
      fileName.toLowerCase().endsWith('.png')
          ? MediaType('image', 'png')
          : MediaType('image', 'jpeg');

  /// A `secure_url` is only stored when it is an absolute HTTPS URL.
  static bool _isUsableUrl(String url) {
    final Uri? uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.path.isNotEmpty;
  }

  static Map<String, dynamic> _decodeBody(String raw) {
    if (raw.trim().isEmpty) return <String, dynamic>{};
    try {
      final Object? decoded = jsonDecode(raw);
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static String? _cloudinaryErrorMessage(Map<String, dynamic> body) {
    final Object? error = body['error'];
    if (error is Map && error['message'] is String) {
      return error['message'] as String;
    }
    return null;
  }

  static String _errorMessage(Map<String, dynamic> body, int statusCode) {
    final String? detail = _cloudinaryErrorMessage(body);
    if (detail == null || detail.isEmpty) {
      return 'The photo upload was rejected (HTTP $statusCode). You can retry, '
          'or place the order without a photo.';
    }
    return 'The photo upload was rejected: $detail';
  }
}

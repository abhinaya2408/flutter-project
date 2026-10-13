import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:college_bakery_flutter/config/app_config.dart';
import 'package:college_bakery_flutter/models/customization_draft.dart';
import 'package:college_bakery_flutter/services/cloudinary_image_service.dart';
import 'package:college_bakery_flutter/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// ASCII bytes, so the multipart body can still be inspected as text. The
/// service only validates the name, size and length, so the fixtures do not
/// need to be real images.
ReferenceImageFile fakeFile({String name = 'cake.png', int length = 32}) {
  final Uint8List bytes = Uint8List.fromList(utf8.encode('p' * length));
  return ReferenceImageFile(name: name, size: bytes.length, bytes: bytes);
}

const String secureUrl =
    'https://res.cloudinary.com/haryqfbk/image/upload/v1712345678/cake.png';

void main() {
  group('endpoint and configuration', () {
    test('uses the configured cloud name and unsigned preset', () {
      // Both values are public by design: an unsigned preset exists so a client
      // can upload without holding any credential.
      final CloudinaryImageService service = CloudinaryImageService();

      expect(service.cloudName, 'haryqfbk');
      expect(service.uploadPreset, 'crumbly_reference_upload');
      expect(
        CloudinaryImageService.endpointFor(service.cloudName).toString(),
        'https://api.cloudinary.com/v1_1/haryqfbk/image/upload',
      );
    });

    test('reports when no preset is configured', () async {
      final CloudinaryImageService service = CloudinaryImageService(
        client: MockClient((http.Request _) async => http.Response('{}', 200)),
        cloudName: '',
        uploadPreset: '',
      );

      await expectLater(
        service.uploadReferenceImage(file: fakeFile()),
        throwsA(isA<CloudinaryUploadException>()),
      );
    });
  });

  group('successful upload', () {
    late http.Request captured;

    CloudinaryImageService serviceReturning(
      String body,
      int statusCode, {
      void Function(http.Request request)? onRequest,
    }) =>
        CloudinaryImageService(
          client: MockClient((http.Request request) async {
            captured = request;
            onRequest?.call(request);
            return http.Response(body, statusCode);
          }),
          cloudName: 'haryqfbk',
          uploadPreset: 'crumbly_reference_upload',
        );

    test('posts a multipart upload and returns the secure_url', () async {
      final CloudinaryImageService service = serviceReturning(
        jsonEncode(<String, dynamic>{'secure_url': secureUrl, 'public_id': 'cake'}),
        200,
      );

      final String url = await service.uploadReferenceImage(file: fakeFile());

      expect(url, secureUrl);
      expect(captured.method, 'POST');
      expect(
        captured.url.toString(),
        'https://api.cloudinary.com/v1_1/haryqfbk/image/upload',
      );
      expect(captured.body, contains('name="upload_preset"'));
      expect(captured.body, contains('crumbly_reference_upload'));
      expect(captured.body, contains('name="file"'));
      expect(captured.body, contains('filename="cake.png"'));
      // `package:http` writes multipart part headers in lower case.
      expect(captured.body, contains('content-type: image/png'));
    });

    test('sends the jpeg content type for a .jpg pick', () async {
      await serviceReturning(jsonEncode({'secure_url': secureUrl}), 200)
          .uploadReferenceImage(file: fakeFile(name: 'photo.JPG'));

      expect(captured.body, contains('content-type: image/jpeg'));
    });

    test('never sends an API secret or a signature', () async {
      await serviceReturning(jsonEncode({'secure_url': secureUrl}), 200)
          .uploadReferenceImage(file: fakeFile());

      final String body = captured.body.toLowerCase();
      expect(body, isNot(contains('api_secret')));
      expect(body, isNot(contains('signature')));
      expect(body, isNot(contains('api_key')));
    });
  });

  group('failures never look like success', () {
    CloudinaryImageService serviceFor(http.Response Function() respond) =>
        CloudinaryImageService(
          client: MockClient((http.Request _) async => respond()),
          cloudName: 'haryqfbk',
          uploadPreset: 'crumbly_reference_upload',
        );

    test('surfaces the Cloudinary error message', () async {
      final CloudinaryImageService service = serviceFor(
        () => http.Response(
          jsonEncode(<String, dynamic>{
            'error': <String, dynamic>{'message': 'Upload preset not found'},
          }),
          400,
        ),
      );

      await expectLater(
        service.uploadReferenceImage(file: fakeFile()),
        throwsA(
          isA<CloudinaryUploadException>()
              .having((CloudinaryUploadException e) => e.httpStatus, 'status', 400)
              .having(
                (CloudinaryUploadException e) => e.cloudinaryError,
                'cloudinaryError',
                'Upload preset not found',
              )
              .having(
                (CloudinaryUploadException e) => e.message,
                'message',
                contains('Upload preset not found'),
              ),
        ),
      );
    });

    test('rejects a non-2xx response with an empty body', () async {
      await expectLater(
        serviceFor(() => http.Response('', 502)).uploadReferenceImage(file: fakeFile()),
        throwsA(
          isA<CloudinaryUploadException>().having(
            (CloudinaryUploadException e) => e.httpStatus,
            'status',
            502,
          ),
        ),
      );
    });

    test('treats a 200 with no secure_url as a failure', () async {
      await expectLater(
        serviceFor(() => http.Response(jsonEncode(<String, dynamic>{'public_id': 'x'}), 200))
            .uploadReferenceImage(file: fakeFile()),
        throwsA(isA<CloudinaryUploadException>()),
      );
    });

    test('refuses a non-HTTPS url', () async {
      await expectLater(
        serviceFor(
          () => http.Response(
            jsonEncode(<String, dynamic>{
              'secure_url': 'http://res.cloudinary.com/haryqfbk/image/upload/cake.png',
            }),
            200,
          ),
        ).uploadReferenceImage(file: fakeFile()),
        throwsA(isA<CloudinaryUploadException>()),
      );
    });

    test('refuses an empty secure_url', () async {
      await expectLater(
        serviceFor(
          () => http.Response(jsonEncode(<String, dynamic>{'secure_url': ''}), 200),
        ).uploadReferenceImage(file: fakeFile()),
        throwsA(isA<CloudinaryUploadException>()),
      );
    });

    test('reports a timeout in plain words', () async {
      final CloudinaryImageService service = CloudinaryImageService(
        client: MockClient((http.Request _) async => throw TimeoutException('slow')),
        cloudName: 'haryqfbk',
        uploadPreset: 'crumbly_reference_upload',
      );

      await expectLater(
        service.uploadReferenceImage(file: fakeFile()),
        throwsA(
          isA<CloudinaryUploadException>()
              .having((CloudinaryUploadException e) => e.message, 'message', contains('timed out')),
        ),
      );
    });

    test('reports a network failure in plain words', () async {
      final CloudinaryImageService service = CloudinaryImageService(
        client: MockClient(
          (http.Request _) async => throw http.ClientException('no route'),
        ),
        cloudName: 'haryqfbk',
        uploadPreset: 'crumbly_reference_upload',
      );

      await expectLater(
        service.uploadReferenceImage(file: fakeFile()),
        throwsA(
          isA<CloudinaryUploadException>().having(
            (CloudinaryUploadException e) => e.message,
            'message',
            contains('Could not reach the image service'),
          ),
        ),
      );
    });
  });

  group('validation happens before any request', () {
    late int requests;

    CloudinaryImageService countingService() {
      requests = 0;
      return CloudinaryImageService(
        client: MockClient((http.Request _) async {
          requests += 1;
          return http.Response(jsonEncode({'secure_url': secureUrl}), 200);
        }),
        cloudName: 'haryqfbk',
        uploadPreset: 'crumbly_reference_upload',
      );
    }

    test('rejects a file that is too large', () async {
      final CloudinaryImageService service = countingService();
      final ReferenceImageFile big = fakeFile(length: Validators.maxImageBytes + 1);

      await expectLater(
        service.uploadReferenceImage(file: big),
        throwsA(
          isA<CloudinaryUploadException>().having(
            (CloudinaryUploadException e) => e.message,
            'message',
            Validators.imageTooLarge,
          ),
        ),
      );
      expect(requests, 0);
    });

    test('rejects an unsupported file type', () async {
      final CloudinaryImageService service = countingService();

      await expectLater(
        service.uploadReferenceImage(file: fakeFile(name: 'cake.gif')),
        throwsA(
          isA<CloudinaryUploadException>().having(
            (CloudinaryUploadException e) => e.message,
            'message',
            Validators.imageTypeInvalid,
          ),
        ),
      );
      expect(requests, 0);
    });

    test('rejects an unreadable (empty) pick', () async {
      final CloudinaryImageService service = countingService();

      await expectLater(
        service.uploadReferenceImage(file: fakeFile(length: 1)),
        // A single byte is still a valid length, so this one goes through.
        completes,
      );
      expect(requests, 1);

      final CloudinaryImageService service2 = countingService();
      final ReferenceImageFile empty = ReferenceImageFile(
        name: 'cake.png',
        size: 0,
        bytes: Uint8List(0),
      );
      await expectLater(
        service2.uploadReferenceImage(file: empty),
        throwsA(
          isA<CloudinaryUploadException>().having(
            (CloudinaryUploadException e) => e.message,
            'message',
            Validators.imageReadFailed,
          ),
        ),
      );
      expect(requests, 0);
    });
  });

  group('app configuration', () {
    test('is marked configured and is used by default', () {
      expect(AppConfig.isCloudinaryConfigured, isTrue);
      expect(AppConfig.useCloudinaryForReferenceImages, isTrue);
    });
  });
}

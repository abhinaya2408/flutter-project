import 'package:college_bakery_flutter/config/app_config.dart';
import 'package:college_bakery_flutter/models/otp_verification.dart';
import 'package:college_bakery_flutter/services/whatsapp_otp_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_otp_backend.dart';

void main() {
  late FakeOtpBackend backend;
  late WhatsAppOtpService service;

  setUp(() {
    backend = FakeOtpBackend();
    service = WhatsAppOtpService(backend: backend);
  });

  group('requestCode', () {
    test('calls the request function and parses the challenge', () async {
      backend.response = FakeOtpBackend.sentResponse();

      final OtpChallenge challenge =
          await service.requestCode(phoneE164: '+919876543210');

      expect(backend.calls.single.function, AppConfig.requestOtpFunction);
      expect(backend.calls.single.data['phoneNumber'], '+919876543210');
      expect(challenge.phoneMasked, '+91 ••••••3210');
      expect(challenge.resendAfterSeconds, 60);
      expect(challenge.expiresInSeconds, 600);
    });

    test('omits the locale when none is given and sends it when asked', () async {
      backend.response = FakeOtpBackend.sentResponse();

      await service.requestCode(phoneE164: '+919876543210');
      expect(backend.calls.single.data.containsKey('locale'), isFalse);

      await service.requestCode(phoneE164: '+919876543210', locale: 'en');
      expect(backend.calls.last.data['locale'], 'en');
    });

    test('treats a payload that is not a sent result as a failure', () async {
      backend.response = <String, dynamic>{'status': 'pending'};

      await expectLater(
        service.requestCode(phoneE164: '+919876543210'),
        throwsA(
          isA<OtpException>()
              .having((OtpException e) => e.failure, 'failure', OtpFailure.unknown),
        ),
      );
    });

    test('treats a payload with no masked number as a failure', () async {
      backend.response = <String, dynamic>{'status': 'sent'};

      await expectLater(
        service.requestCode(phoneE164: '+919876543210'),
        throwsA(isA<OtpException>()),
      );
    });
  });

  group('verifyCode', () {
    test('returns the custom token for a signed-in result', () async {
      backend.response = FakeOtpBackend.verifiedResponse();

      final WhatsAppVerification result = await service.verifyCode(
        phoneE164: '+919876543210',
        code: '123456',
      );

      expect(backend.calls.single.function, AppConfig.verifyOtpFunction);
      expect(backend.calls.single.data['intent'], OtpIntent.signIn.wire);
      expect(backend.calls.single.data['code'], '123456');
      expect(result.status, WhatsAppVerificationStatus.signedIn);
      expect(result.customToken, 'custom-token-value');
      expect(result.role, WhatsAppAccountRole.student);
      expect(result.uid, 'uid-1');
    });

    test('never reports a signed-in result without a usable token', () async {
      backend.response = FakeOtpBackend.verifiedResponse(customToken: null);

      await expectLater(
        service.verifyCode(phoneE164: '+919876543210', code: '123456'),
        throwsA(
          isA<OtpException>()
              .having((OtpException e) => e.failure, 'failure', OtpFailure.unknown),
        ),
      );
    });

    test('rejects an unknown role instead of guessing one', () async {
      backend.response = FakeOtpBackend.verifiedResponse(role: 'admin');

      await expectLater(
        service.verifyCode(phoneE164: '+919876543210', code: '123456'),
        throwsA(isA<OtpException>()),
      );
    });
  });

  group('linkNumber', () {
    test('asks the backend for the link intent and needs no token back', () async {
      backend.response = FakeOtpBackend.verifiedResponse(
        status: 'linked',
        customToken: null,
      );

      final WhatsAppVerification result =
          await service.linkNumber(phoneE164: '+919876543210', code: '123456');

      expect(backend.calls.single.data['intent'], OtpIntent.link.wire);
      expect(result.status, WhatsAppVerificationStatus.linked);
      expect(result.customToken, isNull);
    });

    test('accepts a bakery member role', () async {
      backend.response = FakeOtpBackend.verifiedResponse(
        status: 'linked',
        role: 'bakery_member',
        customToken: null,
      );

      final WhatsAppVerification result =
          await service.linkNumber(phoneE164: '+919876543210', code: '123456');
      expect(result.role, WhatsAppAccountRole.bakeryMember);
    });
  });

  group('failure mapping', () {
    Future<OtpFailure> failureFor(OtpBackendException error) async {
      backend.queuedErrors.add(error);
      backend.response = FakeOtpBackend.sentResponse();
      try {
        await service.requestCode(phoneE164: '+919876543210');
      } on OtpException catch (caught) {
        return caught.failure;
      }
      fail('expected an OtpException');
    }

    test('prefers the backend reason over the transport code', () async {
      expect(
        await failureFor(
          OtpBackendException(code: 'resource-exhausted', reason: 'rate-limited'),
        ),
        OtpFailure.rateLimited,
      );
      expect(
        await failureFor(
          OtpBackendException(code: 'invalid-argument', reason: 'invalid-phone'),
        ),
        OtpFailure.invalidPhone,
      );
      expect(
        await failureFor(
          OtpBackendException(code: 'failed-precondition', reason: 'not-configured'),
        ),
        OtpFailure.notConfigured,
      );
    });

    test('falls back to the transport code when no reason is sent', () async {
      expect(
        await failureFor(OtpBackendException(code: 'unavailable')),
        OtpFailure.providerUnavailable,
      );
      expect(
        await failureFor(OtpBackendException(code: 'unauthenticated')),
        OtpFailure.unauthenticated,
      );
      expect(
        await failureFor(OtpBackendException(code: 'not-found')),
        OtpFailure.noAccount,
      );
      expect(
        await failureFor(OtpBackendException(code: 'already-exists')),
        OtpFailure.phoneInUse,
      );
      expect(
        await failureFor(OtpBackendException(code: 'malformed-response')),
        OtpFailure.unknown,
      );
    });

    test('keeps the retry delay so the screen can run its countdown', () async {
      backend.queuedErrors.add(
        OtpBackendException(
          code: 'resource-exhausted',
          reason: 'rate-limited',
          retryAfterSeconds: 42,
        ),
      );
      backend.response = FakeOtpBackend.sentResponse();

      await expectLater(
        service.requestCode(phoneE164: '+919876543210'),
        throwsA(
          isA<OtpException>()
              .having((OtpException e) => e.retryAfterSeconds, 'retry', 42)
              .having((OtpException e) => e.message, 'message', isNotEmpty),
        ),
      );
    });

    test('maps every reason the backend can send to a distinct failure', () {
      const Map<String, OtpFailure> expected = <String, OtpFailure>{
        'invalid-request': OtpFailure.invalidRequest,
        'invalid-phone': OtpFailure.invalidPhone,
        'invalid-code': OtpFailure.invalidCode,
        'code-expired': OtpFailure.codeExpired,
        'rate-limited': OtpFailure.rateLimited,
        'too-many-attempts': OtpFailure.tooManyAttempts,
        'no-account': OtpFailure.noAccount,
        'no-profile': OtpFailure.noProfile,
        'phone-in-use': OtpFailure.phoneInUse,
        'provider-unavailable': OtpFailure.providerUnavailable,
        'not-configured': OtpFailure.notConfigured,
        'unauthenticated': OtpFailure.unauthenticated,
      };

      expected.forEach((String reason, OtpFailure failure) {
        expect(OtpFailure.fromReason(reason), failure, reason: reason);
        expect(otpFailureMessage(failure), isNotEmpty, reason: reason);
      });

      expect(OtpFailure.fromReason('something-new'), OtpFailure.unknown);
      expect(OtpFailure.fromReason(null), OtpFailure.unknown);
    });
  });
}

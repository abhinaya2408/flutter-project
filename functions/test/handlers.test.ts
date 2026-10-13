import {describe, expect, it} from 'vitest';

import type {OtpReason} from '../src/errors';
import {requestWhatsAppOtp, verifyWhatsAppOtp} from '../src/handlers';
import type {ProviderCheckStatus} from '../src/ports';
import {makeHarness, type TestHarness} from './support';

const PHONE = '+919876543210';

function expectOtpFailure(promise: Promise<unknown>, reason: OtpReason) {
  return expect(promise).rejects.toMatchObject({name: 'OtpError', reason});
}

function harness(): TestHarness {
  return makeHarness();
}

/** A student account whose phone number is already on file. */
function withLinkedStudent(h: TestHarness, uid = 'student-1', phone = PHONE) {
  h.profiles.roles.set(uid, 'student');
  h.auth.addUser(uid, phone);
  return uid;
}

describe('requestWhatsAppOtp', () => {
  it('sends the code over WhatsApp and returns a masked challenge', async () => {
    const h = harness();
    const result = await requestWhatsAppOtp(h.deps, {phoneNumber: '9876543210'}, {});

    expect(result).toEqual({
      status: 'sent',
      channel: 'whatsapp',
      phoneMasked: '+91 ••••••3210',
      expiresInSeconds: 600,
      resendAfterSeconds: 60,
    });
    expect(h.provider.sends).toEqual([{phoneE164: PHONE}]);
  });

  it('rejects a phone number it cannot normalise without calling the provider', async () => {
    const h = harness();
    await expectOtpFailure(requestWhatsAppOtp(h.deps, {phoneNumber: 'not-a-number'}, {}), 'invalid-phone');
    expect(h.provider.sends).toHaveLength(0);
  });

  it('passes a valid locale through and ignores a junk one', async () => {
    const h = harness();
    await requestWhatsAppOtp(h.deps, {phoneNumber: PHONE, locale: 'en'}, {});
    expect(h.provider.sends[0]).toEqual({phoneE164: PHONE, locale: 'en'});

    const h2 = harness();
    await requestWhatsAppOtp(h2.deps, {phoneNumber: PHONE, locale: {evil: true}}, {});
    expect(h2.provider.sends[0]).toEqual({phoneE164: PHONE});
  });

  it('applies the cooldown between two requests for the same number', async () => {
    const h = harness();
    await requestWhatsAppOtp(h.deps, {phoneNumber: PHONE}, {});

    // retryAfter must tell the UI how long the resend countdown is.
    await expect(requestWhatsAppOtp(h.deps, {phoneNumber: PHONE}, {})).rejects.toMatchObject({
      name: 'OtpError',
      reason: 'rate-limited',
      details: {retryAfterSeconds: 60},
    });
    expect(h.provider.sends).toHaveLength(1);
  });

  it('caps repeated requests for the same number across the window', async () => {
    const h = harness();
    for (let i = 0; i < 3; i += 1) {
      await requestWhatsAppOtp(h.deps, {phoneNumber: PHONE}, {});
      h.clock.advance(61_000);
    }

    await expectOtpFailure(requestWhatsAppOtp(h.deps, {phoneNumber: PHONE}, {}), 'rate-limited');
    expect(h.provider.sends).toHaveLength(3);
  });

  it('caps requests from a single IP across many different numbers', async () => {
    const h = harness();
    for (let i = 0; i < 10; i += 1) {
      await requestWhatsAppOtp(h.deps, {phoneNumber: `+9198765432${String(i).padStart(2, '0')}`}, {ip: '203.0.113.7'});
    }

    await expectOtpFailure(
      requestWhatsAppOtp(h.deps, {phoneNumber: '+919876543299'}, {ip: '203.0.113.7'}),
      'rate-limited',
    );
    expect(h.provider.sends).toHaveLength(10);
  });

  it('does not apply the per-IP limit when no IP is available', async () => {
    const h = harness();
    for (let i = 0; i < 12; i += 1) {
      await requestWhatsAppOtp(h.deps, {phoneNumber: `+9198765432${String(i).padStart(2, '0')}`}, {});
    }
    expect(h.provider.sends).toHaveLength(12);
  });

  it('reports a provider outage instead of pretending the code was sent', async () => {
    const h = harness();
    h.provider.sendError = new Error('twilio down');
    await expectOtpFailure(requestWhatsAppOtp(h.deps, {phoneNumber: PHONE}, {}), 'provider-unavailable');
    expect(h.provider.sends).toHaveLength(0);
  });

  it('never reveals whether an account exists (no account enumeration)', async () => {
    const h = harness();
    const result = await requestWhatsAppOtp(
      h.deps,
      {phoneNumber: '+919000000000'},
      {},
    );
    // Same shape for a number with no account behind it.
    expect(result.status).toBe('sent');
    expect(JSON.stringify(result)).not.toContain('account');
  });
});

describe('verifyWhatsAppOtp — sign_in', () => {
  it('mints a custom token for the account that owns the number', async () => {
    const h = harness();
    const uid = withLinkedStudent(h);

    const result = await verifyWhatsAppOtp(
      h.deps,
      {phoneNumber: PHONE, code: '123456', intent: 'sign_in'},
      {},
    );

    expect(result).toEqual({
      status: 'signed_in',
      uid,
      role: 'student',
      phoneMasked: '+91 ••••••3210',
      customToken: `custom-token-for-${uid}`,
    });
    expect(h.auth.tokens).toEqual([{uid, token: `custom-token-for-${uid}`}]);
    expect(h.profiles.verifications).toHaveLength(1);
    expect(h.profiles.verifications[0]).toMatchObject({uid, role: 'student', method: 'sign_in'});
  });

  it('signs a bakery member in with the bakery role', async () => {
    const h = harness();
    h.profiles.roles.set('owner-1', 'bakery_member');
    h.auth.addUser('owner-1', PHONE);

    const result = await verifyWhatsAppOtp(h.deps, {phoneNumber: PHONE, code: '123456'}, {});

    expect(result.status).toBe('signed_in');
    expect(result.role).toBe('bakery_member');
  });

  it('defaults to sign_in when no intent is supplied', async () => {
    const h = harness();
    withLinkedStudent(h);
    const result = await verifyWhatsAppOtp(h.deps, {phoneNumber: PHONE, code: '123456'}, {});
    expect(result.status).toBe('signed_in');
  });

  it('refuses an unknown intent', async () => {
    const h = harness();
    await expectOtpFailure(
      verifyWhatsAppOtp(h.deps, {phoneNumber: PHONE, code: '123456', intent: 'promote_me'}, {}),
      'invalid-request',
    );
    expect(h.provider.checks).toHaveLength(0);
  });

  it('reports no-account only after the provider approved the code', async () => {
    const h = harness();

    const result = verifyWhatsAppOtp(h.deps, {phoneNumber: PHONE, code: '123456'}, {});
    await expectOtpFailure(result, 'no-account');
    expect(h.provider.checks).toHaveLength(1);
    expect(h.auth.tokens).toHaveLength(0);
  });

  it('refuses to issue a token for an account with no profile document', async () => {
    const h = harness();
    h.auth.addUser('ghost-1', PHONE); // an Auth user with no students/bakery_members doc

    await expectOtpFailure(
      verifyWhatsAppOtp(h.deps, {phoneNumber: PHONE, code: '123456'}, {}),
      'no-profile',
    );
    expect(h.auth.tokens).toHaveLength(0);
  });
});

describe('verifyWhatsAppOtp — link', () => {
  it('requires a verified caller identity', async () => {
    const h = harness();
    await expectOtpFailure(
      verifyWhatsAppOtp(h.deps, {phoneNumber: PHONE, code: '123456', intent: 'link'}, {}),
      'unauthenticated',
    );
    expect(h.provider.checks).toHaveLength(0);
  });

  it('attaches the number to the caller and marks the profile verified', async () => {
    const h = harness();
    h.profiles.roles.set('student-1', 'student');

    const result = await verifyWhatsAppOtp(
      h.deps,
      {phoneNumber: PHONE, code: '123456', intent: 'link'},
      {uid: 'student-1'},
    );

    expect(result).toEqual({
      status: 'linked',
      uid: 'student-1',
      role: 'student',
      phoneMasked: '+91 ••••••3210',
    });
    expect(result.customToken).toBeUndefined();
    expect(h.auth.attached).toEqual([{uid: 'student-1', phoneE164: PHONE}]);
    expect(h.auth.tokens).toHaveLength(0);
    expect(h.profiles.marks).toEqual([
      {
        uid: 'student-1',
        role: 'student',
        phoneE164: PHONE,
        phoneMasked: '+91 ••••••3210',
        method: 'link',
      },
    ]);
  });

  it('refuses a number that already belongs to another account', async () => {
    const h = harness();
    withLinkedStudent(h, 'student-1');
    h.profiles.roles.set('student-2', 'student');

    await expectOtpFailure(
      verifyWhatsAppOtp(
        h.deps,
        {phoneNumber: PHONE, code: '123456', intent: 'link'},
        {uid: 'student-2'},
      ),
      'phone-in-use',
    );
    expect(h.auth.attached).toHaveLength(0);
    expect(h.profiles.marks).toHaveLength(0);
  });

  it('is idempotent when the number is already this account\u2019s', async () => {
    const h = harness();
    const uid = withLinkedStudent(h);

    const result = await verifyWhatsAppOtp(
      h.deps,
      {phoneNumber: PHONE, code: '123456', intent: 'link'},
      {uid},
    );

    expect(result.status).toBe('linked');
    expect(h.auth.attached).toHaveLength(0);
    expect(h.profiles.marks).toHaveLength(1);
  });

  it('refuses to link for an account with no profile document', async () => {
    const h = harness();
    await expectOtpFailure(
      verifyWhatsAppOtp(
        h.deps,
        {phoneNumber: PHONE, code: '123456', intent: 'link'},
        {uid: 'nobody'},
      ),
      'no-profile',
    );
    expect(h.auth.attached).toHaveLength(0);
  });

  it('links a bakery member without ever touching a student role', async () => {
    const h = harness();
    h.profiles.roles.set('owner-1', 'bakery_member');

    await verifyWhatsAppOtp(
      h.deps,
      {phoneNumber: PHONE, code: '123456', intent: 'link'},
      {uid: 'owner-1'},
    );

    expect(h.profiles.marks[0]).toMatchObject({role: 'bakery_member'});
    // The port refuses any attempt to hand out the wrong role, on top of this.
    expect(h.profiles.roles.get('owner-1')).toBe('bakery_member');
  });

  it('never grants a role: a student stays a student', async () => {
    const h = harness();
    h.profiles.roles.set('student-1', 'student');

    await verifyWhatsAppOtp(
      h.deps,
      {phoneNumber: PHONE, code: '123456', intent: 'link'},
      {uid: 'student-1'},
    );

    expect([...h.profiles.roles.values()]).toEqual(['student']);
  });
});

describe('verifyWhatsAppOtp — code handling', () => {
  it('rejects a malformed code before spending a provider attempt', async () => {
    const h = harness();
    await expectOtpFailure(
      verifyWhatsAppOtp(h.deps, {phoneNumber: PHONE, code: '12'}, {}),
      'invalid-code',
    );
    expect(h.provider.checks).toHaveLength(0);
  });

  it('maps every provider outcome to the right reason', async () => {
    const cases: [string, OtpReason][] = [
      ['pending', 'invalid-code'],
      ['canceled', 'code-expired'],
      ['max_attempts_reached', 'too-many-attempts'],
    ];

    for (const [status, reason] of cases) {
      const h = harness();
      withLinkedStudent(h);
      h.provider.status = status as ProviderCheckStatus;
      await expectOtpFailure(verifyWhatsAppOtp(h.deps, {phoneNumber: PHONE, code: '123456'}, {}), reason);
      expect(h.auth.tokens).toHaveLength(0);
    }
  });

  it('throttles brute force: the sixth attempt never reaches the provider', async () => {
    const h = harness();
    withLinkedStudent(h);
    h.provider.status = 'pending';

    for (let i = 0; i < 5; i += 1) {
      await expectOtpFailure(
        verifyWhatsAppOtp(h.deps, {phoneNumber: PHONE, code: '000000'}, {}),
        'invalid-code',
      );
    }

    await expectOtpFailure(
      verifyWhatsAppOtp(h.deps, {phoneNumber: PHONE, code: '000000'}, {}),
      'too-many-attempts',
    );
    expect(h.provider.checks).toHaveLength(5);
  });

  it('never echoes the submitted code back to the client', async () => {
    const h = harness();
    withLinkedStudent(h);

    const result = await verifyWhatsAppOtp(h.deps, {phoneNumber: PHONE, code: '424242'}, {});
    expect(JSON.stringify(result)).not.toContain('424242');
  });
});

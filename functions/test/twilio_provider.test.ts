import {describe, expect, it, vi} from 'vitest';

import type {TwilioCredentials} from '../src/config';
import {OtpError} from '../src/errors';
import {TwilioVerifyProvider} from '../src/providers/twilio';

const SERVICE_SID = `VA${'a'.repeat(32)}`;
const ACCOUNT_SID = `AC${'0'.repeat(32)}`;

const credentials: TwilioCredentials = {
  accountSid: ACCOUNT_SID,
  authToken: 'super-secret-auth-token',
  verifyServiceSid: SERVICE_SID,
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {'Content-Type': 'application/json'},
  });
}

function captureFetch(response: Response) {
  return vi.fn(async (_url: string, _init?: RequestInit) => response);
}

describe('TwilioVerifyProvider.send', () => {
  it('posts a WhatsApp verification with the expected URL, auth and body', async () => {
    const fetchImpl = captureFetch(jsonResponse({status: 'pending', sid: 'VE123'}));
    const provider = new TwilioVerifyProvider(credentials, fetchImpl);

    await provider.send({phoneE164: '+919876543210', locale: 'en'});

    expect(fetchImpl).toHaveBeenCalledTimes(1);
    const [url, init] = fetchImpl.mock.calls[0]!;

    expect(url).toBe(`https://verify.twilio.com/v2/Services/${SERVICE_SID}/Verifications`);
    expect(init?.method).toBe('POST');
    expect(init?.headers).toMatchObject({'Content-Type': 'application/x-www-form-urlencoded'});

    const authorization = (init?.headers as Record<string, string>)['Authorization']!;
    expect(authorization.startsWith('Basic ')).toBe(true);
    expect(Buffer.from(authorization.slice('Basic '.length), 'base64').toString('utf8')).toBe(
      `${ACCOUNT_SID}:super-secret-auth-token`,
    );

    const body = new URLSearchParams(init?.body as string);
    expect(body.get('To')).toBe('+919876543210');
    expect(body.get('Channel')).toBe('whatsapp');
    expect(body.get('Locale')).toBe('en');
  });

  it('uses the API key pair when one is configured', async () => {
    const fetchImpl = captureFetch(jsonResponse({status: 'pending'}));
    const provider = new TwilioVerifyProvider(
      {
        accountSid: ACCOUNT_SID,
        apiKey: 'SKit-is-an-api-key',
        apiSecret: 'api-secret',
        verifyServiceSid: SERVICE_SID,
      },
      fetchImpl,
    );

    await provider.send({phoneE164: '+919876543210'});

    const [, init] = fetchImpl.mock.calls[0]!;
    const authorization = (init?.headers as Record<string, string>)['Authorization']!;
    expect(Buffer.from(authorization.slice('Basic '.length), 'base64').toString('utf8')).toBe(
      'SKit-is-an-api-key:api-secret',
    );

    // No locale set and no SMS fallback channel.
    const body = new URLSearchParams(init?.body as string);
    expect(body.get('Locale')).toBeNull();
    expect(body.get('Channel')).toBe('whatsapp');
  });
});

describe('TwilioVerifyProvider.check', () => {
  async function checkWith(status: string) {
    const fetchImpl = captureFetch(jsonResponse({status}));
    const provider = new TwilioVerifyProvider(credentials, fetchImpl);
    return {result: await provider.check({phoneE164: '+919876543210', code: '123456'}), fetchImpl};
  }

  it('maps approved, pending, canceled and max_attempts_reached', async () => {
    expect((await checkWith('approved')).result).toBe('approved');
    expect((await checkWith('pending')).result).toBe('pending');
    expect((await checkWith('canceled')).result).toBe('canceled');
    expect((await checkWith('max_attempts_reached')).result).toBe('max_attempts_reached');
  });

  it('posts the code to the VerificationCheck endpoint', async () => {
    const {fetchImpl} = await checkWith('approved');
    const [url, init] = fetchImpl.mock.calls[0]!;
    expect(url).toBe(`https://verify.twilio.com/v2/Services/${SERVICE_SID}/VerificationCheck`);
    const body = new URLSearchParams(init?.body as string);
    expect(body.get('To')).toBe('+919876543210');
    expect(body.get('Code')).toBe('123456');
  });

  it('treats an unknown provider status as a failure, never a success', async () => {
    const fetchImpl = captureFetch(jsonResponse({status: 'something_new'}));
    const provider = new TwilioVerifyProvider(credentials, fetchImpl);

    await expect(
      provider.check({phoneE164: '+919876543210', code: '123456'}),
    ).rejects.toMatchObject({reason: 'provider-unavailable'});
  });
});

describe('TwilioVerifyProvider failures', () => {
  async function failure(response: Response) {
    const fetchImpl = captureFetch(response);
    const provider = new TwilioVerifyProvider(credentials, fetchImpl);
    return provider.send({phoneE164: '+919876543210'}).catch((error: unknown) => error);
  }

  it('maps a rejected credential to a configuration error', async () => {
    const error = await failure(jsonResponse({code: 20003, message: 'Authenticate'}, 401));
    expect(error).toBeInstanceOf(OtpError);
    expect((error as OtpError).reason).toBe('not-configured');
  });

  it('maps an unusable phone number to invalid-phone', async () => {
    const error = await failure(jsonResponse({code: 60200, message: 'Invalid parameter'}, 400));
    expect((error as OtpError).reason).toBe('invalid-phone');
  });

  it('maps a server error to provider-unavailable', async () => {
    const error = await failure(jsonResponse({code: 20500, message: 'Internal error'}, 500));
    expect((error as OtpError).reason).toBe('provider-unavailable');
  });

  it('maps a network failure or timeout to provider-unavailable', async () => {
    const fetchImpl = vi.fn(async () => {
      throw new Error('ECONNRESET');
    });
    const provider = new TwilioVerifyProvider(credentials, fetchImpl);
    const error = await provider
      .send({phoneE164: '+919876543210'})
      .catch((thrown: unknown) => thrown);

    expect((error as OtpError).reason).toBe('provider-unavailable');
  });

  it('never puts the credential or the phone number in the error details', async () => {
    const error = (await failure(
      jsonResponse({code: 20003, message: 'Authenticate'}, 401),
    )) as OtpError;

    const serialised = JSON.stringify(error.details);
    expect(serialised).not.toContain('super-secret-auth-token');
    expect(serialised).not.toContain('9876543210');
    expect(JSON.stringify(error.message)).not.toContain('super-secret-auth-token');
  });
});

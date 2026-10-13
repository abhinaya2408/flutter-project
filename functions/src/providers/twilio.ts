/**
 * Twilio Verify provider — WhatsApp channel.
 *
 * Twilio generates and verifies the one-time passcode. This code never creates,
 * stores, compares or logs a code itself: it only asks Twilio to send one and
 * asks Twilio whether a supplied code is correct. That is what keeps brute
 * force protection, attempt counting and expiry in the provider's hands.
 *
 * Endpoints (REST, form-encoded, HTTP Basic auth):
 *   POST /v2/Services/{VerifyServiceSid}/Verifications      {To, Channel, Locale}
 *   POST /v2/Services/{VerifyServiceSid}/VerificationCheck  {To, Code}
 * Docs: https://www.twilio.com/docs/verify/api
 */

import type {TwilioCredentials} from '../config';
import {OtpError} from '../errors';
import type {ProviderCheckStatus, VerificationProvider} from '../ports';

const TWILIO_API_BASE = 'https://verify.twilio.com/v2/Services';
const REQUEST_TIMEOUT_MS = 10_000;

/** Twilio error codes that mean "this is not a usable phone number". */
const TWILIO_INVALID_PHONE_CODES = new Set<number>([21211, 21214, 21217, 21614, 60200]);
const TWILIO_AUTH_CODES = new Set<number>([20003, 20005, 20404]);
/** How long we tell the client the code is good for (Twilio's own default). */
const DEFAULT_CODE_TTL_SECONDS = 600;

type FetchLike = (input: string, init?: RequestInit) => Promise<Response>;

interface TwilioErrorBody {
  code?: number;
  message?: string;
  status?: number;
}

export class TwilioVerifyProvider implements VerificationProvider {
  readonly name = 'twilio';
  readonly channel = 'whatsapp';

  private readonly credentials: TwilioCredentials;
  private readonly fetchImpl: FetchLike;

  constructor(credentials: TwilioCredentials, fetchImpl: FetchLike = globalThis.fetch) {
    this.credentials = credentials;
    this.fetchImpl = fetchImpl;
  }

  async send(input: {phoneE164: string; locale?: string}): Promise<void> {
    const body = new URLSearchParams({
      To: input.phoneE164,
      // WhatsApp only — this app never silently falls back to SMS.
      Channel: 'whatsapp',
    });
    if (input.locale) body.set('Locale', input.locale);

    await this.post('Verifications', body);
  }

  async check(input: {phoneE164: string; code: string}): Promise<ProviderCheckStatus> {
    const body = new URLSearchParams({
      To: input.phoneE164,
      Code: input.code,
    });

    const payload = await this.post('VerificationCheck', body);
    const status = payload['status'];

    switch (status) {
      case 'approved':
        return 'approved';
      case 'pending':
        return 'pending';
      case 'canceled':
        return 'canceled';
      case 'max_attempts_reached':
        return 'max_attempts_reached';
      default:
        // An unrecognised status must never read as success.
        throw new OtpError('provider-unavailable', {provider: this.name});
    }
  }

  /** Exposed for the client's "code expires in" copy. */
  get codeTtlSeconds(): number {
    return DEFAULT_CODE_TTL_SECONDS;
  }

  private async post(path: string, body: URLSearchParams): Promise<Record<string, unknown>> {
    const url = `${TWILIO_API_BASE}/${this.credentials.verifyServiceSid}/${path}`;

    let response: Response;
    try {
      response = await this.fetchImpl(url, {
        method: 'POST',
        headers: {
          Authorization: `Basic ${this.basicAuth()}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body.toString(),
        signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
      });
    } catch {
      // Network failure or timeout. The URL is redacted from the message so a
      // phone number never lands in a log line.
      throw new OtpError('provider-unavailable', {provider: this.name});
    }

    const payload = await this.readJson(response);

    if (!response.ok) {
      const providerCode = typeof payload['code'] === 'number' ? (payload['code'] as number) : 0;

      if (TWILIO_INVALID_PHONE_CODES.has(providerCode)) {
        throw new OtpError('invalid-phone', {provider: this.name, providerCode});
      }
      if (response.status === 401 || response.status === 403 || TWILIO_AUTH_CODES.has(providerCode)) {
        // Credentials or the Verify Service SID are wrong — a server
        // configuration problem, not the user's.
        console.error(`twilio: authentication/configuration rejected (code ${providerCode}).`);
        throw new OtpError('not-configured', {provider: this.name, providerCode});
      }

      console.error(`twilio: request failed (http ${response.status}, code ${providerCode}).`);
      throw new OtpError('provider-unavailable', {provider: this.name, providerCode});
    }

    return payload;
  }

  private basicAuth(): string {
    const {accountSid, apiKey, apiSecret, authToken} = this.credentials;
    // Twilio accepts either an API Key/Secret pair or the account SID/Auth Token.
    const username = apiKey ?? accountSid;
    const password = apiSecret ?? authToken ?? '';
    return Buffer.from(`${username}:${password}`, 'utf8').toString('base64');
  }

  private async readJson(response: Response): Promise<Record<string, unknown>> {
    try {
      const text = await response.text();
      if (text.trim() === '') return {};
      const parsed: unknown = JSON.parse(text);
      return parsed !== null && typeof parsed === 'object'
        ? (parsed as Record<string, unknown>)
        : {};
    } catch {
      return {};
    }
  }
}

/** Re-exported so handlers and tests share one source of truth. */
export const twilioCodeTtlSeconds = DEFAULT_CODE_TTL_SECONDS;

export type {TwilioErrorBody};

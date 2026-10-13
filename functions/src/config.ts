/**
 * Backend configuration for the WhatsApp OTP flow.
 *
 * Everything in here is server-only. None of these values may ever be shipped
 * inside the Flutter client: the Flutter app knows only the callable Function
 * names and the region.
 */

export type OtpProviderName = 'twilio' | 'mock';

export interface SendLimits {
  /** Max code requests per phone number inside `windowMs`. */
  perPhoneLimit: number;
  perPhoneWindowMs: number;
  /** Minimum gap between two code requests for the same phone number. */
  perPhoneCooldownMs: number;
  /** Max code requests from one IP address inside `windowMs`. */
  perIpLimit: number;
  perIpWindowMs: number;
}

export interface VerifyLimits {
  /** Max code-check attempts per phone number inside `windowMs`. */
  perPhoneLimit: number;
  perPhoneWindowMs: number;
}

export interface TwilioCredentials {
  accountSid: string;
  /** Present when the deployment uses an API Key/Secret pair instead. */
  apiKey?: string;
  apiSecret?: string;
  /** Present when the deployment uses the account Auth Token instead. */
  authToken?: string;
  verifyServiceSid: string;
}

export interface OtpConfig {
  provider: OtpProviderName;
  region: string;
  defaultCountryCode: string;
  locale?: string;
  enforceAppCheck: boolean;
  send: SendLimits;
  verify: VerifyLimits;
  /** How long the code stays valid, for the client-side "code expires" copy. */
  codeTtlSeconds: number;
  /** Emulator-only mock provider code. Never set in production. */
  mockCode?: string;
  twilio?: TwilioCredentials;
}

/** Raised when the backend is started without usable configuration. */
export class ConfigurationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ConfigurationError';
  }
}

const SID_ACCOUNT = /^AC[0-9a-fA-F]{32}$/;
const SID_VERIFY_SERVICE = /^VA[0-9a-fA-F]{32}$/;
const E164_PREFIX = /^\+[1-9]\d{0,3}$/;

function readInt(
  env: NodeJS.ProcessEnv,
  key: string,
  fallback: number,
  {min = 1, max = 100000}: {min?: number; max?: number} = {},
): number {
  const raw = env[key];
  if (raw === undefined || raw.trim() === '') return fallback;
  const value = Number.parseInt(raw, 10);
  if (!Number.isFinite(value) || value < min || value > max) {
    throw new ConfigurationError(`${key} must be an integer between ${min} and ${max}.`);
  }
  return value;
}

function readBool(env: NodeJS.ProcessEnv, key: string, fallback: boolean): boolean {
  const raw = env[key];
  if (raw === undefined || raw.trim() === '') return fallback;
  return raw.trim().toLowerCase() === 'true';
}

/**
 * The mock provider exists so the flow can be exercised in the Firebase
 * emulator without spending money or messaging anyone. It is deliberately
 * unreachable in a deployed Function: the runtime sets neither
 * `FUNCTIONS_EMULATOR` nor `NODE_ENV=test` there.
 */
export function isMockProviderAllowed(env: NodeJS.ProcessEnv): boolean {
  return env.FUNCTIONS_EMULATOR === 'true' || env.NODE_ENV === 'test';
}

/**
 * Options that must be known when the Function is *defined* (before any request
 * arrives), so they are read straight from the environment rather than from the
 * lazily validated [loadConfig].
 */
export function runtimeOptions(env: NodeJS.ProcessEnv = process.env): {
  region: string;
  enforceAppCheck: boolean;
} {
  const region = (env.OTP_FUNCTIONS_REGION ?? 'us-central1').trim();
  return {
    region: region === '' ? 'us-central1' : region,
    enforceAppCheck: readBool(env, 'OTP_ENFORCE_APP_CHECK', false),
  };
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): OtpConfig {
  const provider = (env.OTP_PROVIDER ?? 'twilio').trim().toLowerCase();
  if (provider !== 'twilio' && provider !== 'mock') {
    throw new ConfigurationError('OTP_PROVIDER must be `twilio` or `mock`.');
  }

  const defaultCountryCode = (env.OTP_DEFAULT_COUNTRY_CODE ?? '+91').trim();
  if (!E164_PREFIX.test(defaultCountryCode)) {
    throw new ConfigurationError('OTP_DEFAULT_COUNTRY_CODE must look like `+91`.');
  }

  const region = (env.OTP_FUNCTIONS_REGION ?? 'us-central1').trim();
  if (region === '') throw new ConfigurationError('OTP_FUNCTIONS_REGION must not be empty.');

  const config: OtpConfig = {
    provider,
    region,
    defaultCountryCode,
    enforceAppCheck: readBool(env, 'OTP_ENFORCE_APP_CHECK', false),
    codeTtlSeconds: readInt(env, 'OTP_CODE_TTL_SECONDS', 600, {min: 60, max: 3600}),
    send: {
      perPhoneLimit: readInt(env, 'OTP_SEND_PER_PHONE_LIMIT', 3, {min: 1, max: 50}),
      perPhoneWindowMs:
        readInt(env, 'OTP_SEND_PER_PHONE_WINDOW_SECONDS', 900, {min: 60, max: 86400}) * 1000,
      perPhoneCooldownMs:
        readInt(env, 'OTP_SEND_COOLDOWN_SECONDS', 60, {min: 0, max: 3600}) * 1000,
      perIpLimit: readInt(env, 'OTP_SEND_PER_IP_LIMIT', 10, {min: 1, max: 500}),
      perIpWindowMs:
        readInt(env, 'OTP_SEND_PER_IP_WINDOW_SECONDS', 3600, {min: 60, max: 86400}) * 1000,
    },
    verify: {
      perPhoneLimit: readInt(env, 'OTP_VERIFY_PER_PHONE_LIMIT', 5, {min: 1, max: 50}),
      perPhoneWindowMs:
        readInt(env, 'OTP_VERIFY_PER_PHONE_WINDOW_SECONDS', 600, {min: 60, max: 86400}) * 1000,
    },
  };

  const locale = env.OTP_LOCALE?.trim();
  if (locale) config.locale = locale;

  if (provider === 'mock') {
    if (!isMockProviderAllowed(env)) {
      throw new ConfigurationError(
        'OTP_PROVIDER=mock is only allowed in the Firebase emulator or in tests. ' +
          'Deployed Functions must use OTP_PROVIDER=twilio.',
      );
    }
    const mockCode = env.OTP_MOCK_CODE?.trim();
    if (!mockCode || !/^\d{6}$/.test(mockCode)) {
      throw new ConfigurationError(
        'OTP_PROVIDER=mock requires OTP_MOCK_CODE to be set to a 6-digit value.',
      );
    }
    config.mockCode = mockCode;
    return config;
  }

  const accountSid = env.TWILIO_ACCOUNT_SID?.trim() ?? '';
  const verifyServiceSid = env.TWILIO_VERIFY_SERVICE_SID?.trim() ?? '';
  const apiKey = env.TWILIO_API_KEY?.trim();
  const apiSecret = env.TWILIO_API_SECRET?.trim();
  const authToken = env.TWILIO_AUTH_TOKEN?.trim();

  if (!SID_ACCOUNT.test(accountSid)) {
    throw new ConfigurationError('TWILIO_ACCOUNT_SID is missing or malformed.');
  }
  if (!SID_VERIFY_SERVICE.test(verifyServiceSid)) {
    throw new ConfigurationError('TWILIO_VERIFY_SERVICE_SID is missing or malformed.');
  }
  if (apiKey && !apiSecret) {
    throw new ConfigurationError('TWILIO_API_KEY is set but TWILIO_API_SECRET is missing.');
  }
  if (!apiKey && !authToken) {
    throw new ConfigurationError(
      'Set either TWILIO_API_KEY + TWILIO_API_SECRET, or TWILIO_AUTH_TOKEN.',
    );
  }

  const twilio: TwilioCredentials = {accountSid, verifyServiceSid};
  if (apiKey && apiSecret) {
    twilio.apiKey = apiKey;
    twilio.apiSecret = apiSecret;
  } else if (authToken) {
    twilio.authToken = authToken;
  }
  config.twilio = twilio;

  return config;
}

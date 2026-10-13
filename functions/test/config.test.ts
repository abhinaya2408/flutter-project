import {describe, expect, it} from 'vitest';

import {ConfigurationError, isMockProviderAllowed, loadConfig, runtimeOptions} from '../src/config';

const ACCOUNT_SID = `AC${'0'.repeat(32)}`;
const SERVICE_SID = `VA${'a'.repeat(32)}`;

function twilioEnv(extra: Record<string, string> = {}): NodeJS.ProcessEnv {
  return {
    OTP_PROVIDER: 'twilio',
    TWILIO_ACCOUNT_SID: ACCOUNT_SID,
    TWILIO_AUTH_TOKEN: 'auth-token-value',
    TWILIO_VERIFY_SERVICE_SID: SERVICE_SID,
    ...extra,
  };
}

describe('loadConfig', () => {
  it('defaults to the twilio provider with sane limits', () => {
    const config = loadConfig(twilioEnv());

    expect(config.provider).toBe('twilio');
    expect(config.defaultCountryCode).toBe('+91');
    expect(config.region).toBe('us-central1');
    expect(config.enforceAppCheck).toBe(false);
    expect(config.send.perPhoneLimit).toBe(3);
    expect(config.send.perPhoneCooldownMs).toBe(60_000);
    expect(config.verify.perPhoneLimit).toBe(5);
    expect(config.twilio?.accountSid).toBe(ACCOUNT_SID);
    expect(config.twilio?.verifyServiceSid).toBe(SERVICE_SID);
  });

  it('accepts an API key/secret pair instead of an auth token', () => {
    const config = loadConfig({
      OTP_PROVIDER: 'twilio',
      TWILIO_ACCOUNT_SID: ACCOUNT_SID,
      TWILIO_VERIFY_SERVICE_SID: SERVICE_SID,
      TWILIO_API_KEY: 'SK123',
      TWILIO_API_SECRET: 'secret',
    });

    expect(config.twilio?.apiKey).toBe('SK123');
    expect(config.twilio?.authToken).toBeUndefined();
  });

  it('refuses an API key without its secret', () => {
    expect(() =>
      loadConfig({
        OTP_PROVIDER: 'twilio',
        TWILIO_ACCOUNT_SID: ACCOUNT_SID,
        TWILIO_VERIFY_SERVICE_SID: SERVICE_SID,
        TWILIO_API_KEY: 'SK123',
      }),
    ).toThrow(ConfigurationError);
  });

  it('refuses an auth token and no API key at all', () => {
    expect(() =>
      loadConfig({
        OTP_PROVIDER: 'twilio',
        TWILIO_ACCOUNT_SID: ACCOUNT_SID,
        TWILIO_VERIFY_SERVICE_SID: SERVICE_SID,
      }),
    ).toThrow(ConfigurationError);
  });

  it('refuses malformed SIDs', () => {
    expect(() => loadConfig(twilioEnv({TWILIO_ACCOUNT_SID: 'nope'}))).toThrow(ConfigurationError);
    expect(() => loadConfig(twilioEnv({TWILIO_VERIFY_SERVICE_SID: 'AC123'}))).toThrow(
      ConfigurationError,
    );
  });

  it('refuses an invalid default country code or provider name', () => {
    expect(() => loadConfig(twilioEnv({OTP_DEFAULT_COUNTRY_CODE: '91'}))).toThrow(
      ConfigurationError,
    );
    expect(() => loadConfig(twilioEnv({OTP_PROVIDER: 'sms'}))).toThrow(ConfigurationError);
  });

  it('honours rate-limit overrides and rejects nonsense values', () => {
    const config = loadConfig(
      twilioEnv({
        OTP_SEND_PER_PHONE_LIMIT: '7',
        OTP_SEND_COOLDOWN_SECONDS: '30',
        OTP_VERIFY_PER_PHONE_WINDOW_SECONDS: '120',
      }),
    );
    expect(config.send.perPhoneLimit).toBe(7);
    expect(config.send.perPhoneCooldownMs).toBe(30_000);
    expect(config.verify.perPhoneWindowMs).toBe(120_000);

    expect(() => loadConfig(twilioEnv({OTP_SEND_PER_PHONE_LIMIT: '0'}))).toThrow(ConfigurationError);
    expect(() => loadConfig(twilioEnv({OTP_SEND_PER_PHONE_LIMIT: 'lots'}))).toThrow(
      ConfigurationError,
    );
  });

  it('refuses the mock provider outside the emulator or tests', () => {
    expect(() =>
      loadConfig({OTP_PROVIDER: 'mock', OTP_MOCK_CODE: '111111'}),
    ).toThrow(/emulator/i);
  });

  it('allows the mock provider in the emulator, but only with an explicit code', () => {
    expect(() =>
      loadConfig({OTP_PROVIDER: 'mock', FUNCTIONS_EMULATOR: 'true'}),
    ).toThrow(/OTP_MOCK_CODE/);

    const config = loadConfig({
      OTP_PROVIDER: 'mock',
      FUNCTIONS_EMULATOR: 'true',
      OTP_MOCK_CODE: '246810',
    });
    expect(config.provider).toBe('mock');
    expect(config.mockCode).toBe('246810');
    // No Twilio credentials are required for the emulator path.
    expect(config.twilio).toBeUndefined();
  });

  it('allows the mock provider under NODE_ENV=test', () => {
    const config = loadConfig({
      OTP_PROVIDER: 'mock',
      NODE_ENV: 'test',
      OTP_MOCK_CODE: '246810',
    });
    expect(config.provider).toBe('mock');
  });
});

describe('isMockProviderAllowed', () => {
  it('is false for a deployed runtime', () => {
    expect(isMockProviderAllowed({})).toBe(false);
    expect(isMockProviderAllowed({OTP_PROVIDER: 'mock'})).toBe(false);
  });

  it('is true only for the emulator or tests', () => {
    expect(isMockProviderAllowed({FUNCTIONS_EMULATOR: 'true'})).toBe(true);
    expect(isMockProviderAllowed({NODE_ENV: 'test'})).toBe(true);
  });
});

describe('runtimeOptions', () => {
  it('has deployable defaults', () => {
    expect(runtimeOptions({})).toEqual({region: 'us-central1', enforceAppCheck: false});
  });

  it('reads the region and App Check flag from the environment', () => {
    expect(
      runtimeOptions({OTP_FUNCTIONS_REGION: 'asia-south1', OTP_ENFORCE_APP_CHECK: 'true'}),
    ).toEqual({region: 'asia-south1', enforceAppCheck: true});
  });
});

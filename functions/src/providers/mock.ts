/**
 * Emulator-only mock provider.
 *
 * This exists purely so `firebase emulators:start` can exercise the client flow
 * without sending real WhatsApp messages. It is gated three times and cannot
 * accidentally protect a production deployment:
 *
 *   1. `OTP_PROVIDER=mock` must be set explicitly (the default is `twilio`);
 *   2. `loadConfig` refuses it unless `FUNCTIONS_EMULATOR=true` or
 *      `NODE_ENV=test`, neither of which is set in a deployed Function;
 *   3. it will not construct at all unless `OTP_MOCK_CODE` is an explicit
 *      6-digit value — there is no built-in default code.
 *
 * It never logs or returns the code.
 */

import {ConfigurationError, isMockProviderAllowed} from '../config';
import {OtpError} from '../errors';
import type {ProviderCheckStatus, VerificationProvider} from '../ports';

const MAX_ATTEMPTS = 5;

export class MockVerificationProvider implements VerificationProvider {
  readonly name = 'mock';
  readonly channel = 'whatsapp';

  private readonly code: string;
  private readonly attempts = new Map<string, number>();

  constructor(env: NodeJS.ProcessEnv = process.env) {
    if (!isMockProviderAllowed(env)) {
      // Belt and braces: never constructable inside a deployed Function.
      throw new ConfigurationError(
        'The mock WhatsApp provider can only run in the Firebase emulator or in tests.',
      );
    }
    const code = env.OTP_MOCK_CODE?.trim() ?? '';
    if (!/^\d{6}$/.test(code)) {
      throw new ConfigurationError('OTP_MOCK_CODE must be an explicit 6-digit value.');
    }
    this.code = code;
  }

  async send(_input: {phoneE164: string; locale?: string}): Promise<void> {
    // No network call, no code stored anywhere.
  }

  async check(input: {phoneE164: string; code: string}): Promise<ProviderCheckStatus> {
    const used = (this.attempts.get(input.phoneE164) ?? 0) + 1;
    this.attempts.set(input.phoneE164, used);
    if (used > MAX_ATTEMPTS) return 'max_attempts_reached';
    return input.code === this.code ? 'approved' : 'pending';
  }
}

/** Guards the emulator path in the same style as the real provider. */
export function assertMockProviderUsable(env: NodeJS.ProcessEnv = process.env): void {
  if (!isMockProviderAllowed(env)) {
    throw new OtpError('not-configured', {provider: 'mock'});
  }
}

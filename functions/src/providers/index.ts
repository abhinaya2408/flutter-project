/**
 * Provider selection. `twilio` is the default and the only production option.
 */

import type {OtpConfig} from '../config';
import {ConfigurationError} from '../config';
import type {VerificationProvider} from '../ports';
import {MockVerificationProvider} from './mock';
import {TwilioVerifyProvider} from './twilio';

export function createProvider(
  config: OtpConfig,
  env: NodeJS.ProcessEnv = process.env,
): VerificationProvider {
  if (config.provider === 'mock') {
    return new MockVerificationProvider(env);
  }
  if (!config.twilio) {
    throw new ConfigurationError('Twilio credentials are missing from the configuration.');
  }
  return new TwilioVerifyProvider(config.twilio);
}

export {MockVerificationProvider, TwilioVerifyProvider};

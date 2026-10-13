import {describe, expect, it} from 'vitest';

import {isValidCodeFormat, maskPhone, normalizeToE164} from '../src/phone';

describe('normalizeToE164', () => {
  it('accepts an already international number', () => {
    expect(normalizeToE164('+919876543210', '+91')).toBe('+919876543210');
  });

  it('strips spaces, dashes, dots and brackets', () => {
    expect(normalizeToE164('+91 98765-43210', '+91')).toBe('+919876543210');
    expect(normalizeToE164('(987) 654.3210', '+91')).toBe('+919876543210');
  });

  it('prepends the default country code to a national number', () => {
    expect(normalizeToE164('9876543210', '+91')).toBe('+919876543210');
    expect(normalizeToE164('7911123456', '+44')).toBe('+447911123456');
  });

  it('handles a leading trunk zero', () => {
    expect(normalizeToE164('09876543210', '+91')).toBe('+919876543210');
    expect(normalizeToE164('07911123456', '+44')).toBe('+447911123456');
  });

  it('handles a 00 international prefix', () => {
    expect(normalizeToE164('00919876543210', '+91')).toBe('+919876543210');
  });

  it('rejects a 00 prefix followed by a trunk zero, rather than guessing', () => {
    // `00` already means "international"; a leftover trunk zero makes the
    // value ambiguous, so it is refused instead of silently rewritten.
    expect(normalizeToE164('0009876543210', '+91')).toBeNull();
  });

  it('treats a long digit-only value as international', () => {
    expect(normalizeToE164('919876543210', '+91')).toBe('+919876543210');
  });

  it('rejects input that cannot be a phone number', () => {
    expect(normalizeToE164('', '+91')).toBeNull();
    expect(normalizeToE164('   ', '+91')).toBeNull();
    expect(normalizeToE164('abcdefghij', '+91')).toBeNull();
    expect(normalizeToE164('+91 98765 4321x', '+91')).toBeNull();
    expect(normalizeToE164('123', '+91')).toBeNull();
    expect(normalizeToE164('+0123456789', '+91')).toBeNull();
    expect(normalizeToE164('+1234567890123456', '+91')).toBeNull();
  });

  it('rejects non-string input', () => {
    expect(normalizeToE164(9876543210, '+91')).toBeNull();
    expect(normalizeToE164(undefined, '+91')).toBeNull();
    expect(normalizeToE164({}, '+91')).toBeNull();
  });
});

describe('maskPhone', () => {
  it('keeps the country code and the last four digits', () => {
    expect(maskPhone('+919876543210')).toBe('+91 ••••••3210');
  });

  it('handles a single-digit country code', () => {
    expect(maskPhone('+14155552671')).toBe('+1 ••••••2671');
  });

  it('never returns more digits than it was given', () => {
    const masked = maskPhone('+919876543210');
    expect(masked.replace(/\D/g, '').length).toBe(6); // 91 + 3210
  });

  it('degrades safely for very short values', () => {
    expect(maskPhone('+12')).toBe('••');
  });
});

describe('isValidCodeFormat', () => {
  it('accepts exactly six digits', () => {
    expect(isValidCodeFormat('123456')).toBe(true);
    expect(isValidCodeFormat('000000')).toBe(true);
  });

  it('rejects everything else', () => {
    expect(isValidCodeFormat('12345')).toBe(false);
    expect(isValidCodeFormat('1234567')).toBe(false);
    expect(isValidCodeFormat('12345a')).toBe(false);
    expect(isValidCodeFormat('')).toBe(false);
    expect(isValidCodeFormat(123456)).toBe(false);
    expect(isValidCodeFormat(undefined)).toBe(false);
  });
});

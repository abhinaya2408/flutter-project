/// Country dial codes offered by the WhatsApp verification screen.
///
/// Deliberately a short, explicit list rather than every calling code in the
/// world: the app is a single-college product and a curated list stays
/// searchable on a phone keyboard. India is first because it is the default.
class CountryDialCode {
  const CountryDialCode({
    required this.name,
    required this.isoCode,
    required this.dialCode,
    required this.flag,
  });

  /// Display name, e.g. `India`.
  final String name;

  /// ISO 3166-1 alpha-2, e.g. `IN`.
  final String isoCode;

  /// E.164 prefix, e.g. `+91`.
  final String dialCode;

  /// Emoji flag, used as a lightweight visual marker.
  final String flag;

  /// `🇮🇳 India (+91)`
  String get label => '$flag $name ($dialCode)';
}

/// The default when nothing else is chosen — matches `Validators.collegeEmailDomain`
/// and the 10-digit national numbers the app already stores.
const CountryDialCode kDefaultCountry = CountryDialCode(
  name: 'India',
  isoCode: 'IN',
  dialCode: '+91',
  flag: '🇮🇳',
);

const List<CountryDialCode> kCountryDialCodes = <CountryDialCode>[
  kDefaultCountry,
  CountryDialCode(name: 'United Arab Emirates', isoCode: 'AE', dialCode: '+971', flag: '🇦🇪'),
  CountryDialCode(name: 'Australia', isoCode: 'AU', dialCode: '+61', flag: '🇦🇺'),
  CountryDialCode(name: 'Bangladesh', isoCode: 'BD', dialCode: '+880', flag: '🇧🇩'),
  CountryDialCode(name: 'Bahrain', isoCode: 'BH', dialCode: '+973', flag: '🇧🇭'),
  CountryDialCode(name: 'Canada', isoCode: 'CA', dialCode: '+1', flag: '🇨🇦'),
  CountryDialCode(name: 'Germany', isoCode: 'DE', dialCode: '+49', flag: '🇩🇪'),
  CountryDialCode(name: 'France', isoCode: 'FR', dialCode: '+33', flag: '🇫🇷'),
  CountryDialCode(name: 'United Kingdom', isoCode: 'GB', dialCode: '+44', flag: '🇬🇧'),
  CountryDialCode(name: 'Indonesia', isoCode: 'ID', dialCode: '+62', flag: '🇮🇩'),
  CountryDialCode(name: 'Ireland', isoCode: 'IE', dialCode: '+353', flag: '🇮🇪'),
  CountryDialCode(name: 'Italy', isoCode: 'IT', dialCode: '+39', flag: '🇮🇹'),
  CountryDialCode(name: 'Japan', isoCode: 'JP', dialCode: '+81', flag: '🇯🇵'),
  CountryDialCode(name: 'Kuwait', isoCode: 'KW', dialCode: '+965', flag: '🇰🇼'),
  CountryDialCode(name: 'Sri Lanka', isoCode: 'LK', dialCode: '+94', flag: '🇱🇰'),
  CountryDialCode(name: 'Malaysia', isoCode: 'MY', dialCode: '+60', flag: '🇲🇾'),
  CountryDialCode(name: 'Nepal', isoCode: 'NP', dialCode: '+977', flag: '🇳🇵'),
  CountryDialCode(name: 'New Zealand', isoCode: 'NZ', dialCode: '+64', flag: '🇳🇿'),
  CountryDialCode(name: 'Oman', isoCode: 'OM', dialCode: '+968', flag: '🇴🇲'),
  CountryDialCode(name: 'Philippines', isoCode: 'PH', dialCode: '+63', flag: '🇵🇭'),
  CountryDialCode(name: 'Pakistan', isoCode: 'PK', dialCode: '+92', flag: '🇵🇰'),
  CountryDialCode(name: 'Qatar', isoCode: 'QA', dialCode: '+974', flag: '🇶🇦'),
  CountryDialCode(name: 'Saudi Arabia', isoCode: 'SA', dialCode: '+966', flag: '🇸🇦'),
  CountryDialCode(name: 'Singapore', isoCode: 'SG', dialCode: '+65', flag: '🇸🇬'),
  CountryDialCode(name: 'United States', isoCode: 'US', dialCode: '+1', flag: '🇺🇸'),
  CountryDialCode(name: 'South Africa', isoCode: 'ZA', dialCode: '+27', flag: '🇿🇦'),
];

/// Look a code up by ISO code, falling back to [kDefaultCountry].
CountryDialCode countryForIso(String isoCode) {
  for (final CountryDialCode country in kCountryDialCodes) {
    if (country.isoCode == isoCode) return country;
  }
  return kDefaultCountry;
}

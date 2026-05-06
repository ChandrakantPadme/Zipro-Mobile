/// ISO 3166-1 alpha-2 to alpha-3 (matches web KYC page helper).
String countryCode2ToAlpha3(String code2) {
  const countryMap = {
    'US': 'USA',
    'IN': 'IND',
    'GB': 'GBR',
    'AE': 'ARE',
    'SG': 'SGP',
    'AU': 'AUS',
    'CA': 'CAN',
    'DE': 'DEU',
    'FR': 'FRA',
    'JP': 'JPN',
    'CN': 'CHN',
    'BR': 'BRA',
    'MX': 'MEX',
    'ZA': 'ZAF',
    'NG': 'NGA',
    'KE': 'KEN',
    'CH': 'CHE',
    'NL': 'NLD',
    'SE': 'SWE',
    'NO': 'NOR',
  };
  final u = code2.toUpperCase();
  return countryMap[u] ?? (u.padRight(3, u.isNotEmpty ? u[0] : 'X'));
}

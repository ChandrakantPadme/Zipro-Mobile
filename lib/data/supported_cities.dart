// Mirrors [zipro_website_new/data/cities.ts] SUPPORTED_CITIES (labels for UI).

class SupportedCity {
  const SupportedCity({
    required this.city,
    required this.countryCode,
    required this.label,
  });

  final String city;
  final String countryCode;
  final String label;
}

/// Same entries as web `SUPPORTED_CITIES_RAW`, sorted by label.
const List<SupportedCity> kSupportedCities = [
  SupportedCity(city: 'Bangalore', countryCode: 'IN', label: 'Bangalore, India'),
  SupportedCity(city: 'Dubai', countryCode: 'AE', label: 'Dubai, UAE'),
  SupportedCity(city: 'London', countryCode: 'GB', label: 'London, United Kingdom'),
  SupportedCity(city: 'Mumbai', countryCode: 'IN', label: 'Mumbai, India'),
  SupportedCity(city: 'New Delhi', countryCode: 'IN', label: 'New Delhi, India'),
  SupportedCity(city: 'New York', countryCode: 'US', label: 'New York, United States'),
  SupportedCity(city: 'Singapore', countryCode: 'SG', label: 'Singapore, Singapore'),
];

String cityCountryLabel(String city, String countryCode) {
  for (final c in kSupportedCities) {
    if (c.city == city && c.countryCode == countryCode) {
      return c.label;
    }
  }
  if (city.isEmpty && countryCode.isEmpty) return '—';
  if (city.isEmpty) return countryCode;
  if (countryCode.isEmpty) return city;
  return '$city, $countryCode';
}

const String kIndiaCountryCode = 'IN';

List<SupportedCity> sortedIndiaCities() {
  final list =
      kSupportedCities.where((c) => c.countryCode == kIndiaCountryCode).toList();
  list.sort((a, b) => a.label.compareTo(b.label));
  return list;
}

List<SupportedCity> sortedNonIndiaCities() {
  final list =
      kSupportedCities.where((c) => c.countryCode != kIndiaCountryCode).toList();
  list.sort((a, b) => a.label.compareTo(b.label));
  return list;
}

String cityCompositeValue(String city, String countryCode) => '$city|$countryCode';

SupportedCity? findSupportedCity(String city, String countryCode) {
  for (final c in kSupportedCities) {
    if (c.city == city && c.countryCode == countryCode) return c;
  }
  return null;
}

SupportedCity? parseCityComposite(String? value) {
  if (value == null || value.isEmpty || !value.contains('|')) return null;
  final i = value.indexOf('|');
  final city = value.substring(0, i);
  final cc = value.substring(i + 1);
  return findSupportedCity(city, cc);
}

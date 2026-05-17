/// Currency conversion rates to INR for capacity value limit checks.
/// Mirrors [zipro_website_new/data/currency-rates.ts] — align with backend
/// `CurrencyConversionService` rates.
const Map<String, num> _rateToInr = {
  'USD': 83,
  'GBP': 105,
  'EUR': 90,
  'INR': 1,
};

/// Convert [amount] from [fromCurrency] to INR. Falls back to 1:1 when the
/// currency is unknown.
double convertToInr(num amount, String? fromCurrency) {
  final currency = (fromCurrency ?? 'INR').toUpperCase().trim();
  final rate = _rateToInr[currency] ?? 1;
  final v = amount * rate;
  return (v * 100).round() / 100;
}

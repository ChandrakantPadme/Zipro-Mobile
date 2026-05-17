// Port of [zipro_website_new/data/delivery-fees.ts] for parity with web create-order.

import 'dart:math' as math;

class DeliveryFeeResult {
  const DeliveryFeeResult({
    required this.amount,
    required this.currency,
    this.label,
  });

  final double amount;
  final String currency;
  final String? label;
}

class TotalAmountBreakdown {
  const TotalAmountBreakdown({
    required this.deliveryFee,
    required this.weightFare,
    required this.secureFee,
    required this.totalAmount,
    required this.totalCurrency,
  });

  final DeliveryFeeResult? deliveryFee;
  final double weightFare;
  final double secureFee;
  final double totalAmount;
  final String totalCurrency;
}

const Set<String> europeCountryCodes = {
  'DE',
  'FR',
  'ES',
  'IT',
  'NL',
  'BE',
  'AT',
  'PT',
  'IE',
  'PL',
  'SE',
  'DK',
  'FI',
  'GR',
  'CZ',
  'RO',
  'HU',
  'BG',
  'HR',
  'SK',
  'SI',
  'EE',
  'LV',
  'LT',
  'LU',
  'MT',
  'CY',
};

const Map<String, ({double amount, String currency})> routeFees = {
  'US-IN': (amount: 39, currency: 'USD'),
  'SG-IN': (amount: 19, currency: 'USD'),
  'AE-IN': (amount: 19, currency: 'USD'),
  'GB-IN': (amount: 29, currency: 'GBP'),
  'IN-US': (amount: 3699, currency: 'INR'),
  'IN-GB': (amount: 3599, currency: 'INR'),
  'IN-AE': (amount: 1799, currency: 'INR'),
  'IN-SG': (amount: 1799, currency: 'INR'),
};

const europeToIndia = (amount: 29.0, currency: 'EUR');

const Map<String, double> rateToUsd = {
  'USD': 1,
  'INR': 1 / 83,
  'GBP': 1.27,
  'EUR': 1.08,
};

DeliveryFeeResult? getDeliveryFee(
  String originCountryCode,
  String destinationCountryCode,
) {
  if (originCountryCode.isEmpty || destinationCountryCode.isEmpty) return null;
  final origin = originCountryCode.toUpperCase();
  final dest = destinationCountryCode.toUpperCase();
  final key = '$origin-$dest';
  final exact = routeFees[key];
  if (exact != null) {
    return DeliveryFeeResult(
      amount: exact.amount,
      currency: exact.currency,
      label: '$origin → $dest',
    );
  }
  if (europeCountryCodes.contains(origin) && dest == 'IN') {
    return DeliveryFeeResult(
      amount: europeToIndia.amount,
      currency: europeToIndia.currency,
      label: 'Europe → India',
    );
  }
  return null;
}

double convertToCurrency(
  double amount,
  String fromCurrency,
  String toCurrency,
) {
  final from = fromCurrency.toUpperCase();
  final to = toCurrency.toUpperCase();
  if (from == to) return amount;
  final toUsd = rateToUsd[from] ?? 1;
  final fromUsd = rateToUsd[to] ?? 1;
  final amountUsd = amount * toUsd;
  return amountUsd / fromUsd;
}

TotalAmountBreakdown getDutyFreeTotalAmount(
  int productLinkCount,
  double _,
  String __,
) {
  const perItemInr = 499.0;
  final deliveryFeeAmount = productLinkCount * perItemInr;
  final deliveryFee = DeliveryFeeResult(
    amount: deliveryFeeAmount,
    currency: 'INR',
    label: 'Duty Free',
  );
  return TotalAmountBreakdown(
    deliveryFee: deliveryFee,
    weightFare: 0,
    secureFee: 0,
    totalAmount: deliveryFeeAmount,
    totalCurrency: 'INR',
  );
}

TotalAmountBreakdown getTotalAmount(
  String originCountryCode,
  String destinationCountryCode,
  double parcelValue,
  String parcelCurrency,
  int weightKg,
) {
  final deliveryFee = getDeliveryFee(originCountryCode, destinationCountryCode);
  if (deliveryFee == null) {
    return TotalAmountBreakdown(
      deliveryFee: null,
      weightFare: 0,
      secureFee: 0,
      totalAmount: parcelValue,
      totalCurrency: parcelCurrency,
    );
  }
  final wf = weightKg >= 2
      ? (deliveryFee.amount * (math.pow(1.15, weightKg - 1) - 1) * 100)
              .round() /
          100
      : 0.0;
  final secureFeeInParcelCurrency = parcelValue * 0.05;
  final secureFee = convertToCurrency(
    secureFeeInParcelCurrency,
    parcelCurrency,
    deliveryFee.currency,
  );
  final totalAmount = deliveryFee.amount + wf + secureFee;
  return TotalAmountBreakdown(
    deliveryFee: deliveryFee,
    weightFare: wf,
    secureFee: secureFee,
    totalAmount: totalAmount,
    totalCurrency: deliveryFee.currency,
  );
}

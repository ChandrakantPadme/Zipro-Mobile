/// Arguments passed to [VerifyOtpScreen] via GoRouter `extra`.
class VerifyOtpExtra {
  const VerifyOtpExtra({
    required this.channel,
    required this.identifier,
    required this.displayContact,
  });

  /// Backend channel: `EMAIL` or `PHONE`.
  final String channel;

  /// Value sent to the API (e.g. email or `+91...`).
  final String identifier;

  /// Shown in the subtitle (masked or full per product choice).
  final String displayContact;
}

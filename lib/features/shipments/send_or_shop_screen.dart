import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/env/app_config.dart';
import '../../core/navigation/zipro_pop_or_home.dart';
import '../../core/network/dio_error_mapper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/create_form_ui.dart';
import '../../data/delivery_fees.dart';
import '../../data/supported_cities.dart';
import '../kyc/widgets/kyc_required_dialog.dart';
import '../repositories_providers.dart';
import 'shipments_list_screen.dart';

const _sendingDocs = 'Documents';
const _sendingIntl = 'International Shopping';
const _sendingDuty = 'Duty Free Shopping';

bool _looksLikeUrl(String line) {
  final u = Uri.tryParse(line);
  return u != null &&
      u.hasScheme &&
      (u.scheme == 'http' || u.scheme == 'https');
}

/// Create order UI aligned with [zipro_website_new/app/(app)/shipments/create/page.tsx].
class SendOrShopScreen extends ConsumerStatefulWidget {
  const SendOrShopScreen({super.key});

  @override
  ConsumerState<SendOrShopScreen> createState() => _SendOrShopScreenState();
}

class _SendOrShopScreenState extends ConsumerState<SendOrShopScreen> {
  String _whatSending = _sendingDocs;
  String? _originComposite;
  String? _destinationComposite;
  String? _dutyFreeAirportComposite;

  final _receiverName = TextEditingController();
  final _receiverPhone = TextEditingController();
  final _description = TextEditingController();
  final _parcelValue = TextEditingController();

  /// One [TextEditingController] per row — matches web `productLinksText` lines.
  final List<TextEditingController> _productLinkControllers = [];

  String? _packageWeight;
  String _currency = 'INR';
  DateTime? _deliveryDate;
  bool _termsConsent = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _productLinkControllers.add(TextEditingController());
  }

  @override
  void dispose() {
    _receiverName.dispose();
    _receiverPhone.dispose();
    _description.dispose();
    _parcelValue.dispose();
    for (final c in _productLinkControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addProductLinkRow() {
    setState(() {
      _productLinkControllers.add(TextEditingController());
    });
  }

  void _removeProductLinkRow(int index) {
    if (_productLinkControllers.length <= 1) return;
    setState(() {
      _productLinkControllers.removeAt(index).dispose();
    });
  }

  bool _isDutyFree() => _whatSending == _sendingDuty;

  SupportedCity? _originCity() => parseCityComposite(_originComposite);
  SupportedCity? _destCity() => parseCityComposite(_destinationComposite);

  List<SupportedCity> _originOptions() {
    final dest = _destCity();
    if (dest == null) {
      return [...kSupportedCities]..sort((a, b) => a.label.compareTo(b.label));
    }
    final destIndia = dest.countryCode == kIndiaCountryCode;
    return destIndia ? sortedNonIndiaCities() : sortedIndiaCities();
  }

  List<SupportedCity> _destinationOptions() {
    final origin = _originCity();
    if (origin == null) {
      return [...kSupportedCities]..sort((a, b) => a.label.compareTo(b.label));
    }
    final originIndia = origin.countryCode == kIndiaCountryCode;
    return originIndia ? sortedNonIndiaCities() : sortedIndiaCities();
  }

  void _setWhatSending(String? v) {
    if (v == null) return;
    setState(() {
      _whatSending = v;
      if (v == _sendingDuty) {
        _originComposite = null;
        _destinationComposite = null;
      } else {
        _dutyFreeAirportComposite = null;
      }
    });
  }

  void _pickOrigin(String? composite) {
    setState(() {
      _originComposite = composite;
      if (_originCity() != null && _destCity() != null) {
        final oIn = _originCity()!.countryCode == kIndiaCountryCode;
        final dIn = _destCity()!.countryCode == kIndiaCountryCode;
        if (oIn == dIn) _destinationComposite = null;
      }
    });
  }

  void _pickDestination(String? composite) {
    setState(() {
      _destinationComposite = composite;
      if (_originCity() != null && _destCity() != null) {
        final oIn = _originCity()!.countryCode == kIndiaCountryCode;
        final dIn = _destCity()!.countryCode == kIndiaCountryCode;
        if (oIn == dIn) _originComposite = null;
      }
    });
  }

  int _weightKgSubmit() {
    switch (_packageWeight) {
      case 'upto_1kg':
        return 1;
      case 'upto_2kg':
        return 2;
      case 'upto_3kg':
        return 3;
      default:
        return 1;
    }
  }

  List<String> _validatedProductUrls() {
    final out = <String>[];
    for (final c in _productLinkControllers) {
      final line = c.text.trim();
      if (line.isEmpty) continue;
      if (_looksLikeUrl(line)) out.add(line);
    }
    return out;
  }

  TotalAmountBreakdown _feeBreakdown() {
    final parcel = double.tryParse(_parcelValue.text) ?? 0;
    final w = _weightKgSubmit();
    if (_isDutyFree()) {
      return getDutyFreeTotalAmount(
        _validatedProductUrls().length,
        parcel,
        _currency,
      );
    }
    final o = _originCity();
    final d = _destCity();
    if (o == null || d == null) {
      return TotalAmountBreakdown(
        deliveryFee: null,
        weightFare: 0,
        secureFee: 0,
        totalAmount: parcel,
        totalCurrency: _currency,
      );
    }
    return getTotalAmount(
      o.countryCode,
      d.countryCode,
      parcel,
      _currency,
      w,
    );
  }

  String? _collectValidationError() {
    if (!_termsConsent) {
      return 'Please accept the Sender Declaration Form and parcel terms.';
    }
    final parcel = double.tryParse(_parcelValue.text);
    if (_packageWeight == null) {
      return 'Select package weight.';
    }
    if (_receiverName.text.trim().isEmpty) {
      return 'Receiver name is required.';
    }
    if (_receiverPhone.text.trim().isEmpty) {
      return 'Receiver phone is required.';
    }
    if (_description.text.trim().isEmpty) {
      return 'Description is required.';
    }
    if (_deliveryDate == null) {
      return 'Latest delivery date is required.';
    }
    if (parcel == null || parcel < 0.01) {
      return 'Parcel value must be greater than 0.';
    }
    final max = _currency == 'INR' ? 20000.0 : 250.0;
    if (parcel > max) {
      return 'Parcel value cannot exceed ${_currency == "INR" ? "INR 20000" : "USD 250"}.';
    }

    if (_isDutyFree()) {
      final ap = parseCityComposite(_dutyFreeAirportComposite);
      if (ap == null) {
        return 'Please select the airport of your duty free shopping.';
      }
    } else {
      if (_originCity() == null || _destCity() == null) {
        return 'Origin and destination are required.';
      }
    }

    final needsLinks =
        _whatSending == _sendingIntl || _whatSending == _sendingDuty;
    if (needsLinks) {
      var hasNonEmpty = false;
      for (final c in _productLinkControllers) {
        final line = c.text.trim();
        if (line.isNotEmpty) {
          hasNonEmpty = true;
          if (!_looksLikeUrl(line)) {
            return 'Each product link must be a valid URL.';
          }
        }
      }
      final urls = _validatedProductUrls();
      if (!hasNonEmpty || urls.isEmpty) {
        return 'Add at least one valid product URL (https://…).';
      }
    }
    return null;
  }

  Future<void> _openDeclarationPdf() async {
    final uri = Uri.parse(AppConfig.senderDeclarationPdfUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open declaration: $uri')),
      );
    }
  }

  Future<void> _showDeclarationDialog() async {
    var read = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: const Text('Sender Declaration Form'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Please read the Sender Declaration Form below. You must accept it to create an order.',
                    style: TextStyle(
                        color: AppColors.mutedForeground, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _openDeclarationPdf,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open declaration (PDF)'),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: read,
                    onChanged: (v) => setLocal(() => read = v ?? false),
                    title: const Text(
                      "I have read and accept the Sender Declaration Form.",
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
              FilledButton(
                onPressed: read
                    ? () {
                        setState(() => _termsConsent = true);
                        Navigator.pop(ctx);
                      }
                    : null,
                child: const Text('Accept'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    final err = _collectValidationError();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    final parcel = double.tryParse(_parcelValue.text)!;
    final weightKg = _weightKgSubmit();
    final productUrls = _validatedProductUrls();

    SupportedCity oPayload;
    SupportedCity dPayload;
    TotalAmountBreakdown fee;

    if (_isDutyFree()) {
      final ap = parseCityComposite(_dutyFreeAirportComposite)!;
      oPayload = ap;
      dPayload = ap;
      fee = getDutyFreeTotalAmount(productUrls.length, parcel, _currency);
    } else {
      oPayload = _originCity()!;
      dPayload = _destCity()!;
      fee = getTotalAmount(
        oPayload.countryCode,
        dPayload.countryCode,
        parcel,
        _currency,
        weightKg,
      );
    }

    final payload = <String, dynamic>{
      'originCity': oPayload.city,
      'originCountryCode': oPayload.countryCode,
      'destinationCity': dPayload.city,
      'destinationCountryCode': dPayload.countryCode,
      'description': _description.text.trim(),
      'declaredValueAmount': parcel,
      'currency': _currency,
      'weightKg': weightKg,
      if (productUrls.isNotEmpty) 'productLinks': productUrls,
      'items': [
        {
          'itemDescription': _description.text.trim(),
          'quantity': 1,
          'itemValueAmount': parcel,
          if (productUrls.isNotEmpty) 'productLink': productUrls.first,
        },
      ],
      'addresses': {
        'originAddressText': 'To be provided',
        'originContactName': '',
        'originContactPhone': '',
        'originInstructions': '',
        'destinationAddressText': 'To be provided',
        'destinationContactName': '',
        'destinationContactPhone': '',
        'destinationInstructions': '',
      },
      'receiverName': _receiverName.text.trim(),
      'receiverPhone': _receiverPhone.text.trim(),
      'isRestricted': false,
      if (fee.deliveryFee != null) 'deliveryFee': fee.deliveryFee!.amount,
      if (fee.deliveryFee != null) ...{
        'totalAmountToPay': fee.totalAmount,
        'totalAmountCurrency': fee.totalCurrency,
        'weightFare': _isDutyFree() ? 0 : fee.weightFare,
        'secureFee': fee.secureFee,
      },
      if (_isDutyFree()) 'shipmentType': 'DUTY_FREE_SHOPPING',
      'termsAndParcelConsentAccepted': true,
      'latestDeliveryDate': DateFormat('yyyy-MM-dd').format(_deliveryDate!),
    };

    setState(() => _loading = true);
    final repo = ref.read(shipmentRepositoryProvider);
    try {
      final res = await repo.createShipment(payload);
      if (!mounted) return;
      setState(() => _loading = false);
      if (!res.success || res.data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(res.message.isNotEmpty ? res.message : 'Failed')),
        );
        return;
      }
      ref.invalidate(myShipmentsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order created')),
      );
      final id = res.data!.primaryId;
      context.push('/shipment/$id');
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (isKycRequiredError(e)) {
        await showKycRequiredDialog(context, actionLabel: 'create an order');
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(dioErrorMessage(e))));
    }
  }

  DropdownButtonFormField<String> _cityDropdown({
    required String label,
    required String hint,
    required String? value,
    required List<SupportedCity> options,
    required ValueChanged<String?> onChanged,
    bool enabled = true,
  }) {
    final validIds =
        options.map((e) => cityCompositeValue(e.city, e.countryCode)).toSet();
    final resolved = value != null && validIds.contains(value) ? value : null;

    return DropdownButtonFormField<String>(
      value: resolved,
      decoration: CreateFormUi.inputDecoration(
        label: label,
        hint: hint,
      ),
      items: [
        for (final c in options)
          DropdownMenuItem(
            value: cityCompositeValue(c.city, c.countryCode),
            child: Text(c.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: enabled
          ? (v) {
              onChanged(v);
            }
          : null,
      isExpanded: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final originOpts = _originOptions();
    final destOpts = _destinationOptions();

    final isDutyFree = _isDutyFree();
    final feeCalc = _feeBreakdown();

    final showFees = isDutyFree
        ? _dutyFreeAirportComposite != null
        : (_originCity() != null && _destCity() != null);
    final deliveryFeeUi = (_originCity() != null && _destCity() != null)
        ? getDeliveryFee(
            _originCity()!.countryCode,
            _destCity()!.countryCode,
          )
        : null;
    final productCount = _validatedProductUrls().length;
    final showFeeDetail = isDutyFree
        ? (parseCityComposite(_dutyFreeAirportComposite) != null &&
            productCount >= 1)
        : (double.tryParse(_parcelValue.text) != null && deliveryFeeUi != null);

    return ZiproPopScope(
      child: Scaffold(
        appBar: AppBar(
          leading: ziproLeadingBackOrHome(context),
          title: const Text('Create New Order'),
        ),
        body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= CreateFormUi.wideBreakpoint;
            return Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                padding: CreateFormUi.scrollPadding,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CreateFormUi.heroHeader(
                        context: context,
                        icon: Icons.send,
                        title: 'Send or shop',
                        subtitle:
                            'Connect with travellers to ship your package',
                      ),
                      const SizedBox(height: CreateFormUi.sectionGap),
                      CreateFormUi.sectionTitle(context, 'Order type'),
                      DropdownButtonFormField<String>(
                        decoration: CreateFormUi.inputDecoration(
                          label: 'What are you sending?',
                        ),
                        value: _whatSending,
                        items: const [
                          DropdownMenuItem(
                              value: _sendingDocs, child: Text('Documents')),
                          DropdownMenuItem(
                              value: _sendingIntl, child: Text(_sendingIntl)),
                          DropdownMenuItem(
                              value: _sendingDuty, child: Text(_sendingDuty)),
                        ],
                        onChanged: _setWhatSending,
                      ),
                      const SizedBox(height: CreateFormUi.sectionGap),

                      // Location
                      CreateFormUi.sectionTitle(context, 'Location'),
                      if (isDutyFree) ...[
                        _cityDropdown(
                          label:
                              'Please select the airport of your duty free shopping',
                          hint: 'Select airport',
                          value: _dutyFreeAirportComposite,
                          options: sortedIndiaCities(),
                          onChanged: (v) =>
                              setState(() => _dutyFreeAirportComposite = v),
                        ),
                      ] else ...[
                        Builder(
                          builder: (context) {
                            final originField = Stack(
                              alignment: Alignment.centerRight,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 36),
                                  child: _cityDropdown(
                                    label: 'Origin',
                                    hint: 'Select city and country',
                                    value: _originComposite,
                                    options: originOpts,
                                    onChanged: _pickOrigin,
                                  ),
                                ),
                                if ((_originComposite ?? '').isNotEmpty)
                                  IconButton(
                                    icon: Icon(Icons.clear,
                                        color: AppColors.mutedForeground),
                                    onPressed: () =>
                                        setState(() => _originComposite = null),
                                  ),
                              ],
                            );
                            final destField = Stack(
                              alignment: Alignment.centerRight,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 36),
                                  child: _cityDropdown(
                                    label: 'Destination',
                                    hint: 'Select city and country',
                                    value: _destinationComposite,
                                    options: destOpts,
                                    onChanged: _pickDestination,
                                  ),
                                ),
                                if ((_destinationComposite ?? '').isNotEmpty)
                                  IconButton(
                                    icon: Icon(Icons.clear,
                                        color: AppColors.mutedForeground),
                                    onPressed: () => setState(
                                        () => _destinationComposite = null),
                                  ),
                              ],
                            );
                            if (wide) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: originField),
                                  const SizedBox(width: CreateFormUi.fieldGap),
                                  Expanded(child: destField),
                                ],
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                originField,
                                const SizedBox(height: CreateFormUi.fieldGap),
                                destField,
                              ],
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: CreateFormUi.sectionGap),

                      CreateFormUi.sectionTitle(context, 'Receiver'),
                      CreateFormUi.pairRow(
                        wide: wide,
                        first: TextField(
                          controller: _receiverName,
                          textInputAction: TextInputAction.next,
                          decoration: CreateFormUi.inputDecoration(
                            label: 'Name',
                            hint: 'John Doe',
                          ),
                        ),
                        second: TextField(
                          controller: _receiverPhone,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: CreateFormUi.inputDecoration(
                            label: 'Mobile number',
                            hint: '+1234567890',
                          ),
                        ),
                      ),
                      const SizedBox(height: CreateFormUi.sectionGap),

                      CreateFormUi.sectionTitle(context, 'Package details'),
                      DropdownButtonFormField<String>(
                        decoration: CreateFormUi.inputDecoration(
                          label: 'Weight',
                          hint: 'Select package weight',
                        ),
                        value: _packageWeight,
                        items: const [
                          DropdownMenuItem(
                              value: 'upto_1kg', child: Text('Up to 1 kg')),
                          DropdownMenuItem(
                              value: 'upto_2kg', child: Text('Up to 2 kg')),
                          DropdownMenuItem(
                              value: 'upto_3kg', child: Text('Up to 3 kg')),
                        ],
                        onChanged: (v) => setState(() => _packageWeight = v),
                      ),
                      const SizedBox(height: CreateFormUi.fieldGap),
                      TextField(
                        controller: _description,
                        minLines: 3,
                        maxLines: 5,
                        decoration: CreateFormUi.inputDecoration(
                          label: 'Description',
                          hint: 'Brief description of the order',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: CreateFormUi.fieldGap),

                      Builder(
                        builder: (context) {
                          final needsLinks = _whatSending == _sendingIntl ||
                              _whatSending == _sendingDuty;
                          final dateTile = InkWell(
                            onTap: () async {
                              final now = DateTime.now();
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _deliveryDate ?? now,
                                firstDate:
                                    DateTime(now.year, now.month, now.day),
                                lastDate:
                                    DateTime(now.year + 2, now.month, now.day),
                              );
                              if (picked != null) {
                                setState(() => _deliveryDate = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: CreateFormUi.inputDecoration(
                                label: 'Latest delivery date',
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_month_outlined,
                                      color: AppColors.mutedForeground,
                                      size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _deliveryDate != null
                                          ? DateFormat.yMMMd()
                                              .format(_deliveryDate!)
                                          : 'Pick a date',
                                      style: TextStyle(
                                        color: _deliveryDate != null
                                            ? AppColors.foreground
                                            : AppColors.mutedForeground,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );

                          final linksField = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CreateFormUi.sectionTitle(
                                  context, 'Product links'),
                              const SizedBox(height: CreateFormUi.fieldGap),
                              ...List.generate(_productLinkControllers.length,
                                  (index) {
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: index ==
                                            _productLinkControllers.length - 1
                                        ? 0
                                        : CreateFormUi.fieldGap,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 14),
                                        child: SizedBox(
                                          width: 22,
                                          child: Text(
                                            '${index + 1}.',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.mutedForeground,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: TextField(
                                          controller:
                                              _productLinkControllers[index],
                                          keyboardType: TextInputType.url,
                                          textInputAction: TextInputAction.next,
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 13,
                                          ),
                                          decoration: CreateFormUi
                                              .linkInputDecoration(),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                                      if (_productLinkControllers.length > 1)
                                        IconButton(
                                          tooltip: 'Remove link',
                                          onPressed: () =>
                                              _removeProductLinkRow(index),
                                          icon: Icon(
                                            Icons.close,
                                            color: AppColors.mutedForeground,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: CreateFormUi.fieldGap),
                              OutlinedButton.icon(
                                onPressed: _addProductLinkRow,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add link'),
                              ),
                            ],
                          );

                          if (!needsLinks) return dateTile;
                          if (wide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: dateTile),
                                const SizedBox(width: CreateFormUi.fieldGap),
                                Expanded(child: linksField),
                              ],
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              dateTile,
                              const SizedBox(height: CreateFormUi.fieldGap),
                              linksField,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: CreateFormUi.fieldGap),

                      CreateFormUi.pairRow(
                        wide: wide,
                        first: TextField(
                          controller: _parcelValue,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: CreateFormUi.inputDecoration(
                            label: 'Total parcel value',
                            hint: '1000',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        second: DropdownButtonFormField<String>(
                          decoration: CreateFormUi.inputDecoration(
                            label: 'Currency',
                          ),
                          value: _currency,
                          items: const [
                            DropdownMenuItem(value: 'USD', child: Text('USD')),
                            DropdownMenuItem(value: 'INR', child: Text('INR')),
                          ],
                          onChanged: (v) =>
                              setState(() => _currency = v ?? 'INR'),
                        ),
                      ),

                      if (showFees) ...[
                        const SizedBox(height: CreateFormUi.sectionGap),
                        Card(
                          color: AppColors.secondary.withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: AppColors.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Delivery fee & total',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                if (showFeeDetail) ...[
                                  Text(
                                    isDutyFree
                                        ? 'Delivery fee: ${feeCalc.totalCurrency} ${feeCalc.deliveryFee?.amount.toStringAsFixed(0) ?? 0} '
                                            '(INR 499 × $productCount item${productCount == 1 ? "" : "s"})'
                                        : 'Delivery fee: ${deliveryFeeUi?.currency ?? feeCalc.totalCurrency} '
                                            '${deliveryFeeUi?.amount.toStringAsFixed(0) ?? 0}'
                                            '${deliveryFeeUi?.label != null ? " (${deliveryFeeUi!.label})" : ""}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                  if (!isDutyFree && feeCalc.weightFare > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        'Package weight fare: ${feeCalc.totalCurrency} ${feeCalc.weightFare.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.mutedForeground,
                                        ),
                                      ),
                                    ),
                                  if (!isDutyFree)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        'Parcel Protection Fee: ${feeCalc.totalCurrency} ${feeCalc.secureFee.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.mutedForeground,
                                        ),
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Total amount: ${feeCalc.totalCurrency} ${feeCalc.totalAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  Text(
                                    isDutyFree
                                        ? 'Add at least one product link to see delivery fee.'
                                        : 'Add parcel value above to see parcel protection fee and total amount.',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      fontSize: 13,
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                ],
                                if (!showFeeDetail &&
                                    deliveryFeeUi == null &&
                                    !isDutyFree &&
                                    _originCity() != null &&
                                    _destCity() != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Select a supported route (e.g. US → India, Singapore → India) to see delivery fee.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.mutedForeground,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: CreateFormUi.sectionGap),

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: CheckboxListTile(
                          value: _termsConsent,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (v) =>
                              setState(() => _termsConsent = v ?? false),
                          title: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 0,
                            runSpacing: 4,
                            children: [
                              Text(
                                'I have read and accept the ',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.foreground,
                                  height: 1.35,
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  minimumSize: Size.zero,
                                  padding: EdgeInsets.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  foregroundColor: AppColors.primary,
                                ),
                                onPressed: _showDeclarationDialog,
                                child: const Text(
                                  'Sender Declaration Form',
                                  style: TextStyle(
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                ", and I confirm that my parcel contents are as declared and comply with Zipro's permitted categories and value limits.",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.foreground,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: CreateFormUi.sectionGap),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: [
                            OutlinedButton(
                              onPressed: _loading
                                  ? null
                                  : () => context.go('/dashboard'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: _loading ? null : _submit,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Text('Create Order'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  }
}

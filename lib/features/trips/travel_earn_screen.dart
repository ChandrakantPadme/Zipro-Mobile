import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';

import '../../core/network/dio_error_mapper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/create_form_ui.dart';
import '../../data/supported_cities.dart';
import '../kyc/kyc_status_provider.dart';
import '../kyc/widgets/kyc_required_dialog.dart';
import '../repositories_providers.dart';
import '../shipments/shipment_detail_screen.dart'
    show
        orderByShipmentProvider,
        shipmentDetailProvider,
        shipmentMatchesProvider;
import 'trip_detail_screen.dart'
    show ordersByTripProvider, tripMatchesForTripProvider, tripProvider;
import 'trips_list_screen.dart';

/// Mirrors [zipro_website_new/app/(app)/trips/create/page.tsx] — two rows of
/// two cards (Origin/Destination, Travel Dates/PNR & Capacity), inline field
/// errors, accent-coloured submit, Cancel + Create Trip footer.
class TravelEarnScreen extends ConsumerStatefulWidget {
  const TravelEarnScreen({
    super.key,
    this.initialFromCity,
    this.initialFromCountryCode,
    this.initialToCity,
    this.initialToCountryCode,
    this.createForShipmentId,
  });

  final String? initialFromCity;
  final String? initialFromCountryCode;
  final String? initialToCity;
  final String? initialToCountryCode;
  /// When set (e.g. live order → create trip), accept this shipment after trip create.
  final String? createForShipmentId;

  @override
  ConsumerState<TravelEarnScreen> createState() => _TravelEarnScreenState();
}

class _TravelEarnScreenState extends ConsumerState<TravelEarnScreen> {
  final _airline = TextEditingController();
  final _pnr = TextEditingController();
  final _capW = TextEditingController();
  final _capV = TextEditingController();

  SupportedCity? _fromSelected;
  SupportedCity? _toSelected;
  DateTime? _travelDate;
  DateTime? _returnDate;

  PlatformFile? _boardingPassFile;
  String? _boardingPassS3Key;
  bool _loading = false;
  bool _uploading = false;
  double _uploadProgress = 0;

  /// Per-field validation messages, keyed by field id (matches web `errors.<id>`).
  final Map<String, String> _errors = <String, String>{};

  @override
  void initState() {
    super.initState();
    final fromC = widget.initialFromCity?.trim();
    final fromCc = widget.initialFromCountryCode?.trim();
    if (fromC != null &&
        fromC.isNotEmpty &&
        fromCc != null &&
        fromCc.isNotEmpty) {
      _fromSelected = findSupportedCity(fromC, fromCc);
    }
    final toC = widget.initialToCity?.trim();
    final toCc = widget.initialToCountryCode?.trim();
    if (toC != null && toC.isNotEmpty && toCc != null && toCc.isNotEmpty) {
      _toSelected = findSupportedCity(toC, toCc);
    }
  }

  @override
  void dispose() {
    _airline.dispose();
    _pnr.dispose();
    _capW.dispose();
    _capV.dispose();
    super.dispose();
  }

  List<SupportedCity> _sortedAllCities() {
    final all = [...kSupportedCities];
    all.sort((a, b) => a.label.compareTo(b.label));
    return all;
  }

  List<SupportedCity> _fromOptions() {
    final toCc = _toSelected?.countryCode;
    if (toCc == null || toCc.isEmpty) return _sortedAllCities();
    return toCc == kIndiaCountryCode
        ? sortedNonIndiaCities()
        : sortedIndiaCities();
  }

  List<SupportedCity> _toOptions() {
    final fromCc = _fromSelected?.countryCode;
    if (fromCc == null || fromCc.isEmpty) return _sortedAllCities();
    return fromCc == kIndiaCountryCode
        ? sortedNonIndiaCities()
        : sortedIndiaCities();
  }

  Future<void> _pickTravelDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _travelDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _travelDate = DateTime(selected.year, selected.month, selected.day);
      _errors.remove('travelDate');
      if (_returnDate != null && _returnDate!.isBefore(_travelDate!)) {
        _returnDate = null;
      }
    });
  }

  Future<void> _pickReturnDate() async {
    final now = DateTime.now();
    final min = _travelDate ?? DateTime(now.year, now.month, now.day);
    final initial = _returnDate ?? min;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: min,
      lastDate: DateTime(now.year + 3),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _returnDate = DateTime(selected.year, selected.month, selected.day);
      _errors.remove('returnDate');
    });
  }

  Future<void> _pickAndUploadBoardingPass() async {
    final picked = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    final file = picked?.files.firstOrNull;
    if (file == null || file.bytes == null || file.bytes!.isEmpty) return;

    final fileName = file.name.isEmpty ? 'boarding_pass_upload' : file.name;
    final mime = lookupMimeType(
          fileName,
          headerBytes: file.bytes!.take(20).toList(),
        ) ??
        'application/octet-stream';
    final up = ref.read(uploadRepositoryProvider);

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });
    try {
      final s3Path = await up.uploadBytesAndGetS3Path(
        bytes: file.bytes!.toList(),
        fileName: fileName,
        contentType: mime,
        onSendProgress: (c, t) {
          if (!mounted || t <= 0) return;
          setState(() => _uploadProgress = c / t);
        },
      );
      if (!mounted) return;
      setState(() {
        _boardingPassFile = file;
        _boardingPassS3Key = s3Path;
        _uploading = false;
        _uploadProgress = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadProgress = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  bool _validate() {
    final errors = <String, String>{};
    if (_fromSelected == null) {
      errors['fromCity'] = 'Origin city is required';
    }
    if (_toSelected == null) {
      errors['toCity'] = 'Destination city is required';
    }
    if (_travelDate == null) {
      errors['travelDate'] = 'Travel date is required';
    }
    if (_returnDate != null &&
        _travelDate != null &&
        _returnDate!.isBefore(_travelDate!)) {
      errors['returnDate'] = 'Return date must be on or after travel date';
    }

    final capWText = _capW.text.trim();
    if (capWText.isNotEmpty) {
      final v = double.tryParse(capWText);
      if (v == null) {
        errors['capacityWeightKg'] = 'Enter a number';
      } else if (v < 0.1) {
        errors['capacityWeightKg'] = 'Capacity must be at least 0.1 kg';
      } else if (v > 10) {
        errors['capacityWeightKg'] = 'Capacity must not exceed 10 kg';
      }
    }
    final capVText = _capV.text.trim();
    if (capVText.isNotEmpty) {
      final v = double.tryParse(capVText);
      if (v == null) {
        errors['capacityValueLimit'] = 'Enter a number';
      } else if (v < 0) {
        errors['capacityValueLimit'] = 'Value limit cannot be negative';
      } else if (v > 50000) {
        errors['capacityValueLimit'] =
            'Value limit must not exceed ₹50,000 INR';
      }
    }

    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
    });
    return errors.isEmpty;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    final departUtc = DateTime.utc(
      _travelDate!.year,
      _travelDate!.month,
      _travelDate!.day,
      0,
      0,
      0,
      0,
    ).toIso8601String();

    final capW =
        _capW.text.trim().isEmpty ? null : double.tryParse(_capW.text.trim());
    final capV =
        _capV.text.trim().isEmpty ? null : double.tryParse(_capV.text.trim());

    final payload = <String, dynamic>{
      'fromCity': _fromSelected!.city,
      'fromCountryCode': _fromSelected!.countryCode,
      'toCity': _toSelected!.city,
      'toCountryCode': _toSelected!.countryCode,
      'departAt': departUtc,
      if (_returnDate != null)
        'arriveAt': DateTime.utc(
          _returnDate!.year,
          _returnDate!.month,
          _returnDate!.day,
          23,
          59,
          59,
          999,
        ).toIso8601String(),
      if (_airline.text.trim().isNotEmpty) 'airline': _airline.text.trim(),
      if (_pnr.text.trim().isNotEmpty) 'pnr': _pnr.text.trim(),
      if (_boardingPassS3Key != null) 'boardingPassS3Key': _boardingPassS3Key,
      if (capW != null) 'capacityWeightKg': capW,
      if (capV != null) 'capacityValueLimit': capV,
    };

    setState(() => _loading = true);
    final repo = ref.read(tripRepositoryProvider);
    try {
      final res = await repo.createTrip(payload);
      if (!mounted) return;
      setState(() => _loading = false);
      if (!res.success || res.data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message)),
        );
        return;
      }
      final newTripId = res.data!.tripId;
      final pendingShipment = widget.createForShipmentId?.trim();
      if (pendingShipment != null && pendingShipment.isNotEmpty) {
        try {
          final acceptRes = await repo.acceptShipmentForTrip(
            tripId: newTripId,
            shipmentId: pendingShipment,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                acceptRes.success
                    ? (acceptRes.message.isNotEmpty
                        ? acceptRes.message
                        : 'Order accepted')
                    : (acceptRes.message.isNotEmpty
                        ? acceptRes.message
                        : 'Could not accept order'),
              ),
            ),
          );
        } catch (e) {
          if (!mounted) return;
          if (isKycRequiredError(e)) {
            await showKycRequiredDialog(context, actionLabel: 'accept an order');
          } else {
            final msg = e is DioException ? dioErrorMessage(e) : '$e';
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
          }
        }
      }
      ref.invalidate(myTripsProvider);
      ref.invalidate(myPlannedTripsProvider);
      ref.invalidate(tripProvider(newTripId));
      ref.invalidate(tripMatchesForTripProvider(newTripId));
      ref.invalidate(ordersByTripProvider(newTripId));
      if (pendingShipment != null && pendingShipment.isNotEmpty) {
        ref.invalidate(shipmentDetailProvider(pendingShipment));
        ref.invalidate(shipmentMatchesProvider(pendingShipment));
        ref.invalidate(orderByShipmentProvider(pendingShipment));
      }
      if (!mounted) return;
      if (pendingShipment == null || pendingShipment.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip created')),
        );
      }
      context.go('/trip/$newTripId');
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (isKycRequiredError(e)) {
        await showKycRequiredDialog(context, actionLabel: 'create a trip');
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(dioErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: const Text('Create New Trip'),
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
                      _heroHeader(context),
                      const SizedBox(height: CreateFormUi.sectionGap),
                      // Row 1: Origin | Destination
                      CreateFormUi.pairRow(
                        wide: wide,
                        first: _RouteCityCard(
                          label: 'Origin',
                          selected: _fromSelected,
                          options: _fromOptions(),
                          errorText: _errors['fromCity'],
                          onChanged: (city) {
                            setState(() {
                              _fromSelected = city;
                              if (city != null) _errors.remove('fromCity');
                              if (_toSelected != null && city != null) {
                                final sameSide = (_toSelected!.countryCode ==
                                        kIndiaCountryCode) ==
                                    (city.countryCode == kIndiaCountryCode);
                                if (sameSide) _toSelected = null;
                              }
                            });
                          },
                          onClear: () => setState(() => _fromSelected = null),
                        ),
                        second: _RouteCityCard(
                          label: 'Destination',
                          selected: _toSelected,
                          options: _toOptions(),
                          errorText: _errors['toCity'],
                          onChanged: (city) {
                            setState(() {
                              _toSelected = city;
                              if (city != null) _errors.remove('toCity');
                              if (_fromSelected != null && city != null) {
                                final sameSide = (_fromSelected!.countryCode ==
                                        kIndiaCountryCode) ==
                                    (city.countryCode == kIndiaCountryCode);
                                if (sameSide) _fromSelected = null;
                              }
                            });
                          },
                          onClear: () => setState(() => _toSelected = null),
                        ),
                      ),
                      const SizedBox(height: CreateFormUi.fieldGap),
                      // Row 2: Travel Dates | PNR & Capacity
                      CreateFormUi.pairRow(
                        wide: wide,
                        first: _TravelDatesCard(
                          travelDate: _travelDate,
                          returnDate: _returnDate,
                          travelDateError: _errors['travelDate'],
                          returnDateError: _errors['returnDate'],
                          onPickTravel: _pickTravelDate,
                          onPickReturn: _pickReturnDate,
                          onClearReturn: () =>
                              setState(() => _returnDate = null),
                        ),
                        second: _PnrCapacityCard(
                          pnrController: _pnr,
                          airlineController: _airline,
                          capWController: _capW,
                          capVController: _capV,
                          capWError: _errors['capacityWeightKg'],
                          capVError: _errors['capacityValueLimit'],
                          uploading: _uploading,
                          uploadProgress: _uploadProgress,
                          boardingPassFileName: _boardingPassFile?.name,
                          boardingPassUploaded: _boardingPassS3Key != null,
                          onPickBoardingPass: _pickAndUploadBoardingPass,
                          onCapWChanged: () => setState(
                              () => _errors.remove('capacityWeightKg')),
                          onCapVChanged: () => setState(
                              () => _errors.remove('capacityValueLimit')),
                        ),
                      ),
                      const SizedBox(height: CreateFormUi.sectionGap),
                      _FormFooter(
                        loading: _loading,
                        onCancel: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/trips/available');
                          }
                        },
                        onSubmit: _submit,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _heroHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.20),
                AppColors.primary.withValues(alpha: 0.10),
              ],
            ),
          ),
          child: Icon(Icons.flight, color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create New Trip',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Add your travel details to start earning',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Card containing a city/country dropdown with an inline clear (X) button —
/// matches the Origin/Destination cards in the web Create New Trip page.
class _RouteCityCard extends StatelessWidget {
  const _RouteCityCard({
    required this.label,
    required this.selected,
    required this.options,
    required this.errorText,
    required this.onChanged,
    required this.onClear,
  });

  final String label;
  final SupportedCity? selected;
  final List<SupportedCity> options;
  final String? errorText;
  final ValueChanged<SupportedCity?> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final value = selected != null
        ? cityCompositeValue(selected!.city, selected!.countryCode)
        : null;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey(value ?? '$label-empty'),
                  initialValue: value,
                  isExpanded: true,
                  decoration: CreateFormUi.inputDecoration(
                    label: label,
                    hint: 'Select city and country',
                  ).copyWith(errorText: errorText),
                  items: [
                    for (final c in options)
                      DropdownMenuItem<String>(
                        value: cityCompositeValue(c.city, c.countryCode),
                        child: Text(c.label),
                      ),
                  ],
                  onChanged: (v) => onChanged(parseCityComposite(v)),
                ),
              ),
              if (selected != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 6),
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Clear $label',
                    onPressed: onClear,
                    color: AppColors.mutedForeground,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TravelDatesCard extends StatelessWidget {
  const _TravelDatesCard({
    required this.travelDate,
    required this.returnDate,
    required this.travelDateError,
    required this.returnDateError,
    required this.onPickTravel,
    required this.onPickReturn,
    required this.onClearReturn,
  });

  final DateTime? travelDate;
  final DateTime? returnDate;
  final String? travelDateError;
  final String? returnDateError;
  final VoidCallback onPickTravel;
  final VoidCallback onPickReturn;
  final VoidCallback onClearReturn;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMMd();
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(
            icon: Icons.calendar_today_outlined,
            title: 'Travel Dates',
          ),
          const SizedBox(height: 16),
          _DateField(
            label: 'Travel date',
            value: travelDate,
            formatter: df,
            errorText: travelDateError,
            onTap: onPickTravel,
          ),
          const SizedBox(height: CreateFormUi.fieldGap),
          _DateField(
            label: 'Return date (optional)',
            value: returnDate,
            formatter: df,
            errorText: returnDateError,
            onTap: onPickReturn,
            trailingClear: returnDate != null ? onClearReturn : null,
          ),
        ],
      ),
    );
  }
}

class _PnrCapacityCard extends StatelessWidget {
  const _PnrCapacityCard({
    required this.pnrController,
    required this.airlineController,
    required this.capWController,
    required this.capVController,
    required this.capWError,
    required this.capVError,
    required this.uploading,
    required this.uploadProgress,
    required this.boardingPassFileName,
    required this.boardingPassUploaded,
    required this.onPickBoardingPass,
    required this.onCapWChanged,
    required this.onCapVChanged,
  });

  final TextEditingController pnrController;
  final TextEditingController airlineController;
  final TextEditingController capWController;
  final TextEditingController capVController;
  final String? capWError;
  final String? capVError;
  final bool uploading;
  final double uploadProgress;
  final String? boardingPassFileName;
  final bool boardingPassUploaded;
  final VoidCallback onPickBoardingPass;
  final VoidCallback onCapWChanged;
  final VoidCallback onCapVChanged;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(icon: Icons.business_outlined, title: 'PNR & Capacity'),
          const SizedBox(height: 16),
          _TwoColRow(
            first: TextField(
              controller: pnrController,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              decoration: CreateFormUi.inputDecoration(
                label: 'PNR',
                hint: 'ABC123',
              ),
            ),
            second: TextField(
              controller: airlineController,
              textInputAction: TextInputAction.next,
              decoration: CreateFormUi.inputDecoration(
                label: 'Airline',
                hint: 'e.g. IndiGo, Air India',
              ),
            ),
          ),
          const SizedBox(height: CreateFormUi.fieldGap),
          _TwoColRow(
            first: TextField(
              controller: capWController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              decoration: CreateFormUi.inputDecoration(
                label: 'Capacity (kg)',
                hint: '5',
              ).copyWith(errorText: capWError),
              onChanged: (_) => onCapWChanged(),
            ),
            second: TextField(
              controller: capVController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              decoration: CreateFormUi.inputDecoration(
                label: 'Value limit (INR)',
                hint: 'Max 50,000',
              ).copyWith(errorText: capVError),
              onChanged: (_) => onCapVChanged(),
            ),
          ),
          const SizedBox(height: CreateFormUi.fieldGap),
          _BoardingPassField(
            uploading: uploading,
            uploadProgress: uploadProgress,
            uploaded: boardingPassUploaded,
            fileName: boardingPassFileName,
            onPick: onPickBoardingPass,
          ),
        ],
      ),
    );
  }
}

class _BoardingPassField extends StatelessWidget {
  const _BoardingPassField({
    required this.uploading,
    required this.uploadProgress,
    required this.uploaded,
    required this.fileName,
    required this.onPick,
  });

  final bool uploading;
  final double uploadProgress;
  final bool uploaded;
  final String? fileName;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Boarding pass (optional)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Stored securely with Zipro only and never shared with senders.',
          style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  alignment: Alignment.centerLeft,
                ),
                onPressed: uploading ? null : onPick,
                icon: uploading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: uploadProgress > 0 ? uploadProgress : null,
                        ),
                      )
                    : const Icon(Icons.upload_file_outlined),
                label: Text(
                  uploaded ? (fileName ?? 'Uploaded') : 'Choose file',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (uploaded)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  'Uploaded',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.formatter,
    required this.errorText,
    required this.onTap,
    this.trailingClear,
  });

  final String label;
  final DateTime? value;
  final DateFormat formatter;
  final String? errorText;
  final VoidCallback onTap;
  final VoidCallback? trailingClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.foreground,
                ),
              ),
            ),
            if (trailingClear != null)
              TextButton(
                onPressed: trailingClear,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.mutedForeground,
                ),
                child: const Text('Clear', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: errorText != null
                    ? AppColors.destructive
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: AppColors.mutedForeground,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value == null ? 'Pick a date' : formatter.format(value!),
                    style: TextStyle(
                      fontSize: 14,
                      color: value == null
                          ? AppColors.mutedForeground
                          : AppColors.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              errorText!,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.destructive,
              ),
            ),
          ),
      ],
    );
  }
}

class _FormFooter extends StatelessWidget {
  const _FormFooter({
    required this.loading,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool loading;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: loading ? null : onCancel,
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.accentForeground,
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: loading ? null : onSubmit,
            icon: loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accentForeground,
                    ),
                  )
                : const Icon(Icons.flight, size: 18),
            label: Text(loading ? 'Creating…' : 'Create Trip'),
          ),
        ),
      ],
    );
  }
}

/// White card with rounded border and subtle shadow, mirrors web `<Card className="p-6">`.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.foreground.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _TwoColRow extends StatelessWidget {
  const _TwoColRow({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 12),
        Expanded(child: second),
      ],
    );
  }
}

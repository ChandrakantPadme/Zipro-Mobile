import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../core/models/kyc_dto.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/create_form_ui.dart';
import '../auth/presentation/auth_notifier.dart';
import '../auth/presentation/auth_providers.dart';
import 'data/upload_repository.dart';
import 'kyc_completion.dart';
import 'kyc_country_utils.dart';
import 'kyc_status_provider.dart';

class PersonalInfoDraft {
  const PersonalInfoDraft({
    required this.legalName,
    required this.address,
    required this.country,
    required this.postalCode,
    required this.countryCodePhone,
    required this.phone,
    required this.email,
  });

  final String legalName;
  final String address;
  final String country;
  final String postalCode;
  final String countryCodePhone;
  final String phone;
  final String email;
}

const _countries = [
  ('US', 'United States'),
  ('IN', 'India'),
  ('GB', 'United Kingdom'),
  ('AE', 'United Arab Emirates'),
  ('SG', 'Singapore'),
  ('AU', 'Australia'),
];

class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key});

  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen> {
  int _wizardStep = 0;
  final _legalCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _phoneCcCtrl = TextEditingController(text: '+91');
  final _emailCtrl = TextEditingController();
  String _country = 'IN';
  String _bankCountryIso = 'IN';
  final _passportNumberCtrl = TextEditingController();
  PlatformFile? _passportFile;
  Uint8List? _selfieBytes;
  String? _selfieName;
  String? _passportRef;
  String? _selfieRef;
  final _bankNameCtrl = TextEditingController();
  final _holderCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _routingCtrl = TextEditingController();
  final _swiftCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  bool _indiaUpi = false;
  bool _busy = false;
  double _uploadProgress = 0;
  String? _error;

  bool _profileSeeded = false;

  @override
  void dispose() {
    _legalCtrl.dispose();
    _addressCtrl.dispose();
    _postalCtrl.dispose();
    _phoneCtrl.dispose();
    _phoneCcCtrl.dispose();
    _emailCtrl.dispose();
    _passportNumberCtrl.dispose();
    _bankNameCtrl.dispose();
    _holderCtrl.dispose();
    _accountCtrl.dispose();
    _routingCtrl.dispose();
    _swiftCtrl.dispose();
    _ibanCtrl.dispose();
    _upiCtrl.dispose();
    super.dispose();
  }

  PersonalInfoDraft? _collectPersonal(AuthNotifier auth) {
    final legal = _legalCtrl.text.trim();
    final addr = _addressCtrl.text.trim();
    if (legal.isEmpty ||
        addr.isEmpty ||
        _country.isEmpty ||
        _postalCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please complete personal information');
      return null;
    }
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Phone is required');
      return null;
    }
    setState(() => _error = null);
    return PersonalInfoDraft(
      legalName: legal,
      address: addr,
      country: _country,
      postalCode: _postalCtrl.text.trim(),
      countryCodePhone: _phoneCcCtrl.text.trim(),
      phone: phone,
      email: _emailCtrl.text.trim().isEmpty
          ? (auth.user?.email ?? '')
          : _emailCtrl.text.trim(),
    );
  }

  Future<void> _uploadPassport(UploadRepository up) async {
    final file = _passportFile;
    if (file == null || file.bytes == null) {
      setState(() => _error = 'Select a passport image or PDF');
      return;
    }
    final name = file.name.isNotEmpty ? file.name : 'passport_upload';
    final mime =
        lookupMimeType(name, headerBytes: file.bytes!.take(20).toList()) ??
            'application/octet-stream';
    setState(() {
      _busy = true;
      _uploadProgress = 0;
      _error = null;
    });
    try {
      final path = await up.uploadBytesAndGetS3Path(
        bytes: file.bytes!.toList(),
        fileName: name,
        contentType: mime,
        onSendProgress: (c, t) {
          if (t > 0 && mounted) {
            setState(() => _uploadProgress = c / t);
          }
        },
      );
      if (!mounted) return;
      setState(() {
        _passportRef = path;
        _wizardStep = 2;
        _busy = false;
        _uploadProgress = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _uploadSelfie(UploadRepository up) async {
    final bytes = _selfieBytes;
    if (bytes == null || bytes.isEmpty) {
      setState(() => _error = 'Take a selfie with your camera');
      return;
    }
    final name = _selfieName ?? 'selfie.jpg';
    final mime = lookupMimeType(name, headerBytes: bytes.take(20).toList()) ??
        'image/jpeg';
    setState(() {
      _busy = true;
      _uploadProgress = 0;
      _error = null;
    });
    try {
      final path = await up.uploadBytesAndGetS3Path(
        bytes: bytes.toList(),
        fileName: name,
        contentType: mime,
        onSendProgress: (c, t) {
          if (t > 0 && mounted) setState(() => _uploadProgress = c / t);
        },
      );
      if (!mounted) return;
      setState(() {
        _selfieRef = path;
        _wizardStep = 3;
        _busy = false;
        _uploadProgress = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _submitKyc(AuthNotifier auth, PersonalInfoDraft p) async {
    if (_passportRef == null || _selfieRef == null) {
      setState(() => _error = 'Missing document uploads');
      return;
    }
    final passportNum = _passportNumberCtrl.text.trim();
    if (passportNum.isEmpty) {
      setState(() => _error = 'Passport number required');
      return;
    }

    final bankCountry = _bankCountryIso;
    if (_indiaUpi && bankCountry == 'IN') {
      if (_upiCtrl.text.trim().isEmpty) {
        setState(() => _error = 'UPI ID required');
        return;
      }
    } else {
      if (_bankNameCtrl.text.trim().isEmpty ||
          _holderCtrl.text.trim().isEmpty ||
          _accountCtrl.text.trim().isEmpty) {
        setState(() => _error = 'Complete bank details');
        return;
      }
    }

    final addressParts = p.address
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final street = addressParts.isNotEmpty ? addressParts.first : p.address;
    final city = addressParts.length > 1 ? addressParts[1] : p.address;
    final statePart = addressParts.length > 2 ? addressParts[2] : p.country;

    final userPhone = auth.user?.phone ?? p.phone;
    final userCc = auth.user?.countryCode ?? p.countryCodePhone;

    final payload = CreateKycPayload(
      legalName: p.legalName,
      nationality: countryCode2ToAlpha3(p.country),
      countryResidence: countryCode2ToAlpha3(p.country),
      phoneNumberCode: userCc.isNotEmpty ? userCc : p.countryCodePhone,
      phoneNumber: userPhone,
      address: KycAddressDto(
        street: street,
        city: city,
        state: statePart,
        postalCode: p.postalCode,
        country: p.country,
      ),
      selfieImageRef: _selfieRef,
      passportImageRef: _passportRef,
      metadata: {
        'email': auth.user?.email ?? p.email,
        'passportNumber': passportNum,
        'bankAccount': {
          'bankCountry': bankCountry,
          'paymentMethod': _indiaUpi && bankCountry == 'IN' ? 'upi' : 'bank',
          if (_indiaUpi && bankCountry == 'IN') 'upiId': _upiCtrl.text.trim(),
          'bankName': _bankNameCtrl.text.trim(),
          'accountHolderName': _holderCtrl.text.trim(),
          'accountNumber': _accountCtrl.text.trim(),
          'routingNumber': _routingCtrl.text.trim().isEmpty
              ? null
              : _routingCtrl.text.trim(),
          'swiftCode':
              _swiftCtrl.text.trim().isEmpty ? null : _swiftCtrl.text.trim(),
          'iban': _ibanCtrl.text.trim().isEmpty ? null : _ibanCtrl.text.trim(),
        },
      },
    );

    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(kycRepositoryProvider);
    final res = await repo.createKyc(payload);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!res.success) {
      setState(() =>
          _error = res.message.isNotEmpty ? res.message : 'KYC submit failed');
      return;
    }
    ref.invalidate(kycRecordProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(res.message.isNotEmpty ? res.message : 'KYC submitted')),
    );
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(kycRecordProvider);
    final auth = ref.watch(authNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('KYC'),
      ),
      body: Stack(
        children: [
          async.when(
            data: (kyc) {
              if (kyc != null &&
                  !needsKycCompletion(kyc) &&
                  (kyc.verified ||
                      kyc.status == 'VERIFIED' ||
                      kyc.status == 'SUBMITTED' ||
                      kyc.status == 'UNDER_REVIEW')) {
                final pending =
                    {'SUBMITTED', 'UNDER_REVIEW'}.contains(kyc.status);
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pending ? 'Verification in progress' : 'Verified',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Status: ${kyc.status}'),
                      if (kyc.rejectionReason != null &&
                          kyc.rejectionReason!.isNotEmpty)
                        Text('Reason: ${kyc.rejectionReason}',
                            style: TextStyle(color: AppColors.destructive)),
                    ],
                  ),
                );
              }
              if (!_profileSeeded && auth.user != null) {
                _profileSeeded = true;
                final u = auth.user!;
                if (u.email != null &&
                    u.email!.isNotEmpty &&
                    _emailCtrl.text.isEmpty) {
                  _emailCtrl.text = u.email!;
                }
                if (u.phone != null &&
                    u.phone!.isNotEmpty &&
                    _phoneCtrl.text.isEmpty) {
                  _phoneCtrl.text = u.phone!;
                }
                final cc = u.countryCode;
                if (cc != null && cc.isNotEmpty) _phoneCcCtrl.text = cc;
              }

              return _buildWizard(auth);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          if (_busy)
            Container(
              color: Colors.black26,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        if (_uploadProgress > 0 && _uploadProgress < 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child:
                                LinearProgressIndicator(value: _uploadProgress),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWizard(AuthNotifier auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Step ${_wizardStep + 1} of 4',
            style: TextStyle(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 16),
          if (_wizardStep == 0) ...[
            TextField(
              controller: _legalCtrl,
              textInputAction: TextInputAction.next,
              decoration: CreateFormUi.inputDecoration(
                label: 'Legal name (as on passport)',
              ),
            ),
            const SizedBox(height: CreateFormUi.fieldGap),
            TextField(
              controller: _addressCtrl,
              decoration: CreateFormUi.inputDecoration(
                label: 'Full address',
                alignLabelWithHint: true,
              ),
              maxLines: 2,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: CreateFormUi.fieldGap),
            DropdownButtonFormField<String>(
              decoration: CreateFormUi.inputDecoration(label: 'Country'),
              value: _country,
              items: [
                for (final c in _countries)
                  DropdownMenuItem(value: c.$1, child: Text(c.$2)),
              ],
              onChanged: (v) => setState(() => _country = v ?? 'IN'),
            ),
            const SizedBox(height: CreateFormUi.fieldGap),
            TextField(
              controller: _postalCtrl,
              textInputAction: TextInputAction.next,
              decoration: CreateFormUi.inputDecoration(label: 'Postal code'),
            ),
            const SizedBox(height: CreateFormUi.fieldGap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 96,
                  child: TextField(
                    controller: _phoneCcCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: CreateFormUi.inputDecoration(label: 'Code'),
                  ),
                ),
                const SizedBox(width: CreateFormUi.fieldGap),
                Expanded(
                  child: TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: CreateFormUi.inputDecoration(label: 'Phone'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: CreateFormUi.fieldGap),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              decoration: CreateFormUi.inputDecoration(label: 'Email'),
            ),
            const SizedBox(height: CreateFormUi.sectionGap),
            FilledButton(
              onPressed: () {
                final p = _collectPersonal(auth);
                if (p != null) setState(() => _wizardStep = 1);
              },
              child: const Text('Continue'),
            ),
          ],
          if (_wizardStep == 1) ...[
            TextField(
              controller: _passportNumberCtrl,
              decoration:
                  CreateFormUi.inputDecoration(label: 'Passport number'),
            ),
            const SizedBox(height: CreateFormUi.fieldGap),
            OutlinedButton.icon(
              onPressed: () async {
                final r = await FilePicker.platform.pickFiles(
                  withData: true,
                  type: FileType.custom,
                  allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
                );
                if (r != null && r.files.isNotEmpty) {
                  final f = r.files.first;
                  if (f.size > 10 * 1024 * 1024) {
                    setState(() => _error = 'Max file size 10MB');
                    return;
                  }
                  setState(() {
                    _passportFile = f;
                    _error = null;
                  });
                }
              },
              icon: const Icon(Icons.upload_file),
              label: Text(
                _passportFile == null
                    ? 'Upload passport (PDF/JPEG/PNG)'
                    : _passportFile!.name,
              ),
            ),
            const SizedBox(height: CreateFormUi.sectionGap),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _wizardStep = 0),
                  child: const Text('Back'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () {
                          if (_passportNumberCtrl.text.trim().isEmpty) {
                            setState(() => _error = 'Enter passport number');
                            return;
                          }
                          if (_passportFile?.bytes == null) {
                            setState(() => _error = 'Upload passport');
                            return;
                          }
                          _uploadPassport(ref.read(uploadRepositoryProvider));
                        },
                  child: const Text('Continue'),
                ),
              ],
            ),
          ],
          if (_wizardStep == 2) ...[
            const Text('Take a clear selfie holding your ID.'),
            const SizedBox(height: CreateFormUi.fieldGap),
            OutlinedButton.icon(
              onPressed: () async {
                final picker = ImagePicker();
                final x = await picker.pickImage(
                  source: ImageSource.camera,
                  preferredCameraDevice: CameraDevice.front,
                  maxWidth: 1600,
                  imageQuality: 85,
                );
                if (x != null) {
                  final b = await x.readAsBytes();
                  setState(() {
                    _selfieBytes = b;
                    _selfieName = x.name.isNotEmpty ? x.name : 'selfie.jpg';
                    _error = null;
                  });
                }
              },
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Take selfie'),
            ),
            if (_selfieBytes != null)
              Padding(
                padding: const EdgeInsets.only(top: CreateFormUi.fieldGap),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Selfie captured. Tap Continue to upload, or retake.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setState(() {
                          _selfieBytes = null;
                          _selfieName = null;
                        }),
                        child: const Text('Retake selfie'),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: CreateFormUi.sectionGap),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _wizardStep = 1),
                  child: const Text('Back'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _uploadSelfie(ref.read(uploadRepositoryProvider)),
                  child: const Text('Continue'),
                ),
              ],
            ),
          ],
          if (_wizardStep == 3) ...[
            DropdownButtonFormField<String>(
              decoration: CreateFormUi.inputDecoration(label: 'Bank country'),
              value: _bankCountryIso,
              items: [
                for (final c in _countries)
                  DropdownMenuItem(value: c.$1, child: Text(c.$2)),
              ],
              onChanged: (v) =>
                  setState(() => _bankCountryIso = v ?? 'IN'),
            ),
            if (_bankCountryIso == 'IN') ...[
              const SizedBox(height: CreateFormUi.fieldGap),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _indiaUpi,
                onChanged: (v) => setState(() => _indiaUpi = v ?? false),
                title: const Text('Use UPI'),
              ),
              if (_indiaUpi) ...[
                const SizedBox(height: CreateFormUi.fieldGap),
                TextField(
                  controller: _upiCtrl,
                  decoration: CreateFormUi.inputDecoration(label: 'UPI ID'),
                ),
              ] else ...[
                const SizedBox(height: CreateFormUi.fieldGap),
                TextField(
                  controller: _bankNameCtrl,
                  decoration: CreateFormUi.inputDecoration(label: 'Bank name'),
                ),
                const SizedBox(height: CreateFormUi.fieldGap),
                TextField(
                  controller: _holderCtrl,
                  decoration:
                      CreateFormUi.inputDecoration(label: 'Account holder'),
                ),
                const SizedBox(height: CreateFormUi.fieldGap),
                TextField(
                  controller: _accountCtrl,
                  decoration:
                      CreateFormUi.inputDecoration(label: 'Account number'),
                ),
              ],
            ] else ...[
              const SizedBox(height: CreateFormUi.fieldGap),
              TextField(
                controller: _bankNameCtrl,
                decoration: CreateFormUi.inputDecoration(label: 'Bank name'),
              ),
              const SizedBox(height: CreateFormUi.fieldGap),
              TextField(
                controller: _holderCtrl,
                decoration:
                    CreateFormUi.inputDecoration(label: 'Account holder'),
              ),
              const SizedBox(height: CreateFormUi.fieldGap),
              TextField(
                controller: _accountCtrl,
                decoration:
                    CreateFormUi.inputDecoration(label: 'Account / IBAN'),
              ),
              const SizedBox(height: CreateFormUi.fieldGap),
              TextField(
                controller: _ibanCtrl,
                decoration: CreateFormUi.inputDecoration(
                  label: 'IBAN (if applicable)',
                ),
              ),
              const SizedBox(height: CreateFormUi.fieldGap),
              TextField(
                controller: _swiftCtrl,
                decoration: CreateFormUi.inputDecoration(label: 'SWIFT/BIC'),
              ),
              const SizedBox(height: CreateFormUi.fieldGap),
              TextField(
                controller: _routingCtrl,
                decoration:
                    CreateFormUi.inputDecoration(label: 'Routing (US etc.)'),
              ),
            ],
            const SizedBox(height: CreateFormUi.sectionGap),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _wizardStep = 2),
                  child: const Text('Back'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () {
                          final p = PersonalInfoDraft(
                            legalName: _legalCtrl.text.trim(),
                            address: _addressCtrl.text.trim(),
                            country: _country,
                            postalCode: _postalCtrl.text.trim(),
                            countryCodePhone: _phoneCcCtrl.text.trim(),
                            phone: _phoneCtrl.text.trim(),
                            email: _emailCtrl.text.trim(),
                          );
                          if (_collectPersonal(auth) == null) return;
                          _submitKyc(auth, p);
                        },
                  child: const Text('Submit KYC'),
                ),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: AppColors.destructive)),
          ],
        ],
      ),
    );
  }
}

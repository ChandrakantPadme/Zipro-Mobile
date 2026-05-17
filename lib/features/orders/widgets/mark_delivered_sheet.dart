import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../../core/network/dio_error_mapper.dart';
import '../../../core/theme/app_theme.dart';
import '../../kyc/kyc_status_provider.dart';
import '../../repositories_providers.dart';

/// Mirrors [zipro_website_new/components/orders/mark-delivered-form.tsx]:
/// 6-digit OTP from the sender + delivery confirmation photo + a
/// "Generate delivery OTP" affordance to email the OTP to the sender.
Future<bool> showMarkDeliveredSheet(
  BuildContext context, {
  required String orderId,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _MarkDeliveredSheetBody(orderId: orderId),
    ),
  );
  return result ?? false;
}

class _MarkDeliveredSheetBody extends ConsumerStatefulWidget {
  const _MarkDeliveredSheetBody({required this.orderId});

  final String orderId;

  @override
  ConsumerState<_MarkDeliveredSheetBody> createState() =>
      _MarkDeliveredSheetBodyState();
}

class _MarkDeliveredSheetBodyState
    extends ConsumerState<_MarkDeliveredSheetBody> {
  final _otpController = TextEditingController();
  String? _photoKey;
  String? _photoName;
  bool _uploading = false;
  bool _submitting = false;
  bool _generatingOtp = false;
  bool _otpSent = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    if (_uploading || _submitting) return;
    setState(() => _uploading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf', 'webp'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _uploading = false);
        return;
      }
      final picked = result.files.first;
      final bytes = picked.bytes ??
          (picked.path != null ? await File(picked.path!).readAsBytes() : null);
      if (bytes == null) {
        setState(() => _uploading = false);
        return;
      }
      final contentType =
          lookupMimeType(picked.name) ?? 'application/octet-stream';
      final repo = ref.read(uploadRepositoryProvider);
      final fileKey = await repo.uploadBytesAndGetFileKey(
        bytes: bytes,
        fileName: picked.name,
        contentType: contentType,
      );
      if (!mounted) return;
      setState(() {
        _photoKey = fileKey;
        _photoName = picked.name;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      _showError(e);
    }
  }

  Future<void> _captureFromCamera() async {
    if (_uploading || _submitting) return;
    setState(() => _uploading = true);
    try {
      final picker = ImagePicker();
      final shot = await picker.pickImage(source: ImageSource.camera);
      if (shot == null) {
        setState(() => _uploading = false);
        return;
      }
      final bytes = await shot.readAsBytes();
      final contentType = lookupMimeType(shot.name) ?? 'image/jpeg';
      final repo = ref.read(uploadRepositoryProvider);
      final fileKey = await repo.uploadBytesAndGetFileKey(
        bytes: bytes,
        fileName: shot.name,
        contentType: contentType,
      );
      if (!mounted) return;
      setState(() {
        _photoKey = fileKey;
        _photoName = shot.name;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      _showError(e);
    }
  }

  Future<void> _generateOtp() async {
    if (_generatingOtp) return;
    setState(() => _generatingOtp = true);
    try {
      final repo = ref.read(orderRepositoryProvider);
      final res = await repo.generateDeliveryOtp(widget.orderId);
      if (!mounted) return;
      setState(() {
        _generatingOtp = false;
        _otpSent = res.success;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(res.message.isNotEmpty ? res.message : 'OTP sent to sender'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _generatingOtp = false);
      _showError(e);
    }
  }

  Future<void> _submit() async {
    if (_submitting || _uploading) return;
    final otp = _otpController.text.trim();
    if (otp.length != 6 || _photoKey == null) return;
    setState(() => _submitting = true);
    try {
      final repo = ref.read(orderRepositoryProvider);
      final res = await repo.markDelivered(
        widget.orderId,
        otp: otp,
        deliveryPhotoS3Key: _photoKey,
      );
      if (!mounted) return;
      if (res.success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(res.message.isNotEmpty ? res.message : 'Marked delivered'),
          ),
        );
      } else {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message.isNotEmpty
                ? res.message
                : 'Failed to mark delivered'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError(e);
    }
  }

  void _showError(Object e) {
    final msg = e is DioException ? dioErrorMessage(e) : '$e';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _otpController.text.trim().length == 6 &&
        _photoKey != null &&
        !_uploading &&
        !_submitting;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.task_alt, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Mark product delivered',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Enter the 6-digit OTP from the sender and upload a delivery confirmation photo.',
                style:
                    TextStyle(fontSize: 13, color: AppColors.mutedForeground),
              ),
              const SizedBox(height: 16),
              const Text(
                'OTP from sender',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w700,
                ),
                decoration: const InputDecoration(
                  hintText: '123456',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              const Text(
                'Delivery confirmation photo',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _uploading || _submitting ? null : _pickAndUpload,
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: Text(_uploading ? 'Uploading…' : 'Choose file'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _uploading || _submitting ? null : _captureFromCamera,
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Camera'),
                    ),
                  ),
                ],
              ),
              if (_photoKey != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Photo attached: ${_photoName ?? 'file'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.vpn_key_outlined,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          const Text(
                            'Generate OTP (Sender)',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _otpSent
                            ? 'OTP sent to sender. Ask the sender for the OTP and enter it above.'
                            : 'The sender will receive a delivery OTP via email after you tap "Generate delivery OTP".',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _generatingOtp || _submitting
                              ? null
                              : _generateOtp,
                          icon: _generatingOtp
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.outgoing_mail, size: 16),
                          label: Text(_otpSent
                              ? 'Resend delivery OTP'
                              : 'Generate delivery OTP'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: canSubmit ? _submit : null,
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Mark delivered'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

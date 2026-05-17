import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/dio_error_mapper.dart';
import '../../../core/theme/app_theme.dart';
import '../../kyc/kyc_status_provider.dart';
import '../../repositories_providers.dart';

/// Mirrors [zipro_website_new/components/orders/mark-received-form.tsx]:
/// upload a photo / pdf to S3, accept the carrier declaration, then call
/// `markReceived` with the resulting `receiptS3Key`.
Future<bool> showMarkReceivedSheet(
  BuildContext context, {
  required String orderId,
  required WidgetRef ref,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _MarkReceivedSheetBody(orderId: orderId),
    ),
  );
  return result ?? false;
}

class _MarkReceivedSheetBody extends ConsumerStatefulWidget {
  const _MarkReceivedSheetBody({required this.orderId});

  final String orderId;

  @override
  ConsumerState<_MarkReceivedSheetBody> createState() =>
      _MarkReceivedSheetBodyState();
}

class _MarkReceivedSheetBodyState
    extends ConsumerState<_MarkReceivedSheetBody> {
  String? _fileKey;
  String? _fileName;
  bool _uploading = false;
  bool _submitting = false;
  bool _declarationAccepted = false;

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
        _fileKey = fileKey;
        _fileName = picked.name;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      final msg = e is DioException ? dioErrorMessage(e) : '$e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
        _fileKey = fileKey;
        _fileName = shot.name;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      final msg = e is DioException ? dioErrorMessage(e) : '$e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _submit() async {
    if (_submitting || _uploading) return;
    if (_fileKey == null || !_declarationAccepted) return;
    setState(() => _submitting = true);
    try {
      final repo = ref.read(orderRepositoryProvider);
      final res = await repo.markReceived(
        widget.orderId,
        receiptS3Key: _fileKey!,
        carrierDeclarationAccepted: true,
      );
      if (!mounted) return;
      if (res.success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  res.message.isNotEmpty ? res.message : 'Marked received')),
        );
      } else {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(res.message.isNotEmpty
                  ? res.message
                  : 'Failed to mark received')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final msg = e is DioException ? dioErrorMessage(e) : '$e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit =
        _fileKey != null && _declarationAccepted && !_uploading && !_submitting;
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
                  Icon(Icons.inventory_2_outlined,
                      color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Mark product received',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Confirm you have received the parcel from the sender. Upload a photo.',
                style:
                    TextStyle(fontSize: 13, color: AppColors.mutedForeground),
              ),
              const SizedBox(height: 16),
              const Text(
                'Photo',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
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
              if (_fileKey != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Attached: ${_fileName ?? 'file'}',
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
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _declarationAccepted,
                        onChanged: _submitting
                            ? null
                            : (v) => setState(
                                () => _declarationAccepted = v ?? false),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.foreground,
                                height: 1.4,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'I have read and accept the ',
                                ),
                                TextSpan(
                                  text: 'Carrier Declaration Form',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                const TextSpan(
                                  text:
                                      ', and I confirm that I will comply with Zipro\u2019s terms as a carrier.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(
                      'https://zipro.in/carrier-declaration-form.pdf',
                    );
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Read declaration form'),
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
                          : const Text('Mark received'),
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

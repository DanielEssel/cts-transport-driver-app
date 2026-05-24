// lib/features/driver/presentation/driver_documents_screens.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../app/app_routes.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DOCUMENT DEFINITIONS
// ─────────────────────────────────────────────────────────────────────────────

class _Doc {
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool required;
  final bool hasExpiry;

  const _Doc({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.required = true,
    this.hasExpiry = false,
  });
}

const _docs = [
  _Doc(
    key: 'profile_photo',
    title: 'Profile Photo',
    subtitle: 'Clear face photo, no sunglasses or hats',
    icon: Icons.person_rounded,
  ),
  _Doc(
    key: 'national_id',
    title: 'National ID / Passport',
    subtitle: 'Ghana Card, Voter ID, or International Passport',
    icon: Icons.badge_rounded,
    hasExpiry: true,
  ),
  _Doc(
    key: 'drivers_license',
    title: "Driver's License",
    subtitle: 'Must be valid and not expired — all vehicle classes',
    icon: Icons.drive_eta_rounded,
    hasExpiry: true,
  ),
  _Doc(
    key: 'vehicle_registration',
    title: 'Vehicle Registration',
    subtitle: 'DVLA registration certificate for your vehicle',
    icon: Icons.article_rounded,
    hasExpiry: true,
  ),
  _Doc(
    key: 'roadworthy_certificate',
    title: 'Roadworthy Certificate',
    subtitle: 'Valid DVLA roadworthy — required for Ghana operations',
    icon: Icons.verified_rounded,
    hasExpiry: true,
  ),
  _Doc(
    key: 'insurance',
    title: 'Vehicle Insurance',
    subtitle: 'Minimum third-party insurance certificate',
    icon: Icons.shield_rounded,
    hasExpiry: true,
  ),
  _Doc(
    key: 'police_clearance',
    title: 'Police Clearance',
    subtitle: 'Criminal background check from Ghana Police Service',
    icon: Icons.security_rounded,
    hasExpiry: true,
  ),
  _Doc(
    key: 'vehicle_photo_front',
    title: 'Vehicle Photo (Front)',
    subtitle: 'Clear photo showing front of vehicle and plate number',
    icon: Icons.directions_car_rounded,
    required: false,
  ),
  _Doc(
    key: 'vehicle_photo_side',
    title: 'Vehicle Photo (Side)',
    subtitle: 'Clear side-on photo showing full vehicle',
    icon: Icons.car_repair_rounded,
    required: false,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// DOCUMENT STATE MODEL
// ─────────────────────────────────────────────────────────────────────────────

enum _DocStatus { empty, uploading, uploaded, rejected }

class _DocState {
  final _DocStatus status;
  final String? url;
  final String? rejectionReason;
  final DateTime? expiryDate;
  final File? localFile;
  final String? fileType; // 'image' | 'pdf'

  const _DocState({
    this.status = _DocStatus.empty,
    this.url,
    this.rejectionReason,
    this.expiryDate,
    this.localFile,
    this.fileType,
  });

  _DocState copyWith({
    _DocStatus? status,
    String? url,
    String? rejectionReason,
    DateTime? expiryDate,
    File? localFile,
    String? fileType,
  }) =>
      _DocState(
        status: status ?? this.status,
        url: url ?? this.url,
        rejectionReason: rejectionReason ?? this.rejectionReason,
        expiryDate: expiryDate ?? this.expiryDate,
        localFile: localFile ?? this.localFile,
        fileType: fileType ?? this.fileType,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class DriverDocumentsScreen extends StatefulWidget {
  const DriverDocumentsScreen({super.key});

  @override
  State<DriverDocumentsScreen> createState() => _DriverDocumentsScreenState();
}

class _DriverDocumentsScreenState extends State<DriverDocumentsScreen> {
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  final _storage = FirebaseStorage.instance;
  final _db = FirebaseFirestore.instance;
  final _picker = ImagePicker();

  final Map<String, _DocState> _states = {
    for (final d in _docs) d.key: const _DocState()
  };

  bool _submitting = false;

  List<_Doc> get _requiredDocs => _docs.where((d) => d.required).toList();

  bool get _allRequiredUploaded =>
      _requiredDocs.every((d) => _states[d.key]?.status == _DocStatus.uploaded);

  int get _uploadedCount =>
      _docs.where((d) => _states[d.key]?.status == _DocStatus.uploaded).length;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  // ── Load existing ─────────────────────────────────────────────────────────

  Future<void> _loadExisting() async {
    final snap = await _db.collection('drivers').doc(_uid).get();
    final data = snap.data();
    if (data == null || !mounted) return;

    final docs = data['documents'] as Map<String, dynamic>? ?? {};

    setState(() {
      for (final d in _docs) {
        final docData = docs[d.key] as Map<String, dynamic>?;
        if (docData == null) continue;

        final statusStr = docData['status'] as String? ?? 'empty';
        final status = switch (statusStr) {
          'uploaded' => _DocStatus.uploaded,
          'rejected' => _DocStatus.rejected,
          _ => _DocStatus.empty,
        };

        _states[d.key] = _DocState(
          status: status,
          url: docData['url'] as String?,
          rejectionReason: docData['rejectionReason'] as String?,
          expiryDate: (docData['expiryDate'] as Timestamp?)?.toDate(),
          fileType: docData['fileType'] as String?,
        );
      }
    });
  }

  // ── Pick & upload ─────────────────────────────────────────────────────────

  Future<void> _pickAndUpload(_Doc doc) async {
    HapticFeedback.lightImpact();

    File? file;
    String? mimeType;

    final isPhotoOnly = doc.key == 'profile_photo' ||
        doc.key == 'vehicle_photo_front' ||
        doc.key == 'vehicle_photo_side';

    if (isPhotoOnly) {
      // Image only
      final source = await _showSourceDialog();
      if (source == null || !mounted) return;

      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      file = File(picked.path);
      mimeType = 'image/jpeg';
    } else {
      // Image or PDF
      final choice = await _showFileTypeDialog();
      if (choice == null || !mounted) return;

      if (choice == 'image') {
        final source = await _showSourceDialog();
        if (source == null || !mounted) return;

        final picked = await _picker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
        if (picked == null || !mounted) return;
        file = File(picked.path);
        mimeType = 'image/jpeg';
      } else {
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          withData: true, // ← get bytes directly
        );
        if (result == null || result.files.isEmpty || !mounted) return;

        final pickedFile = result.files.single;
        final bytes = pickedFile.bytes;

        if (bytes == null) {
          _showError('Could not read PDF file. Please try again.');
          return;
        }

        // Write bytes to temp file
        final tempDir = await Directory.systemTemp.createTemp('pdf_upload');
        final tempFile = File('${tempDir.path}/${pickedFile.name}');
        await tempFile.writeAsBytes(bytes);

        file = tempFile;
        mimeType = 'application/pdf';
      }
    }

    // File size check — max 10MB
    final sizeBytes = await file.length();
    if (sizeBytes > 10 * 1024 * 1024) {
      _showError('File too large. Maximum size is 10MB.');
      return;
    }

    setState(() {
      _states[doc.key] = _states[doc.key]!.copyWith(
        status: _DocStatus.uploading,
        localFile: file,
      );
    });

    // Expiry date
    DateTime? expiry;
    if (doc.hasExpiry && mounted) {
      expiry = await _showExpiryPicker();
    }

    try {
      final isPdf = mimeType == 'application/pdf';
      final ext = isPdf ? 'pdf' : 'jpg';
      final ref = _storage
          .ref()
          .child('driver_documents')
          .child(_uid)
          .child('${doc.key}.$ext');

      await ref.putFile(file, SettableMetadata(contentType: mimeType));
      final url = await ref.getDownloadURL();

      await _db.collection('drivers').doc(_uid).set({
        'documents': {
          doc.key: {
            'status': 'uploaded',
            'url': url,
            'fileType': isPdf ? 'pdf' : 'image',
            'uploadedAt': FieldValue.serverTimestamp(),
            if (expiry != null) 'expiryDate': Timestamp.fromDate(expiry),
          },
        },
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _states[doc.key] = _DocState(
          status: _DocStatus.uploaded,
          url: url,
          expiryDate: expiry,
          fileType: isPdf ? 'pdf' : 'image',
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text('${doc.title} uploaded successfully'),
        ]),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _states[doc.key] = _states[doc.key]!.copyWith(status: _DocStatus.empty);
      });
      _showError('Upload failed: $e');
    }
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  Future<String?> _showFileTypeDialog() => showModalBottomSheet<String>(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Choose file type',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryDim,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      const Icon(Icons.image_rounded, color: AppColors.primary),
                ),
                title: const Text('Photo / Image'),
                subtitle: const Text('JPG or PNG from camera or gallery'),
                onTap: () => Navigator.pop(context, 'image'),
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded,
                      color: Color(0xFFDC2626)),
                ),
                title: const Text('PDF Document'),
                subtitle: const Text('Scanned or digital PDF'),
                onTap: () => Navigator.pop(context, 'pdf'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );

  Future<ImageSource?> _showSourceDialog() => showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );

  Future<DateTime?> _showExpiryPicker() => showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 365)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
        helpText: 'Document Expiry Date',
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        ),
      );

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_allRequiredUploaded || _submitting) return;
    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);

    try {
      await _db.collection('drivers').doc(_uid).update({
        'documentsUploaded': true,
        'signupStep': 'documentsUploaded',
        'submittedForReviewAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.driverPending, (_) => false);
    } catch (e) {
      if (mounted) _showError('Submission failed. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Documents', style: AppTextStyles.heading4),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                const Text('Upload Documents', style: AppTextStyles.display),
                const SizedBox(height: 8),
                Text(
                  'Upload clear, valid documents for verification. '
                  'All documents are securely stored and '
                  'reviewed within 24 hours.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                _ProgressCard(
                  uploaded: _uploadedCount,
                  total: _docs.length,
                ),
                const SizedBox(height: 24),
                _SectionLabel(
                  title: 'Required Documents',
                  subtitle: 'All ${_requiredDocs.length} must be uploaded',
                  color: AppColors.error,
                ),
                const SizedBox(height: 10),
                ..._requiredDocs.map((d) => _DocTile(
                      doc: d,
                      state: _states[d.key]!,
                      onTap: () => _pickAndUpload(d),
                    )),
                const SizedBox(height: 20),
                const _SectionLabel(
                  title: 'Vehicle Photos',
                  subtitle: 'Recommended for faster approval',
                  color: AppColors.primary,
                ),
                const SizedBox(height: 10),
                ..._docs.where((d) => !d.required).map((d) => _DocTile(
                      doc: d,
                      state: _states[d.key]!,
                      onTap: () => _pickAndUpload(d),
                    )),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDim,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryMuted),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Documents must be valid and not expired. '
                          'Expired documents will be rejected. '
                          'You will be notified if any document '
                          'needs re-uploading.',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.primaryDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _SubmitBar(
            allDone: _allRequiredUploaded,
            submitting: _submitting,
            uploaded: _uploadedCount,
            total: _requiredDocs.length,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROGRESS CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressCard extends StatelessWidget {
  final int uploaded;
  final int total;
  const _ProgressCard({required this.uploaded, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? uploaded / total : 0.0;
    final complete = uploaded == total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: complete ? AppColors.primaryDim : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: complete ? AppColors.primaryMuted : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                complete
                    ? 'All documents uploaded ✓'
                    : '$uploaded of $total documents uploaded',
                style: AppTextStyles.labelMedium.copyWith(
                  color:
                      complete ? AppColors.primaryDark : AppColors.textPrimary,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: AppTextStyles.labelMedium.copyWith(
                  color: complete ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                complete ? AppColors.primary : AppColors.primaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION LABEL
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;

  const _SectionLabel({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 3,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.textPrimary)),
              Text(subtitle,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// DOCUMENT TILE
// ─────────────────────────────────────────────────────────────────────────────

class _DocTile extends StatelessWidget {
  final _Doc doc;
  final _DocState state;
  final VoidCallback onTap;

  const _DocTile({
    required this.doc,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUploaded = state.status == _DocStatus.uploaded;
    final isUploading = state.status == _DocStatus.uploading;
    final isRejected = state.status == _DocStatus.rejected;
    final isPdf = state.fileType == 'pdf';

    final Color borderColor;
    final Color bgColor;
    final Widget statusWidget;

    if (isUploaded) {
      borderColor = AppColors.primaryMuted;
      bgColor = AppColors.primaryDim;
      statusWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primarySubtle,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPdf ? Icons.picture_as_pdf_rounded : Icons.check_circle_rounded,
              color: isPdf ? const Color(0xFFDC2626) : AppColors.primary,
              size: 12,
            ),
            const SizedBox(width: 4),
            Text(
              isPdf ? 'PDF Uploaded' : 'Uploaded',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isPdf ? const Color(0xFFDC2626) : AppColors.primary,
              ),
            ),
          ],
        ),
      );
    } else if (isRejected) {
      borderColor = AppColors.error.withValues(alpha: 0.4);
      bgColor = AppColors.errorLight;
      statusWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.errorLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: const Text('Rejected — tap to re-upload',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.error,
            )),
      );
    } else if (isUploading) {
      borderColor = AppColors.border;
      bgColor = Colors.white;
      statusWidget = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary,
        ),
      );
    } else {
      borderColor = AppColors.border;
      bgColor = Colors.white;
      statusWidget = Text('Tap to upload',
          style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary));
    }

    return GestureDetector(
      onTap: isUploading ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color:
                    isUploaded ? AppColors.primarySubtle : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(11),
              ),
              child: isUploading
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : Icon(
                      isUploaded
                          ? (isPdf
                              ? Icons.picture_as_pdf_rounded
                              : Icons.check_circle_rounded)
                          : doc.icon,
                      color: isUploaded
                          ? (isPdf
                              ? const Color(0xFFDC2626)
                              : AppColors.primary)
                          : AppColors.textSecondary,
                      size: 20,
                    ),
            ),
            const SizedBox(width: 12),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(doc.title, style: AppTextStyles.labelLarge),
                      ),
                      if (!doc.required)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Optional',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textTertiary)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(doc.subtitle,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary)),
                  if (isRejected && state.rejectionReason != null) ...[
                    const SizedBox(height: 4),
                    Text('Reason: ${state.rejectionReason}',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.error)),
                  ],
                  if (isUploaded && state.expiryDate != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.event_rounded,
                            size: 11, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          'Expires ${_formatDate(state.expiryDate!)}',
                          style: AppTextStyles.caption.copyWith(
                            color: _isExpiringSoon(state.expiryDate!)
                                ? AppColors.warning
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  statusWidget,
                ],
              ),
            ),

            // Trailing icon
            if (!isUploading)
              Icon(
                isUploaded
                    ? Icons.edit_rounded
                    : Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  bool _isExpiringSoon(DateTime expiry) =>
      expiry.difference(DateTime.now()).inDays < 30;
}

// ─────────────────────────────────────────────────────────────────────────────
// SUBMIT BAR
// ─────────────────────────────────────────────────────────────────────────────

class _SubmitBar extends StatelessWidget {
  final bool allDone;
  final bool submitting;
  final int uploaded;
  final int total;
  final VoidCallback onSubmit;

  const _SubmitBar({
    required this.allDone,
    required this.submitting,
    required this.uploaded,
    required this.total,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(color: AppColors.border, width: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!allDone) ...[
              Text(
                '$uploaded / $total required documents uploaded',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: allDone && !submitting ? onSubmit : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.border,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        allDone
                            ? 'Submit for Verification'
                            : 'Upload all required documents',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      );
}

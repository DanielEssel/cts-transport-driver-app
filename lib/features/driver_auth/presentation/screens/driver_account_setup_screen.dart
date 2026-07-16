import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/legal/legal_urls.dart';
import '../../../../core/services/driver_service.dart';
import '../../../../core/services/driver_flow_resolver.dart';
import '../../../../shared/widgets/common/shared_widgets.dart'
    hide PrimaryButton;
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/textfields/custom_textfield.dart';
import '../../../../core/validators/driver_account_validator.dart';


class DriverAccountSetupScreen extends StatefulWidget {
  final String phone;
  const DriverAccountSetupScreen({super.key, required this.phone});

  @override
  State<DriverAccountSetupScreen> createState() =>
      _DriverAccountSetupScreenState();
}

class _DriverAccountSetupScreenState extends State<DriverAccountSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _nameFocusNode = FocusNode();

  File? _photo;
  bool _isLoading = false;
  String? _errorMessage;
  String? _photoError;
  bool _agreeToTerms = false;
  String? _termsError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 72,
        maxWidth: 800,
      );

      if (picked != null) {
        setState(() {
          _photo = File(picked.path);
          _photoError = null;
        });
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        switch (e.code) {
          case 'camera_access_denied':
          case 'camera_denied':
            _photoError = 'Camera permission is required to continue.';
            break;
          default:
            _photoError = 'Unable to open the camera. Please try again.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _photoError = 'Something went wrong while opening the camera.';
      });
    }
  }

  Future<String> _uploadPhoto(String uid) async {
    final ref =
        FirebaseStorage.instance.ref().child('drivers/profiles/$uid.jpg');

    await ref.putFile(
      _photo!,
      SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedBy': uid,
          'type': 'driver_profile',
        },
      ),
    );

    return ref.getDownloadURL();
  }

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();

    final formValid = _formKey.currentState!.validate();
    final photoError = await DriverAccountValidator.validatePhoto(_photo);
    if (photoError != null) {
      setState(() => _photoError = photoError);
    }
    if (!_agreeToTerms) {
      setState(() => _termsError = 'You must accept the terms to continue');
    }
    if (!formValid || photoError != null || !_agreeToTerms) {
      HapticFeedback.mediumImpact();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _photoError = null;
      _termsError = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      // ── FIX: was closing the try block here prematurely ──────────────────
      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Your session has expired. Please sign in again.';
        });
        return;
      }

      final photoUrl = await _uploadPhoto(user.uid);

      await DriverService.updateDriver({
        'displayName': DriverAccountValidator.normalizeName(_nameCtrl.text),
        'photoUrl': photoUrl,
        'accountSetupComplete': true,
        'signupStep': 'accountCompleted',
        'termsAcceptedAt': FieldValue.serverTimestamp(),
        'termsVersion': '1.0',
      });

      if (!mounted) return;

      final destination = await AppFlowResolver.resolveDestination(user.uid);

      Navigator.pushNamedAndRemoveUntil(
        context,
        destination.route,
        (_) => false,
        arguments: destination.arguments,
      );
    } on FirebaseException catch (e) {
      setState(() {
        _errorMessage = switch (e.code) {
          'permission-denied' => 'Permission denied. Please try again.',
          'network-request-failed' => 'No internet connection.',
          'unauthorized' => 'You are not authorized to upload this photo.',
          _ => 'Unable to complete setup. Please try again.',
        };
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const OnboardingStepIndicator(current: 2, total: 4),
                          const SizedBox(height: 28),
                          const Text('Set up your\naccount',
                              style: AppTextStyles.display),
                          const SizedBox(height: 8),
                          Text(
                            'How should riders and the platform know you?',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 36),
                          _buildPhotoPicker(),
                          const SizedBox(height: 32),
                          CustomTextField(
                            label: "Full Name",
                            hint: "e.g. Kwame Asante",
                            controller: _nameCtrl,
                            focusNode: _nameFocusNode,
                            keyboardType: TextInputType.name,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(60),
                              FilteringTextInputFormatter.allow(
                                RegExp(r"[A-Za-zÀ-ÿ' -]"),
                              ),
                            ],
                            textInputAction: TextInputAction.done,
                            prefixIcon: const Icon(Icons.person_outline_rounded,
                                size: 20),
                            validator: DriverAccountValidator.validateName,
                          ),
                          if (_errorMessage != null) _buildErrorDisplay(),
                          const Spacer(),
                          const SizedBox(height: 24),

                          _TermsCheckbox(
                            value: _agreeToTerms,
                            error: _termsError,
                            onChanged: (v) => setState(() {
                              _agreeToTerms = v ?? false;
                              if (_agreeToTerms) _termsError = null;
                            }),
                          ),
                          const SizedBox(height: 16),
                        
                          PrimaryButton(
                            label: 'Continue',
                            isLoading: _isLoading,
                            enabled: !_isLoading,
                            onPressed: _continue,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      leading: IconButton(
        onPressed: _isLoading ? null : () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
      ),
    );
  }

  Widget _buildPhotoPicker() {
    final hasError = _photoError != null && _photo == null;
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _isLoading ? null : _pickPhoto,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 54,
                  backgroundColor: AppColors.surfaceAlt,
                  backgroundImage: _photo != null ? FileImage(_photo!) : null,
                  child: _photo == null
                      ? Icon(Icons.person_rounded,
                          size: 50,
                          color: hasError
                              ? AppColors.error
                              : AppColors.textSecondary)
                      : null,
                ),
                if (hasError)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.error, width: 2),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt_rounded,
                        size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _photo != null ? 'Tap to retake' : 'Take a live photo',
            style: AppTextStyles.bodySmall.copyWith(
              color: hasError ? AppColors.error : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hasError) ...[
            const SizedBox(height: 4),
            Text(
              _photoError!,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            const SizedBox(height: 2),
            Text(
              'Required — helps riders and the platform verify you',
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorDisplay() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(_errorMessage!,
          style: const TextStyle(color: Colors.red, fontSize: 13)),
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({
    required this.value,
    this.error,
    required this.onChanged,
  });

  final bool value;
  final String? error;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary,
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                  children: [
                    const TextSpan(text: 'I confirm I am 18 or older and agree to the '),
                    TextSpan(
                      text: 'Terms',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => LegalUrls.open(context, LegalUrls.terms),
                    ),
                    const TextSpan(text: ', '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap =
                            () => LegalUrls.open(context, LegalUrls.privacy),
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Driver Agreement',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () =>
                            LegalUrls.open(context, LegalUrls.driverAgreement),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Text(
              error!,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/services/driver_service.dart';
import '../../../../core/services/app_flow_resolver.dart';
import '../../../../shared/widgets/common/shared_widgets.dart' hide PrimaryButton;
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/textfields/custom_textfield.dart';

class DriverAccountSetupScreen extends StatefulWidget {
  final String phone;
  const DriverAccountSetupScreen({super.key, required this.phone});

  @override
  State<DriverAccountSetupScreen> createState() => _DriverAccountSetupScreenState();
}

class _DriverAccountSetupScreenState extends State<DriverAccountSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _nameFocusNode = FocusNode();

  File? _photo;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 500,
    );
    if (picked != null) {
      setState(() => _photo = File(picked.path));
    }
  }

  Future<String?> _uploadPhoto(String uid) async {
    if (_photo == null) return null;
    try {
      final ref = FirebaseStorage.instance.ref().child('drivers/profiles/$uid.jpg');
      await ref.putFile(_photo!);
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.vibrate();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final photoUrl = await _uploadPhoto(user.uid);

      // ✅ FIX: Update 'signupStep' so AppFlowResolver knows to move forward
      await DriverService.updateDriver({
        'displayName': _nameCtrl.text.trim(),
        if (photoUrl != null) 'photoUrl': photoUrl,
        'accountSetupComplete': true,
        'signupStep': 'accountCompleted', // This breaks the loop
      });

      if (!mounted) return;

      // Use Resolver to find the next screen (likely Vehicle Setup)
      final destination = await AppFlowResolver.resolveDestination(user.uid);
      
      Navigator.pushNamedAndRemoveUntil(
        context, 
        destination.route, 
        (route) => false,
        arguments: destination.arguments,
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not save details. Please check your connection.';
      });
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
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const OnboardingStepIndicator(current: 2, total: 4),
                          const SizedBox(height: 28),
                          const Text('Set up your\naccount', style: AppTextStyles.display),
                          const SizedBox(height: 8),
                          Text(
                            'How should riders and the platform know you?',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
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
                            textInputAction: TextInputAction.done,
                            prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Please enter your name' : null,
                          ),

                          if (_errorMessage != null) _buildErrorDisplay(),

                          const Spacer(), // Pushes button to bottom when keyboard is hidden
                          
                          const SizedBox(height: 24),
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

  // --- UI Helper Methods ---

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
    return Center(
      child: GestureDetector(
        onTap: _isLoading ? null : _pickPhoto,
        child: Stack(
          children: [
            CircleAvatar(
              radius: 54,
              backgroundColor: AppColors.surfaceAlt,
              backgroundImage: _photo != null ? FileImage(_photo!) : null,
              child: _photo == null
                  ? const Icon(Icons.person_rounded, size: 50, color: AppColors.textSecondary)
                  : null,
            ),
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorDisplay() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
    );
  }
}
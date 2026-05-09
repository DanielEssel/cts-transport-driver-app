import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../app/app_routes.dart';

class DriverDocumentsScreen extends StatefulWidget {
  const DriverDocumentsScreen({
    super.key,
  });

  @override
  State<DriverDocumentsScreen> createState() => _DriverDocumentsScreenState();
}

class _DriverDocumentsScreenState extends State<DriverDocumentsScreen> {
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  /// Backend-driven document state
  Map<String, bool> uploads = {
    'license': false,
    'registration': false,
    'insurance': false,
    'profile': false,
  };

  bool get isComplete => uploads.values.every((e) => e == true);

  @override
  void initState() {
    super.initState();
    _loadExistingState();
  }

  /// Load existing progress from Firestore
  Future<void> _loadExistingState() async {
    final doc = await FirebaseFirestore.instance
        .collection('drivers')
        .doc(uid)
        .get();

    final data = doc.data();

    if (data == null) return;

    final docs = data['documents'] as Map<String, dynamic>?;

    if (docs != null) {
      setState(() {
        uploads = {
          'license': docs['license'] ?? false,
          'registration': docs['registration'] ?? false,
          'insurance': docs['insurance'] ?? false,
          'profile': docs['profile'] ?? false,
        };
      });
    }
  }

  /// Upload simulation (replace with Firebase Storage later)
  Future<void> _uploadDoc(String key) async {
    HapticFeedback.lightImpact();

    setState(() {
      uploads[key] = true;
    });

    await FirebaseFirestore.instance
        .collection('drivers')
        .doc(uid)
        .set({
      'documents': uploads,
      'documentsUploaded': isComplete,
      'signupStep': isComplete ? 'documentsUploaded' : 'vehicleSetup',
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$key uploaded"),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  Future<void> _submit() async {
    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryColor,
        ),
      ),
    );

    await FirebaseFirestore.instance
        .collection('drivers')
        .doc(uid)
        .update({
      'documentsUploaded': true,
      'signupStep': 'documentsUploaded',
    });

    if (!mounted) return;

    Navigator.pop(context);

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.driverPending,
      (route) => false,
    );
  }

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
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  "Upload Documents",
                  style: AppTextStyles.display,
                ),
                const SizedBox(height: 8),
                Text(
                  "All documents must be clear and valid for verification.",
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                _tile('license', "Driver's License", Icons.badge),
                _tile('registration', "Vehicle Registration", Icons.article),
                _tile('insurance', "Insurance Certificate", Icons.verified),
                _tile('profile', "Profile Photo", Icons.person),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(24),
            child: ElevatedButton(
              onPressed: isComplete ? _submit : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text("Submit for Verification"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(String key, String title, IconData icon) {
    final done = uploads[key] == true;

    return GestureDetector(
      onTap: () => _uploadDoc(key),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: done ? Colors.green.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: done ? Colors.green : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_circle : icon,
              color: done ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.labelLarge,
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade500,
            ),
          ],
        ),
      ),
    );
  }
}
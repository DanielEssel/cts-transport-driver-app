// lib/features/profile/presentation/screens/driver_edit_screen.dart
//
// Edit the driver's own profile. Scope is deliberately narrow and safe:
//   • Editable: full name, email, vehicle model, plate number
//   • Locked:   phone (auth identity), service & vehicle type (set at
//               onboarding, affect dispatch), verification status, uid
//
// Saves via DriverService.updateDriver(), which targets the current user's
// drivers/{uid} doc and merges — so we pass only the changed fields.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart' as c;
import '../../../../core/services/driver_service.dart';
import '../../../driver/models/driver_types.dart';

class DriverEditScreen extends StatefulWidget {
  final DriverProfile profile;
  const DriverEditScreen({super.key, required this.profile});

  @override
  State<DriverEditScreen> createState() => _DriverEditScreenState();
}

class _DriverEditScreenState extends State<DriverEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _plateCtrl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameCtrl = TextEditingController(text: p.displayName ?? '');
    _emailCtrl = TextEditingController(text: p.email ?? '');
    _modelCtrl = TextEditingController(text: p.vehicleModel ?? '');
    _plateCtrl = TextEditingController(text: p.vehiclePlate ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _modelCtrl.dispose();
    _plateCtrl.dispose();
    super.dispose();
  }

  // ── Validation ────────────────────────────────────────────────────────────
  String? _validateName(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Full name is required';
    if (t.length < 2) return 'Name is too short';
    return null;
  }

  String? _validateEmail(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null; // optional
    final ok = RegExp(r'^[\w.\-+]+@[\w\-]+\.[\w.\-]+$').hasMatch(t);
    return ok ? null : 'Enter a valid email address';
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      return;
    }

    // Build a map of only the fields that actually changed, so we never
    // overwrite unrelated data or write no-op updates.
    final p = widget.profile;
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final model = _modelCtrl.text.trim();
    final plate = _plateCtrl.text.trim().toUpperCase();

    final data = <String, dynamic>{};
    if (name != (p.displayName ?? '')) data['displayName'] = name;
    if (email != (p.email ?? '')) data['email'] = email;
    if (model != (p.vehicleModel ?? '')) data['vehicleModel'] = model;
    if (plate != (p.vehiclePlate ?? '')) data['vehiclePlate'] = plate;

    if (data.isEmpty) {
      Navigator.pop(context); // nothing changed
      return;
    }

    setState(() => _saving = true);
    try {
      await DriverService.updateDriver(data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
      Navigator.pop(context, true); // signal the profile screen to refresh
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return Scaffold(
      backgroundColor: c.AppColors.background,
      appBar: AppBar(
        backgroundColor: c.AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: _saving ? null : () => Navigator.maybePop(context),
        ),
        title: const Text('Edit Profile'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _sectionTitle('Account'),
              _field(
                controller: _nameCtrl,
                label: 'Full Name',
                icon: Icons.person_rounded,
                validator: _validateName,
                textCapitalization: TextCapitalization.words,
              ),
              _field(
                controller: _emailCtrl,
                label: 'Email (optional)',
                icon: Icons.email_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
              ),

              // Phone is the auth identity — shown but not editable here.
              _lockedField(
                label: 'Phone',
                value: p.phone ?? '—',
                icon: Icons.phone_rounded,
                note: 'Contact support to change your phone number',
              ),

              const SizedBox(height: 20),
              _sectionTitle('Vehicle'),

              // Service & vehicle type are set at onboarding and affect
              // dispatch matching — locked here.
              _lockedField(
                label: 'Service Type',
                value: p.serviceLabel,
                icon: Icons.electric_rickshaw_rounded,
              ),
              _lockedField(
                label: 'Vehicle Type',
                value: p.vehicleLabel,
                icon: Icons.directions_car_rounded,
              ),
              _field(
                controller: _modelCtrl,
                label: 'Vehicle Model',
                icon: Icons.car_repair_rounded,
                textCapitalization: TextCapitalization.words,
              ),
              _field(
                controller: _plateCtrl,
                label: 'Plate Number',
                icon: Icons.pin_rounded,
                textCapitalization: TextCapitalization.characters,
              ),

              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Changes',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Small UI helpers ───────────────────────────────────────────────────────
  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Text(
          t.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: c.AppColors.textSecondary,
          ),
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          style: const TextStyle(color: c.AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, size: 18, color: c.AppColors.textSecondary),
            filled: true,
            fillColor: c.AppColors.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: c.AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: c.AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: c.AppColors.primary, width: 1.4),
            ),
          ),
        ),
      );

  Widget _lockedField({
    required String label,
    required String value,
    required IconData icon,
    String? note,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: c.AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: c.AppColors.textTertiary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: const TextStyle(
                                fontSize: 11,
                                color: c.AppColors.textTertiary)),
                        const SizedBox(height: 2),
                        Text(value,
                            style: const TextStyle(
                                fontSize: 14,
                                color: c.AppColors.textSecondary)),
                      ],
                    ),
                  ),
                 const Icon(Icons.lock_outline_rounded,
                      size: 15, color: c.AppColors.textTertiary),
                ],
              ),
            ),
            if (note != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(note,
                    style: const TextStyle(
                        fontSize: 11, color: c.AppColors.textTertiary)),
              ),
          ],
        ),
      );
}
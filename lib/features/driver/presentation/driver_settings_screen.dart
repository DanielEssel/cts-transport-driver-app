// features/driver/presentation/driver_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../app/app_routes.dart';

class DriverSettingsScreen extends StatefulWidget {
  const DriverSettingsScreen({super.key});

  @override
  State<DriverSettingsScreen> createState() => _DriverSettingsScreenState();
}

class _DriverSettingsScreenState extends State<DriverSettingsScreen> {
  // ── Preferences ────────────────────────────────
  bool _pushNotifications = true;
  bool _rideRequests = true;
  bool _paymentAlerts = true;
  bool _promoNotifications = false;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  String _appVersion = '';
  bool _isLoading = true;
  bool _isSaving = false;

  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('drivers')
            .doc(_uid)
            .collection('settings')
            .doc('notifications')
            .get(),
        PackageInfo.fromPlatform(),
      ]);

      final snap = results[0] as DocumentSnapshot;
      final info = results[1] as PackageInfo;

      if (snap.exists) {
        final d = snap.data() as Map<String, dynamic>;
        setState(() {
          _pushNotifications = d['pushNotifications'] as bool? ?? true;
          _rideRequests = d['rideRequests'] as bool? ?? true;
          _paymentAlerts = d['paymentAlerts'] as bool? ?? true;
          _promoNotifications = d['promoNotifications'] as bool? ?? false;
          _soundEnabled = d['soundEnabled'] as bool? ?? true;
          _vibrationEnabled = d['vibrationEnabled'] as bool? ?? true;
        });
      }

      setState(() {
        _appVersion = '${info.version} (${info.buildNumber})';
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(_uid)
          .collection('settings')
          .doc('notifications')
          .set({
        'pushNotifications': _pushNotifications,
        'rideRequests': _rideRequests,
        'paymentAlerts': _paymentAlerts,
        'promoNotifications': _promoNotifications,
        'soundEnabled': _soundEnabled,
        'vibrationEnabled': _vibrationEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Settings saved'),
            backgroundColor: AppColors.successColor,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save settings'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out', style: AppTextStyles.heading4),
        content: Text(
          'Are you sure you want to sign out?',
          style: AppTextStyles.subtitle
              .copyWith(color: AppColors.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
            context, AppRoutes.splash, (_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        title: const Text('Settings', style: AppTextStyles.heading3),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveSettings,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Save',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.primaryColor,
                            fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Notifications ──────────────────
                _SectionCard(
                  title: 'Notifications',
                  icon: Icons.notifications_rounded,
                  children: [
                    _ToggleTile(
                      label: 'Push Notifications',
                      subtitle: 'Enable all notifications',
                      value: _pushNotifications,
                      onChanged: (v) =>
                          setState(() => _pushNotifications = v),
                    ),
                    _ToggleTile(
                      label: 'Ride Requests',
                      subtitle: 'New ride & delivery alerts',
                      value: _rideRequests,
                      enabled: _pushNotifications,
                      onChanged: (v) =>
                          setState(() => _rideRequests = v),
                    ),
                    _ToggleTile(
                      label: 'Payment Alerts',
                      subtitle: 'Earnings & withdrawal updates',
                      value: _paymentAlerts,
                      enabled: _pushNotifications,
                      onChanged: (v) =>
                          setState(() => _paymentAlerts = v),
                    ),
                    _ToggleTile(
                      label: 'Promotions',
                      subtitle: 'Bonus & incentive alerts',
                      value: _promoNotifications,
                      enabled: _pushNotifications,
                      onChanged: (v) =>
                          setState(() => _promoNotifications = v),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Sound & Haptics ────────────────
                _SectionCard(
                  title: 'Sound & Haptics',
                  icon: Icons.volume_up_rounded,
                  children: [
                    _ToggleTile(
                      label: 'Sound',
                      subtitle: 'Play sounds for alerts',
                      value: _soundEnabled,
                      onChanged: (v) =>
                          setState(() => _soundEnabled = v),
                    ),
                    _ToggleTile(
                      label: 'Vibration',
                      subtitle: 'Vibrate for new requests',
                      value: _vibrationEnabled,
                      onChanged: (v) =>
                          setState(() => _vibrationEnabled = v),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Account ────────────────────────
                _SectionCard(
                  title: 'Account',
                  icon: Icons.manage_accounts_rounded,
                  children: [
                    _NavTile(
                      label: 'Edit Profile',
                      icon: Icons.person_outline_rounded,
                      onTap: () => Navigator.pushNamed(
                          context, AppRoutes.driverProfile),
                    ),
                    _NavTile(
                      label: 'Privacy & Security',
                      icon: Icons.lock_outline_rounded,
                      onTap: () => Navigator.pushNamed(
                          context, AppRoutes.privacySecurity),
                    ),
                    _NavTile(
                      label: 'Help & Support',
                      icon: Icons.headset_mic_outlined,
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.support),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── About ──────────────────────────
                _SectionCard(
                  title: 'About',
                  icon: Icons.info_outline_rounded,
                  children: [
                    _InfoTile(label: 'App Version', value: _appVersion),
                    _NavTile(
                      label: 'Terms of Service',
                      icon: Icons.article_outlined,
                      onTap: () {},
                    ),
                    _NavTile(
                      label: 'Privacy Policy',
                      icon: Icons.policy_outlined,
                      onTap: () {},
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Sign out ───────────────────────
                OutlinedButton.icon(
                  onPressed: _confirmSignOut,
                  icon: const Icon(Icons.logout_rounded,
                      color: AppColors.errorColor),
                  label: const Text('Sign Out',
                      style: TextStyle(
                          color: AppColors.errorColor,
                          fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: AppColors.errorColor, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

// ── Supporting widgets ─────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundLightColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primaryColor),
                const SizedBox(width: 8),
                Text(title,
                    style: AppTextStyles.bodySmall
                        .copyWith(fontWeight: FontWeight.w700,
                            color: AppColors.primaryColor)),
              ],
            ),
          ),
          const Divider(color: AppColors.borderColor, height: 1),
          ...children,
        ],
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.label,
    required this.subtitle,
    required this.value,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      title: Text(label,
          style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w500,
              color: enabled
                  ? AppColors.textPrimaryColor
                  : AppColors.textDisabledColor)),
      subtitle: Text(subtitle,
          style: AppTextStyles.caption
              .copyWith(color: AppColors.textSecondaryColor)),
      value: value && enabled,
      onChanged: enabled ? onChanged : null,
      activeColor: AppColors.primaryColor,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}

class _NavTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _NavTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondaryColor, size: 22),
      title: Text(label, style: AppTextStyles.bodySmall),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.textDisabledColor),
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: AppTextStyles.bodySmall),
      trailing: Text(value,
          style: AppTextStyles.caption
              .copyWith(color: AppColors.textSecondaryColor)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}
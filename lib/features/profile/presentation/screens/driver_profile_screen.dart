import 'package:cts_transport_driver_app/app/app_routes.dart';
import 'package:flutter/material.dart';
import '../../../driver/models/driver_types.dart';
import '../../../driver/data/driver_profile_service.dart';
import '../../../../app/app_theme.dart';

class DriverProfileScreen extends StatefulWidget {
  final DriverProfile? profile;
  
  const DriverProfileScreen({super.key, this.profile});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  late final Stream<DriverProfile> _profileStream;
  final DriverProfileService _profileService = DriverProfileService();

  @override
  void initState() {
    super.initState();
    if (widget.profile != null) {
      _profileStream = Stream.value(widget.profile!);
    } else {
      _profileStream = _profileService.streamProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        elevation: 0,
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.surface,
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('Edit', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: StreamBuilder<DriverProfile>(
        stream: _profileStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary)));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('No profile data'));
          }

          final profile = snapshot.data!;
          return SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(profile),
                const SizedBox(height: 12),
                
                // Phone
                _buildCard([
                  _listTile(Icons.phone_rounded, 'Phone', profile.phone ?? 'Not provided'),
                  _divider(),
                  _listTile(Icons.email_rounded, 'Email', profile.email ?? 'Not provided'),
                  _divider(),
                  _listTile(Icons.verified_user_rounded, 'Status', profile.isApproved ? 'Verified' : 'Pending',
                      valueColor: profile.isApproved ? Colors.green : AppTheme.warning),
                  _divider(),
                  _listTile(Icons.toggle_on_rounded, 'Online Status', profile.isOnline ? 'Online' : 'Offline',
                      valueColor: profile.isOnline ? Colors.green : AppTheme.textSecondary),
                ]),
                
                const SizedBox(height: 12),
                
                // Service & Vehicle
                _buildCard([
                  _listTile(Icons.electric_rickshaw_rounded, 'Service Type', profile.serviceLabel),
                  _divider(),
                  _listTile(Icons.delivery_dining_rounded, 'Vehicle Type', profile.vehicleLabel),
                ]),
                
                const SizedBox(height: 12),
                
                // Actions
                _buildCard([
                  _actionTile(Icons.help_outline_rounded, 'Help & Support', () {}),
                  _divider(),
                  _actionTile(Icons.logout_rounded, 'Sign Out', () => _showSignOutDialog(context), color: AppTheme.danger),
                ]),
                
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(DriverProfile profile) {
    final displayName = profile.getDisplayName;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'D';
    
    return Container(
      width: double.infinity,
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: AppTheme.primary.withOpacity(0.1),
                child: Text(initial, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primary)),
              ),
              if (profile.isOnline)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  child: const Icon(Icons.circle, size: 12, color: Colors.white),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text('UID: ${profile.shortUid}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(children: children),
    );
  }

  Widget _listTile(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary.withOpacity(0.7)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary))),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor ?? AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _actionTile(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    final textColor = color ?? AppTheme.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: textColor),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor))),
            const Icon(Icons.chevron_right, size: 20, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return const Divider(height: 1, thickness: 0.5, color: AppTheme.textHint);
  }

  void _showSignOutDialog(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign Out', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    
  if (shouldLogout == true && context.mounted) {
  await DriverProfileService().signOut();
  if (context.mounted) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,       // clears entire back stack
    );
  }
}
  }
}
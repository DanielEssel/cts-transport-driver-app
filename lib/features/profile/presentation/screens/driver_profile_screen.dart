// lib/features/profile/presentation/screens/driver_profile_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cts_transport_driver_app/app/app_routes.dart';
import '../../../driver/models/driver_types.dart';
import '../../../driver/data/driver_profile_service.dart';
import '../../../../app/app_theme.dart';



// ── Screen ────────────────────────────────────────────────────────────────────

class DriverProfileScreen extends StatefulWidget {
  final DriverProfile? profile;
  const DriverProfileScreen({super.key, this.profile});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  late final Stream<DriverProfile> _profileStream;
  final _profileService = DriverProfileService();

  @override
  void initState() {
    super.initState();
    _profileStream = widget.profile != null
        ? Stream.value(widget.profile!)
        : _profileService.streamProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: StreamBuilder<DriverProfile>(
        stream: _profileStream,
        builder: (context, snap) {
          final profile = snap.data;
          final loading = snap.connectionState == ConnectionState.waiting
              && profile == null;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Hero app bar ──
              _HeroAppBar(
                profile: profile,
                loading: loading,
                onEdit:  () {},
                onBack:  () => Navigator.pop(context),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    children: [
                      // ── Stats row ──
                      if (profile != null)
                        _StatsRow(profile: profile),

                      const SizedBox(height: 20),

                      // ── Account info ──
                      _Section(
                        title: 'Account',
                        children: [
                          _InfoTile(
                            icon:  Icons.person_rounded,
                            label: 'Full Name',
                            value: profile?.displayName ?? '—',
                            loading: loading,
                          ),
                          _InfoTile(
                            icon:  Icons.phone_rounded,
                            label: 'Phone',
                            value: profile?.phone ?? '—',
                            loading: loading,
                          ),
                          _InfoTile(
                            icon:  Icons.email_rounded,
                            label: 'Email',
                            value: profile?.email?.isNotEmpty == true
                                ? profile!.email!
                                : 'Not provided',
                            loading: loading,
                          ),
                          _InfoTile(
                            icon:     Icons.verified_rounded,
                            label:    'Verification',
                            value:    profile?.isApproved == true
                                ? 'Verified'
                                : 'Pending',
                            valueColor: profile?.isApproved == true
                                ? C.success
                                : C.warning,
                            loading: loading,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Vehicle info ──
                      _Section(
                        title: 'Vehicle',
                        children: [
                          _InfoTile(
                            icon:  Icons.electric_rickshaw_rounded,
                            label: 'Service Type',
                            value: profile?.serviceLabel ?? '—',
                            loading: loading,
                          ),
                          _InfoTile(
                            icon:  Icons.directions_car_rounded,
                            label: 'Vehicle Type',
                            value: profile?.vehicleLabel ?? '—',
                            loading: loading,
                          ),
                          if (profile?.vehicleModel != null)
                            _InfoTile(
                              icon:  Icons.car_repair_rounded,
                              label: 'Model',
                              value: profile!.vehicleModel!,
                              loading: loading,
                            ),
                          if (profile?.vehiclePlate != null)
                            _InfoTile(
                              icon:  Icons.pin_rounded,
                              label: 'Plate Number',
                              value: profile!.vehiclePlate!,
                              loading: loading,
                            ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Documents ──
                      _Section(
                        title: 'Documents',
                        children: [
                          _DocTile(
                            label:    'Driver\'s License',
                            verified: profile?.documents['license'] == true,
                            loading:  loading,
                          ),
                          _DocTile(
                            label:    'Vehicle Insurance',
                            verified: profile?.documents['insurance'] == true,
                            loading:  loading,
                          ),
                          _DocTile(
                            label:    'Vehicle Registration',
                            verified: profile?.documents['registration'] == true,
                            loading:  loading,
                          ),
                          _DocTile(
                            label:    'Profile Photo',
                            verified: profile?.documents['profile'] == true,
                            loading:  loading,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Account actions ──
                      _Section(
                        title: 'Account',
                        children: [
                          _ActionTile(
                            icon:    Icons.help_outline_rounded,
                            label:   'Help & Support',
                            onTap:   () => Navigator.pushNamed(
                                context, AppRoutes.support),
                          ),
                          _ActionTile(
                            icon:    Icons.settings_rounded,
                            label:   'Settings',
                            onTap:   () => Navigator.pushNamed(
                                context, AppRoutes.settings),
                          ),
                          _ActionTile(
                            icon:     Icons.logout_rounded,
                            label:    'Sign Out',
                            color:    C.error,
                            bgColor:  C.errorDim,
                            onTap:    () => _confirmSignOut(context),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // ── UID ──
                      if (profile != null)
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(
                                ClipboardData(text: profile.uid));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('UID copied'),
                                  duration: Duration(seconds: 1)),
                            );
                          },
                          child: Text(
                            'ID: ${profile.uid.substring(0, 12)}…  •  tap to copy',
                            style: const TextStyle(
                              fontSize: 11,
                              color:    C.textTertiary,
                            ),
                          ),
                        ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await DriverProfileService().signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                  (_) => false,
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: C.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

// ── Hero app bar ──────────────────────────────────────────────────────────────

class _HeroAppBar extends StatelessWidget {
  final DriverProfile? profile;
  final bool           loading;
  final VoidCallback   onEdit;
  final VoidCallback   onBack;

  const _HeroAppBar({
    required this.profile,
    required this.loading,
    required this.onEdit,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 240,
      pinned:          true,
      backgroundColor: C.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: onBack,
      ),
      actions: [
        TextButton(
          onPressed: onEdit,
          child: const Text(
            'Edit',
            style: TextStyle(
              color:      Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A56DB), Color(0xFF1E429F)],
              begin:  Alignment.topLeft,
              end:    Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                top: -30, right: -30,
                child: Container(
                  width: 160, height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Positioned(
                bottom: -20, left: 40,
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
              ),

              // Content
              SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),

                      // Avatar
                      Stack(
                        children: [
                          Container(
                            width: 90, height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 3),
                            ),
                            child: ClipOval(
                              child: profile?.photoUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl:  profile!.photoUrl!,
                                      fit:       BoxFit.cover,
                                      errorWidget: (_, __, ___) =>
                                          _avatarFallback(profile),
                                    )
                                  : _avatarFallback(profile),
                            ),
                          ),
                          // Online indicator
                          Positioned(
                            right: 2, bottom: 2,
                            child: Container(
                              width: 20, height: 20,
                              decoration: BoxDecoration(
                                color: profile?.isOnline == true
                                    ? C.success
                                    : C.textTertiary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Name
                      Text(
                        profile?.displayName ?? '—',
                        style: const TextStyle(
                          fontSize:   20,
                          fontWeight: FontWeight.w800,
                          color:      Colors.white,
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Online status
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          profile?.isOnline == true
                              ? '● Online'
                              : '● Offline',
                          style: TextStyle(
                            fontSize:   11,
                            fontWeight: FontWeight.w700,
                            color:      profile?.isOnline == true
                                ? const Color(0xFF84E1BC)
                                : Colors.white60,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarFallback(DriverProfile? profile) {
    final name    = profile?.displayName ?? 'D';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'D';
    return Container(
      color: Colors.white.withValues(alpha: 0.2),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize:   36,
            fontWeight: FontWeight.w800,
            color:      Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final DriverProfile profile;
  const _StatsRow({required this.profile});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: _StatCard(
              icon:      Icons.star_rounded,
              iconColor: const Color(0xFFE3A008),
              iconBg:    const Color(0xFFFDF3D0),
              label:     'Rating',
              value:     profile.rating.toStringAsFixed(1),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              icon:      Icons.directions_car_rounded,
              iconColor: C.primary,
              iconBg:    C.primaryDim,
              label:     'Trips',
              value:     '${profile.totalTrips}',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              icon:      Icons.schedule_rounded,
              iconColor: C.success,
              iconBg:    C.successDim,
              label:     'Member Since',
              value:     _formatDate(profile.memberSince),
            ),
          ),
        ],
      );

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final Color    iconBg;
  final String   label;
  final String   value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:        C.card,
          borderRadius: BorderRadius.circular(14),
          boxShadow:    C.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color:        iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 15),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize:   16,
                fontWeight: FontWeight.w800,
                color:      C.textPrimary,
                height:     1,
              ),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                  fontSize: 10,
                  color:    C.textTertiary,
                )),
          ],
        ),
      );
}

// ── Section wrapper ───────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String       title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize:      11,
                fontWeight:    FontWeight.w700,
                color:         C.textTertiary,
                letterSpacing: 1,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color:        C.card,
              borderRadius: BorderRadius.circular(16),
              boxShadow:    C.cardShadow,
            ),
            child: Column(
              children: List.generate(children.length * 2 - 1, (i) {
                if (i.isOdd) {
                  return const Divider(
                    height:    0.5,
                    thickness: 0.5,
                    indent:    52,
                    color:     C.border,
                  );
                }
                return children[i ~/ 2];
              }),
            ),
          ),
        ],
      );
}

// ── Info tile ─────────────────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color?   valueColor;
  final bool     loading;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color:        C.primaryDim,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 16, color: C.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                    fontSize: 13,
                    color:    C.textSecondary,
                  )),
            ),
            loading
                ? Container(
                    width: 80, height: 13,
                    decoration: BoxDecoration(
                      color:        C.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )
                : Text(
                    value,
                    style: TextStyle(
                      fontSize:   13,
                      fontWeight: FontWeight.w600,
                      color:      valueColor ?? C.textPrimary,
                    ),
                  ),
          ],
        ),
      );
}

// ── Document tile ─────────────────────────────────────────────────────────────

class _DocTile extends StatelessWidget {
  final String label;
  final bool   verified;
  final bool   loading;

  const _DocTile({
    required this.label,
    required this.verified,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: verified ? C.successDim : C.warningDim,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                verified
                    ? Icons.check_circle_rounded
                    : Icons.pending_rounded,
                size:  16,
                color: verified ? C.success : C.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                    fontSize: 13,
                    color:    C.textSecondary,
                  )),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: verified ? C.successDim : C.warningDim,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                verified ? 'Verified' : 'Pending',
                style: TextStyle(
                  fontSize:   10,
                  fontWeight: FontWeight.w700,
                  color:      verified ? C.success : C.warning,
                ),
              ),
            ),
          ],
        ),
      );
}

// ── Action tile ───────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;
  final Color?       color;
  final Color?       bgColor;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color:        bgColor ?? C.primaryDim,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon,
                    size: 16, color: color ?? C.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                      fontSize:   13,
                      fontWeight: FontWeight.w500,
                      color:      color ?? C.textPrimary,
                    )),
              ),
             const Icon(Icons.chevron_right_rounded,
                  size: 18, color: C.textTertiary),
            ],
          ),
        ),
      );
}
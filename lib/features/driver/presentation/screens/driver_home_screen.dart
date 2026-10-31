// lib/features/driver/presentation/screens/driver_home_screen.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cts_transport_driver_app/features/driver/models/driver_types.dart';
import 'package:cts_transport_driver_app/app/app_routes.dart';
import 'package:cts_transport_driver_app/app/app_theme.dart';
import 'package:cts_transport_driver_app/core/services/marker_service.dart';

import '../controllers/driver_home_controller.dart';
import '../widgets/driver_app_bar.dart';
import '../widgets/earnings_card.dart';
import '../widgets/requests_section.dart';
import '../widgets/stats_row.dart';
import '../widgets/loading_shimmer.dart';
import '../../presentation/widgets/active_jobs_screen.dart';
import '../../../gas_supplier_jobs/presentation/gas_supplier_jobs_entry.dart';

// Colours come from AppTheme (CTSGo). Text on white uses textPrimary /
// textSecondary (4.9:1 or better); green text and icons use primaryDark.

// ─────────────────────────────────────────────────────────────────────────────
// ROOT SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key, required this.profile});
  final DriverProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(driverHomeControllerProvider);
    // Pre-load map markers so job screens open without a loading step.
    MarkerService.instance.warmUp(context);

    return homeState.when(
      loading: () => const Scaffold(
        backgroundColor: AppTheme.background,
        body: LoadingShimmer(),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppTheme.background,
        body: _ErrorView(
          error: e.toString(),
          onRetry: () => ref.invalidate(driverHomeControllerProvider),
        ),
      ),
      data: (state) => _HomeBody(
        state: state,
        profile: profile,
        ref: ref,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN BODY
// ─────────────────────────────────────────────────────────────────────────────

class _HomeBody extends StatelessWidget {
  final dynamic state;
  final DriverProfile profile;
  final WidgetRef ref;

  const _HomeBody({
    required this.state,
    required this.profile,
    required this.ref,
  });

  void _toggleOnline() =>
      ref.read(driverHomeControllerProvider.notifier).toggleOnlineStatus();

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: DriverAppBar(
          onlineStatus: state.isOnline,
          unreadNotifications: state.unreadNotifications,
          profile: profile,
          onProfileTap: () => Navigator.pushNamed(
              context, AppRoutes.driverProfile,
              arguments: profile),
          onNotificationsTap: () =>
              Navigator.pushNamed(context, AppRoutes.notifications),
        ),
        body: RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () => ref.refresh(driverHomeControllerProvider.future),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              // ── Availability ─────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: HomeStatusCard(
                    isOnline: state.isOnline as bool,
                    onToggle: _toggleOnline,
                  ),
                ),
              ),

              // ── Active jobs (only while one is ongoing) ──────────────
              SliverToBoxAdapter(
                child: Consumer(
                  builder: (ctx, ref, _) {
                    final jobs = ref.watch(activeJobsProvider);
                    if (jobs.isEmpty) return const SizedBox.shrink();
                    return _ActiveTripBanner(jobs: jobs);
                  },
                ),
              ),

              // ── Gas supplier jobs (delivery drivers, while switched on) ─
              if (profile.role == 'driver_delivery')
                const SliverToBoxAdapter(child: GasSupplierJobsEntry()),

              // ── Requests ─────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: RequestsSection(
                    driver: profile,
                    isOnline: state.isOnline,
                    onGoOnline: _toggleOnline,
                  ),
                ),
              ),

              // ── Today: stats and earnings ────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _StatsStrip(stats: state.stats),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(child: EarningsCard()),
              ),

              // ── Quick actions ────────────────────────────────────────
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: _SectionLabel(
                    icon: Icons.apps_rounded,
                    title: 'Quick Actions',
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _QuickActionsGrid(
                    onHistoryTap: () =>
                        Navigator.pushNamed(context, AppRoutes.tripHistory),
                    onWalletTap: () =>
                        Navigator.pushNamed(context, AppRoutes.driverWallet),
                    onSupportTap: () =>
                        Navigator.pushNamed(context, AppRoutes.support),
                    onSettingsTap: () =>
                        Navigator.pushNamed(context, AppRoutes.settings),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: SizedBox(
                  height: 24 + MediaQuery.of(context).padding.bottom,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS CARD
//
// Online and offline differ in text, icon, colour and the action offered:
//   online  — the Wallet card's green gradient and glow, live icon, white
//             "Go Offline" button
//   offline — white card, power icon, deep-green "Go Online" button
// White text on the gradient is either large (the headline) or sits on
// AppTheme.onGradientScrim, so it stays readable at the gradient's light end.
// ─────────────────────────────────────────────────────────────────────────────

class HomeStatusCard extends StatelessWidget {
  const HomeStatusCard({
    super.key,
    required this.isOnline,
    required this.onToggle,
  });

  final bool isOnline;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final subtitle =
        isOnline ? 'Ready to receive requests' : 'Go online to start earning';

    return Container(
      key: const ValueKey('home-status-card'),
      decoration: BoxDecoration(
        color: isOnline ? null : AppTheme.surface,
        gradient: isOnline ? AppTheme.primaryGradient : null,
        borderRadius: BorderRadius.circular(20),
        border: isOnline ? null : Border.all(color: AppTheme.divider),
        boxShadow: isOnline ? AppTheme.primaryGlow : AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isOnline ? Colors.white : AppTheme.background,
                  shape: BoxShape.circle,
                  border: isOnline
                      ? null
                      : Border.all(color: AppTheme.divider),
                ),
                child: Icon(
                  isOnline
                      ? Icons.graphic_eq_rounded
                      : Icons.power_settings_new_rounded,
                  color: isOnline ? AppTheme.primaryDark : AppTheme.textSecondary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 21 px w800 counts as large text: 3:1 is enough.
                    Text(
                      isOnline ? "You're Online" : "You're Offline",
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: isOnline ? Colors.white : AppTheme.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isOnline)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.onGradientScrim,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      )
                    else
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, color: AppTheme.textSecondary),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ServiceStrip(isOnline: isOnline),
          const SizedBox(height: 14),
          if (isOnline)
            // Secondary on the green card: white with deep-green text, 7.1:1.
            OutlinedButton.icon(
              onPressed: onToggle,
              icon: const Icon(Icons.power_settings_new_rounded, size: 20),
              label: const Text('Go Offline'),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryDeep,
                side: const BorderSide(color: Colors.white),
                minimumSize: const Size.fromHeight(50),
              ),
            )
          else
            FilledButton.icon(
              onPressed: onToggle,
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: const Text('Go Online'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
        ],
      ),
    );
  }
}

class _ServiceStrip extends StatelessWidget {
  final bool isOnline;
  const _ServiceStrip({required this.isOnline});

  // Static for now. Swap for the driver's enabled services if you store them.
  static const _services = [
    (Icons.directions_car_rounded, 'Ride'),
    (Icons.inventory_2_rounded, 'Delivery'),
    (Icons.local_gas_station_rounded, 'Gas'),
  ];

  @override
  Widget build(BuildContext context) {
    final fg = isOnline ? Colors.white : AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      decoration: BoxDecoration(
        // On the gradient: the scrim keeps 13 px white labels at 4.9:1+.
        color: isOnline ? AppTheme.onGradientScrim : AppTheme.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final s in _services)
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(s.$1, color: fg, size: 17),
                    const SizedBox(width: 5),
                    Text(
                      s.$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                    if (isOnline) ...[
                      const SizedBox(width: 5),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: AppTheme.primaryDark, size: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK ACTIONS GRID
// Secondary navigation: neutral cards with one green icon style.
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  final VoidCallback onHistoryTap;
  final VoidCallback onWalletTap;
  final VoidCallback onSupportTap;
  final VoidCallback onSettingsTap;

  const _QuickActionsGrid({
    required this.onHistoryTap,
    required this.onWalletTap,
    required this.onSupportTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionItem(
        icon: Icons.history_rounded,
        label: 'Trip History',
        subtitle: 'View past trips',
        onTap: onHistoryTap,
      ),
      _ActionItem(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Wallet',
        subtitle: 'Balance & payouts',
        onTap: onWalletTap,
      ),
      _ActionItem(
        icon: Icons.headset_mic_rounded,
        label: 'Support',
        subtitle: 'Get help fast',
        onTap: onSupportTap,
      ),
      _ActionItem(
        icon: Icons.settings_rounded,
        label: 'Settings',
        subtitle: 'App preferences',
        onTap: onSettingsTap,
      ),
    ];

    // Grow the tiles with the device text size so two lines never clip.
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: math.max(72, 30 + 38 * textScale),
      ),
      children: actions.map(_buildCard).toList(),
    );
  }

  Widget _buildCard(_ActionItem item) {
    return Material(
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: AppTheme.primaryDark, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppTheme.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// PERFORMANCE RING  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _PerformanceRing extends StatelessWidget {
  final double rating;
  final double acceptanceRate;

  const _PerformanceRing({
    required this.rating,
    required this.acceptanceRate,
  });

  @override
  Widget build(BuildContext context) {
    final score =
        ((rating / 5.0) * 0.6 + (acceptanceRate / 100.0) * 0.4).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(72, 72),
                painter: _RingPainter(progress: score),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(score * 100).round()}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  const Text(
                    'score',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white60,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '★ ${rating.toStringAsFixed(1)}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  const _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;

    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// STATS STRIP
// ─────────────────────────────────────────────────────────────────────────────

class _StatsStrip extends StatelessWidget {
  final dynamic stats;
  const _StatsStrip({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats == null) return const StatsRow();

    final rating = (stats?.rating as double?) ?? 0.0;
    final trips = (stats?.completedTrips as int?) ?? 0;
    final acceptance = (stats?.acceptanceRate as double?) ?? 0.0;

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.star_rounded,
            iconBg: AppTheme.warningLight,
            iconColor: AppTheme.warning,
            label: 'Rating',
            value: rating.toStringAsFixed(1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.directions_car_rounded,
            iconBg: AppTheme.primaryLight,
            iconColor: AppTheme.primaryDark,
            label: 'Trips',
            value: '$trips',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.check_circle_rounded,
            iconBg: AppTheme.primarySubtle,
            iconColor: AppTheme.primaryDark,
            label: 'Acceptance',
            value: '${acceptance.toStringAsFixed(0)}%',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        height: 1.1,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION LABEL
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionLabel({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: AppTheme.primaryDark, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// LIVE PILL
// ─────────────────────────────────────────────────────────────────────────────

class _LivePill extends StatefulWidget {
  const _LivePill();

  @override
  State<_LivePill> createState() => _LivePillState();
}

class _LivePillState extends State<_LivePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.primarySubtle,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _c,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryDark,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 5),
            const Text(
              'LIVE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryDark,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVE JOB BANNER — shown only while a ride/delivery/gas order is ongoing
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveTripBanner extends StatelessWidget {
  final List<ActiveJob> jobs;
  const _ActiveTripBanner({required this.jobs});

  @override
  Widget build(BuildContext context) {
    final single = jobs.length == 1;
    final title = single
        ? '${jobs.first.typeLabel} in progress'
        : '${jobs.length} jobs in progress';
    final subtitle = single
        ? 'Tap to return to live tracking'
        : 'Tap to see your active jobs';
    final icon = single ? jobs.first.icon : Icons.layers_rounded;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryDark, AppTheme.primaryDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => jobs.length == 1
                    ? jobs.first.trackingScreen()
                    : const ActiveJobsScreen(),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Open',
                            style: TextStyle(
                              color: AppTheme.primaryDeep,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            )),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded,
                            color: AppTheme.primaryDeep, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ERROR VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.dangerLight,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.cloud_off_rounded,
                    color: AppTheme.danger, size: 38),
              ),
              const SizedBox(height: 20),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
}

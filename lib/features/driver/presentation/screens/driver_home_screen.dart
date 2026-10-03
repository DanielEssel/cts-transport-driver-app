// lib/features/driver/presentation/screens/driver_home_screen.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cts_transport_driver_app/features/driver/models/driver_types.dart';
import 'package:cts_transport_driver_app/app/app_routes.dart';

import '../controllers/driver_home_controller.dart';
import '../widgets/driver_app_bar.dart';
import '../widgets/earnings_card.dart';
import '../widgets/requests_section.dart';
import '../widgets/stats_row.dart';
import '../widgets/loading_shimmer.dart';
import '../../presentation/widgets/active_jobs_screen.dart';
import '../../../home/presentation/widgets/promo_banner.dart';
// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────────────────────────────────────

class _DT {
  static const bg = Color(0xFFF0F2F8);
  static const card = Color(0xFFFFFFFF);
  static const primary = Color(0xFF1A56DB);
  static const primaryDim = Color(0xFFEBF0FD);
  static const success = Color(0xFF16A34A);
  static const successDim = Color(0xFFDEF7EC);

  static const error = Color(0xFFE02424);
  static const textPrimary = Color(0xFF111928);
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF9CA3AF);

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
}

// ─────────────────────────────────────────────────────────────────────────────
// ROOT SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key, required this.profile});
  final DriverProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(driverHomeControllerProvider);

    return homeState.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFFF0F2F8),
        body: LoadingShimmer(),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: _DT.bg,
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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _DT.bg,
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
          color: _DT.primary,
          onRefresh: () => ref.refresh(driverHomeControllerProvider.future),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              // ── Status banner ────────────────────────────────────────
              SliverToBoxAdapter(
                child: _StatusBanner(
                  state: state,
                  profile: profile,
                  ref: ref,
                ),
              ),

              // ── Active jobs banner (now below status banner) ─────────
              SliverToBoxAdapter(
                child: Consumer(
                  builder: (ctx, ref, _) {
                    final jobs = ref.watch(activeJobsProvider);
                    if (jobs.isEmpty) return const SizedBox.shrink();
                    return _ActiveTripBanner(jobs: jobs);
                  },
                ),
              ),

              // ── Stats strip ──────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _StatsStrip(stats: state.stats),
                ),
              ),

              // ── Earnings card ────────────────────────────────────────
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(child: EarningsCard()),
              ),

              // ── Requests ─────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: RequestsSection(
                    driver: profile,
                    isOnline: state.isOnline,
                    onGoOnline: () => ref
                        .read(driverHomeControllerProvider.notifier)
                        .toggleOnlineStatus(),
                  ),
                ),
              ),

              // ── Quick actions header ─────────────────────────────────
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
                sliver: SliverToBoxAdapter(
                  child: _SectionLabel(
                    icon: Icons.apps_rounded,
                    title: 'Quick Actions',
                  ),
                ),
              ),

              // ── Quick actions 2×2 grid ───────────────────────────────
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
// QUICK ACTIONS GRID  (FIX 2 — replaces imported QuickActionsGrid)
//
// Before: 4 identical large green rounded squares in a single row.
//   - All same colour → no visual hierarchy
//   - Single row cramps on small phones
//   - No subtitle, no chevron, no differentiation
//
// After: 2×2 grid of cards, each with:
//   - Unique accent colour (blue / purple / orange / slate)
//   - Icon in a tinted rounded container
//   - Bold label + muted subtitle
//   - Trailing chevron for affordance
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
        color: const Color(0xFF1A56DB),
        bgColor: const Color(0xFFEBF0FD),
        onTap: onHistoryTap,
      ),
      _ActionItem(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Wallet',
        subtitle: 'Balance & payouts',
        color: const Color(0xFF7C3AED),
        bgColor: const Color(0xFFF3EFFE),
        onTap: onWalletTap,
      ),
      _ActionItem(
        icon: Icons.headset_mic_rounded,
        label: 'Support',
        subtitle: 'Get help fast',
        color: const Color(0xFFE3A008),
        bgColor: const Color(0xFFFDF3D0),
        onTap: onSupportTap,
      ),
      _ActionItem(
        icon: Icons.settings_rounded,
        label: 'Settings',
        subtitle: 'App preferences',
        color: const Color(0xFF374151),
        bgColor: const Color(0xFFF3F4F6),
        onTap: onSettingsTap,
      ),
    ];

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 68,
      ),
      children: actions.map(_buildCard).toList(),
    );
  }

  Widget _buildCard(_ActionItem item) {
    return Material(
      color: _DT.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: _DT.cardShadow,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: item.bgColor,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(item.icon, color: item.color, size: 19),
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
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _DT.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: _DT.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: _DT.textTertiary),
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
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS BANNER  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final dynamic state;
  final DriverProfile profile;
  final WidgetRef ref;

  const _StatusBanner({
    required this.state,
    required this.profile,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final isOnline = state.isOnline as bool;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOnline
              ? [const Color(0xFF16A34A), const Color(0xFF057A55)]
              : [const Color(0xFF374151), const Color(0xFF1F2937)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: _DT.elevatedShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned(
              top: -30,
              right: -20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: 80,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isOnline
                              ? Icons.graphic_eq_rounded
                              : Icons.power_settings_new_rounded,
                          color: isOnline
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF374151),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOnline ? "You're Online" : "You're Offline",
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isOnline
                                  ? 'Ready to receive requests'
                                  : 'Go online to start earning',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => ref
                            .read(driverHomeControllerProvider.notifier)
                            .toggleOnlineStatus(),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isOnline
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isOnline
                                    ? Icons.power_settings_new_rounded
                                    : Icons.play_arrow_rounded,
                                size: 16,
                                color: isOnline
                                    ? Colors.white
                                    : const Color(0xFF057A55),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isOnline ? 'Go Offline' : 'Go Online',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isOnline
                                      ? Colors.white
                                      : const Color(0xFF057A55),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ServiceStrip(isOnline: isOnline),
                ],
              ),
            ),
          ],
        ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final s in _services)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(s.$1, color: Colors.white, size: 16),
                const SizedBox(width: 5),
                Text(
                  s.$2,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline
                        ? const Color(0xFF22C55E)
                        : Colors.white.withValues(alpha: 0.2),
                  ),
                  child: isOnline
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 11)
                      : null,
                ),
              ],
            ),
        ],
      ),
    );
  }
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
// STATS STRIP  (unchanged)
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
            iconBg: const Color(0xFFFDF3D0),
            iconColor: const Color(0xFFE3A008),
            label: 'Rating',
            value: rating.toStringAsFixed(1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.directions_car_rounded,
            iconBg: _DT.primaryDim,
            iconColor: _DT.primary,
            label: 'Trips',
            value: '$trips',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.check_circle_rounded,
            iconBg: _DT.successDim,
            iconColor: _DT.success,
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
          color: _DT.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _DT.cardShadow,
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
              child: Icon(icon, color: iconColor, size: 17),
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
                        fontFamily: 'Inter',
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _DT.textPrimary,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _DT.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 16, color: _DT.textTertiary),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION LABEL  (unchanged)
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
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _DT.primaryDim,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _DT.primary, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _DT.textPrimary,
              ),
            ),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// LIVE PILL  (unchanged)
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
          color: _DT.successDim,
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
                  color: _DT.success,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 5),
            const Text(
              'LIVE',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _DT.success,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVE TRIP BANNER  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveTripBanner extends StatelessWidget {
  final List<ActiveJob> jobs;
  const _ActiveTripBanner({required this.jobs});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => jobs.length == 1
              ? jobs.first.trackingScreen()
              : const ActiveJobsScreen(),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF16A34A), Color(0xFF15803D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF16A34A).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.directions_car_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Trip in Progress',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tap to return to your trip',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Text('Resume',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      )),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ERROR VIEW  (unchanged)
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
                  color: const Color(0xFFFDE8E8),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.cloud_off_rounded,
                    color: _DT.error, size: 38),
              ),
              const SizedBox(height: 20),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _DT.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: const TextStyle(fontSize: 13, color: _DT.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
                style: FilledButton.styleFrom(
                  backgroundColor: _DT.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
}

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
import '../widgets/quick_actions_grid.dart';
import '../widgets/loading_shimmer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────────────────────────────────────

class _DT {
  // Surfaces
  static const bg          = Color(0xFFF0F2F8);
  static const card        = Color(0xFFFFFFFF);
  
  // Brand
  static const primary     = Color(0xFF1A56DB);
  static const primaryDim  = Color(0xFFEBF0FD);
  static const success     = Color(0xFF0E9F6E);
  static const successDim  = Color(0xFFDEF7EC);
  static const warning     = Color(0xFFE3A008);
  static const warningDim  = Color(0xFFFDF3D0);
  static const error       = Color(0xFFE02424);

  // Text
  static const textPrimary   = Color(0xFF111928);
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary  = Color(0xFF9CA3AF);

  // Border
  static const border      = Color(0xFFE5E7EB);

  // Shadows
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color:      Colors.black.withValues(alpha: 0.05),
      blurRadius: 16,
      offset:     const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color:      Colors.black.withValues(alpha: 0.08),
      blurRadius: 24,
      offset:     const Offset(0, 8),
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
          error:   e.toString(),
          onRetry: () => ref.invalidate(driverHomeControllerProvider),
        ),
      ),
      data: (state) => _HomeBody(
        state:   state,
        profile: profile,
        ref:     ref,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN BODY
// ─────────────────────────────────────────────────────────────────────────────

class _HomeBody extends StatelessWidget {
  final dynamic     state;
  final DriverProfile profile;
  final WidgetRef   ref;

  const _HomeBody({
    required this.state,
    required this.profile,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _DT.bg,
        appBar: DriverAppBar(
          onlineStatus:        state.isOnline,
          unreadNotifications: state.unreadNotifications,
          profile:             profile,
          onProfileTap: () => Navigator.pushNamed(
              context, AppRoutes.driverProfile, arguments: profile),
          onNotificationsTap: () => Navigator.pushNamed(
              context, AppRoutes.notifications),
        ),
        body: RefreshIndicator(
          color:     _DT.primary,
          onRefresh: () =>
              ref.refresh(driverHomeControllerProvider.future),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [

              // ── Status banner ────────────────────────────────────────
              SliverToBoxAdapter(
                child: _StatusBanner(
                  state:   state,
                  profile: profile,
                  ref:     ref,
                ),
              ),

              // ── Stats strip ──────────────────────────────────────────
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _StatsStrip(stats: state.stats),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── Earnings card ────────────────────────────────────────
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(child: EarningsCard()),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── Daily goal ───────────────────────────────────────────
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _DailyGoalCard(
                      earnings: state.earnings),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ── Requests header ──────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                sliver: SliverToBoxAdapter(
                  child: _SectionLabel(
                    icon:     Icons.bolt_rounded,
                    title:    'Available Requests',
                    trailing: state.isOnline
                        ? const _LivePill()
                        : null,
                  ),
                ),
              ),

              // ── Requests ─────────────────────────────────────────────
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: RequestsSection(
                    driver:    profile,
                    isOnline:  state.isOnline,
                    onGoOnline: () => ref
                        .read(driverHomeControllerProvider.notifier)
                        .toggleOnlineStatus(),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ── Quick actions header ──────────────────────────────────
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                sliver: SliverToBoxAdapter(
                  child: _SectionLabel(
                    icon:  Icons.apps_rounded,
                    title: 'Quick Actions',
                  ),
                ),
              ),

              // ── Quick actions ────────────────────────────────────────
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: QuickActionsGrid(
                    onHistoryTap:  () => Navigator.pushNamed(
                        context, AppRoutes.tripHistory),
                    onWalletTap:   () => Navigator.pushNamed(
                        context, AppRoutes.driverWallet),
                    onSupportTap:  () => Navigator.pushNamed(
                        context, AppRoutes.support),
                    onSettingsTap: () => Navigator.pushNamed(
                        context, AppRoutes.settings),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: SizedBox(
                  height: 32 + MediaQuery.of(context).padding.bottom,
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
// STATUS BANNER — replaces hero section
// Full-width card with gradient, online toggle, performance ring
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final dynamic     state;
  final DriverProfile profile;
  final WidgetRef   ref;

  const _StatusBanner({
    required this.state,
    required this.profile,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final isOnline = state.isOnline as bool;
    final rating   = state.stats?.rating as double? ?? 0.0;
    final acceptance = state.stats?.acceptanceRate as double? ?? 0.0;

    return Container(
      margin:  const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOnline
              ? [const Color(0xFF0E9F6E), const Color(0xFF057A55)]
              : [const Color(0xFF374151), const Color(0xFF1F2937)],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow:    _DT.elevatedShadow,
      ),
      child: Stack(
        children: [
          // ── Decorative circles ──
          Positioned(
            top: -20, right: -20,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -30, left: 60,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),

          // ── Content ──
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left: status info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isOnline
                                    ? const Color(0xFF84E1BC)
                                    : Colors.white38,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isOnline ? 'ONLINE' : 'OFFLINE',
                              style: const TextStyle(
                                fontFamily:    'Inter',
                                fontSize:      10,
                                fontWeight:    FontWeight.w800,
                                color:         Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        isOnline
                            ? 'Ready for requests'
                            : 'Start earning today',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize:   22,
                          fontWeight: FontWeight.w800,
                          color:      Colors.white,
                          height:     1.2,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        isOnline
                            ? 'Location sharing active'
                            : 'Tap toggle to go online',
                        style: TextStyle(
                          fontSize: 13,
                          color:    Colors.white.withValues(alpha: 0.7),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Toggle button
                      GestureDetector(
                        onTap: () => ref
                            .read(driverHomeControllerProvider.notifier)
                            .toggleOnlineStatus(),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: isOnline
                                ? Colors.white.withValues(alpha: 0.15)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isOnline
                                    ? Icons.power_settings_new_rounded
                                    : Icons.play_arrow_rounded,
                                size:  16,
                                color: isOnline
                                    ? Colors.white
                                    : const Color(0xFF057A55),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isOnline ? 'Go Offline' : 'Go Online',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize:   13,
                                  fontWeight: FontWeight.w700,
                                  color:      isOnline
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
                ),

                const SizedBox(width: 16),

                // Right: performance ring
                if (state.stats != null)
                  _PerformanceRing(
                    rating:         rating,
                    acceptanceRate: acceptance,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PERFORMANCE RING
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
    final score = ((rating / 5.0) * 0.6 +
            (acceptanceRate / 100.0) * 0.4)
        .clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 72, height: 72,
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
                      fontSize:   20,
                      fontWeight: FontWeight.w900,
                      color:      Colors.white,
                      height:     1,
                    ),
                  ),
                  const Text(
                    'score',
                    style: TextStyle(
                      fontSize: 9,
                      color:    Colors.white60,
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
            fontSize:   12,
            fontWeight: FontWeight.w700,
            color:      Colors.white.withValues(alpha: 0.85),
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

    canvas.drawCircle(center, radius,
        Paint()
          ..color       = Colors.white.withValues(alpha: 0.15)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 5);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color       = Colors.white
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap   = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// STATS STRIP — horizontal 3-card row replacing StatsRow
// ─────────────────────────────────────────────────────────────────────────────

class _StatsStrip extends StatelessWidget {
  final dynamic stats;
  const _StatsStrip({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats == null) return const StatsRow();

    final rating     = (stats?.rating       as double?) ?? 0.0;
    final trips      = (stats?.completedTrips as int?)   ?? 0;
    final acceptance = (stats?.acceptanceRate as double?) ?? 0.0;

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon:    Icons.star_rounded,
            iconBg:  const Color(0xFFFDF3D0),
            iconColor: const Color(0xFFE3A008),
            label:   'Rating',
            value:   rating.toStringAsFixed(1),
            suffix:  '★',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon:     Icons.directions_car_rounded,
            iconBg:   _DT.primaryDim,
            iconColor: _DT.primary,
            label:    'Trips',
            value:    '$trips',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon:     Icons.check_circle_rounded,
            iconBg:   _DT.successDim,
            iconColor: _DT.success,
            label:    'Acceptance',
            value:    '${acceptance.toStringAsFixed(0)}%',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color    iconBg;
  final Color    iconColor;
  final String   label;
  final String   value;
  final String?  suffix;

  const _StatTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color:        _DT.card,
          borderRadius: BorderRadius.circular(14),
          boxShadow:    _DT.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color:        iconBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize:   18,
                fontWeight: FontWeight.w800,
                color:      _DT.textPrimary,
                height:     1,
              ),
            ),
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(
                  fontSize: 11,
                  color:    _DT.textTertiary,
                )),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// DAILY GOAL CARD
// ─────────────────────────────────────────────────────────────────────────────

class _DailyGoalCard extends StatelessWidget {
  final dynamic earnings;
  const _DailyGoalCard({required this.earnings});

  static const double _goal = 200.0;

  @override
  Widget build(BuildContext context) {
    final today    = (earnings?.todayEarnings as double?) ?? 0.0;
    final trips    = (earnings?.todayTrips    as int?)    ?? 0;
    final progress = (today / _goal).clamp(0.0, 1.0);
    final reached  = today >= _goal;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:        _DT.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow:    _DT.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: reached
                      ? _DT.successDim
                      : _DT.warningDim,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  reached
                      ? Icons.emoji_events_rounded
                      : Icons.flag_rounded,
                  color: reached ? _DT.success : _DT.warning,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reached
                          ? 'Daily goal reached! 🎉'
                          : 'Daily Goal',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize:   14,
                        fontWeight: FontWeight.w700,
                        color:      _DT.textPrimary,
                      ),
                    ),
                    Text(
                      'GH₵ ${today.toStringAsFixed(2)} of GH₵ ${_goal.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color:    _DT.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: reached
                      ? _DT.successDim
                      : _DT.primaryDim,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$trips trips',
                  style: TextStyle(
                    fontSize:   11,
                    fontWeight: FontWeight.w700,
                    color:      reached
                        ? _DT.success
                        : _DT.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress track
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color:        _DT.border,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: reached
                          ? [_DT.success,
                             const Color(0xFF0E9F6E)]
                          : [_DT.primary,
                             const Color(0xFF1C64F2)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                reached
                    ? 'Keep going — exceed your goal!'
                    : 'GH₵ ${(_goal - today).toStringAsFixed(2)} more needed',
                style: const TextStyle(
                  fontSize: 11,
                  color:    _DT.textSecondary,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize:   12,
                  fontWeight: FontWeight.w800,
                  color:      reached
                      ? _DT.success
                      : _DT.primary,
                ),
              ),
            ],
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
  final IconData icon;
  final String   title;
  final Widget?  trailing;

  const _SectionLabel({
    required this.icon,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color:        _DT.primaryDim,
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
                fontSize:   16,
                fontWeight: FontWeight.w700,
                color:      _DT.textPrimary,
              ),
            ),
          ),
          if (trailing != null) trailing!,
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
    vsync:    this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color:        _DT.successDim,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _c,
              child: Container(
                width: 6, height: 6,
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
                fontFamily:    'Inter',
                fontSize:      10,
                fontWeight:    FontWeight.w800,
                color:         _DT.success,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ERROR VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String       error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color:        const Color(0xFFFDE8E8),
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
                  fontSize:   18,
                  fontWeight: FontWeight.w700,
                  color:      _DT.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: const TextStyle(
                  fontSize: 13,
                  color:    _DT.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onRetry,
                icon:  const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
                style: FilledButton.styleFrom(
                  backgroundColor: _DT.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
}
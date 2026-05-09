// lib/features/driver/presentation/screens/driver_home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cts_transport_driver_app/core/constants/app_colors.dart';
import 'package:cts_transport_driver_app/core/constants/design_constants.dart';
import 'package:cts_transport_driver_app/features/driver/constants/driver_constants.dart';
import 'package:cts_transport_driver_app/features/driver/models/driver_types.dart';
import 'package:cts_transport_driver_app/app/app_routes.dart';

import '../controllers/driver_home_controller.dart';
import '../widgets/driver_app_bar.dart';
import '../widgets/online_status_card.dart';
import '../widgets/earnings_card.dart';
import '../widgets/requests_section.dart';
import '../widgets/stats_row.dart';
import '../widgets/quick_actions_grid.dart';
import '../widgets/loading_shimmer.dart';

class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key, required this.profile});

  final DriverProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(driverHomeControllerProvider);

    return homeState.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.backgroundColor,
        body: LoadingShimmer(),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.backgroundColor,
        body: _ErrorView(
          error: e.toString(),
          onRetry: () => ref.invalidate(driverHomeControllerProvider),
        ),
      ),
      data: (state) => Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: DriverAppBar(
          onlineStatus: state.isOnline,
          unreadNotifications: state.unreadNotifications,
          profile: profile, // ✅ add this
          onProfileTap: () => _onProfileTap(context),
          onNotificationsTap: () => _onNotificationsTap(context),
        ),
        body: RefreshIndicator(
          onRefresh: () => ref.refresh(driverHomeControllerProvider.future),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingConstants.md,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: SpacingConstants.md),

                    // ── Online toggle ────────────────────────────────────────
                    OnlineStatusCard(
                      isOnline: state.isOnline,
                      isToggling: homeState.isRefreshing,
                      onToggle: () => ref
                          .read(driverHomeControllerProvider.notifier)
                          .toggleOnlineStatus(),
                    ),

                    const SizedBox(height: SpacingConstants.lg),

                    // ── Today's stats ────────────────────────────────────────
                    const StatsRow(),

                    const SizedBox(height: SpacingConstants.lg),

                    // ── Earnings summary ─────────────────────────────────────
                    const EarningsCard(),

                    const SizedBox(height: SpacingConstants.xl),

                    // ── Incoming ride/delivery requests ──────────────────────
                    RequestsSection(
                      serviceType: DriverConstants.defaultServiceType,
                      isOnline: state.isOnline,
                      onGoOnline: () => ref
                          .read(driverHomeControllerProvider.notifier)
                          .toggleOnlineStatus(),
                    ),

                    const SizedBox(height: SpacingConstants.xl),

                    // ── Quick actions ────────────────────────────────────────
                    QuickActionsGrid(
                      onHistoryTap: () => _onHistoryTap(context),
                      onWalletTap: () => _onWalletTap(context),
                      onSupportTap: () => _onSupportTap(context),
                      onSettingsTap: () => _onSettingsTap(context),
                    ),

                    // Bottom safe-area padding
                    SizedBox(
                      height: SpacingConstants.xxl +
                          MediaQuery.of(context).padding.bottom,
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Navigation handlers ──────────────────────────────────────────────────

  void _onProfileTap(BuildContext context) =>
      Navigator.pushNamed(context, AppRoutes.driverProfile, arguments: profile);

  void _onNotificationsTap(BuildContext context) =>
      Navigator.pushNamed(context, AppRoutes.notifications);

  void _onHistoryTap(BuildContext context) =>
      Navigator.pushNamed(context, AppRoutes.tripHistory);

  void _onWalletTap(BuildContext context) =>
      Navigator.pushNamed(context, AppRoutes.driverWallet);

  void _onSupportTap(BuildContext context) =>
      Navigator.pushNamed(context, AppRoutes.support);

  void _onSettingsTap(BuildContext context) =>
      Navigator.pushNamed(context, AppRoutes.settings);
}

// ── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SpacingConstants.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: AppColors.errorColor, size: 56),
            const SizedBox(height: SpacingConstants.md),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SpacingConstants.sm),
            Text(
              error,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondaryColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SpacingConstants.xl),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

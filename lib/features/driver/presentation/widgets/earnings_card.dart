// presentation/widgets/earnings_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/earnings_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../../features/driver/extensions/build_context_extensions.dart';
import 'package:cts_transport_driver_app/features/driver/domain/entities/earnings_summary.dart';
import 'package:cts_transport_driver_app/features/driver/utils/formatters.dart';
import '../../../../core/constants/design_constants.dart';

class EarningsCard extends ConsumerWidget {
  const EarningsCard({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earningsAsync = ref.watch(earningsNotifierProvider);
    
    return earningsAsync.when(
      data: (earnings) => _buildEarningsCard(context, earnings),
      loading: () => _buildLoadingCard(),
      error: (error, _) => _buildErrorCard(error),
    );
  }
  
  Widget _buildEarningsCard(BuildContext context, EarningsSummary earnings) {
    return Container(
      padding: const EdgeInsets.all(SpacingConstants.xl),
      decoration: BoxDecoration(
        color: AppColors.backgroundLightColor,
        borderRadius: BorderRadius.circular(RadiusConstants.lg),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: SpacingConstants.lg),
          _buildEarningsRow(earnings),
          const SizedBox(height: SpacingConstants.lg),
          const Divider(color: AppColors.borderColor, height: 1),
          const SizedBox(height: SpacingConstants.lg),
          _buildBalanceRow(context, earnings),
        ],
      ),
    );
  }
  
  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Earnings', style: AppTextStyles.heading4),
        TextButton(
          onPressed: () => context.push('/earnings'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryColor,
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingConstants.sm,
              vertical: SpacingConstants.xs,
            ),
          ),
          child: const Text('See All →'),
        ),
      ],
    );
  }
  
  Widget _buildEarningsRow(EarningsSummary earnings) {
    return Row(
      children: [
        Expanded(
          child: _EarningsTile(
            label: 'Today',
            amount: Formatters.formatCurrency(earnings.todayEarnings),
            trips: '${earnings.todayTrips} trips',
            highlight: true,
          ),
        ),
        Container(
          width: 1,
          height: 50,
          color: AppColors.borderColor,
          margin: const EdgeInsets.symmetric(horizontal: SpacingConstants.lg),
        ),
        Expanded(
          child: _EarningsTile(
            label: 'This Week',
            amount: Formatters.formatCurrency(earnings.weekEarnings),
            trips: '${earnings.weekTrips} trips',
          ),
        ),
      ],
    );
  }
  
  Widget _buildBalanceRow(BuildContext context, EarningsSummary earnings) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Formatters.formatCurrency(earnings.availableBalance),
              style: AppTextStyles.driverStatsValue.copyWith(
                color: AppColors.successColor,
                fontSize: 22,
              ),
            ),
            const Text(
              'Available Balance',
              style: AppTextStyles.driverStats,
            ),
            if (earnings.pendingPayout > 0)
              Text(
                '${Formatters.formatCurrency(earnings.pendingPayout)} pending',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondaryColor,
                ),
              ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: earnings.canWithdraw 
              ? () => context.push('/withdrawal')
              : null,
          icon: const Icon(Icons.account_balance_wallet, size: 16),
          label: const Text('Withdraw'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.successColor,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingConstants.lg,
              vertical: SpacingConstants.sm,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RadiusConstants.sm),
            ),
            textStyle: AppTextStyles.buttonSmall,
          ),
        ),
      ],
    );
  }
  
  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(SpacingConstants.xl),
      decoration: BoxDecoration(
        color: AppColors.backgroundLightColor,
        borderRadius: BorderRadius.circular(RadiusConstants.lg),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: const Column(
        children: [
          Center(child: CircularProgressIndicator()),
          SizedBox(height: SpacingConstants.lg),
          Text('Loading earnings...'),
        ],
      ),
    );
  }
  
  Widget _buildErrorCard(Object error) {
    return Container(
      padding: const EdgeInsets.all(SpacingConstants.xl),
      decoration: BoxDecoration(
        color: AppColors.errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(RadiusConstants.lg),
        border: Border.all(color: AppColors.errorColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: AppColors.errorColor, size: 48),
          const SizedBox(height: SpacingConstants.md),
          Text(
            'Failed to load earnings',
            style: AppTextStyles.heading4.copyWith(color: AppColors.errorColor),
          ),
          const SizedBox(height: SpacingConstants.sm),
          Text(
            error.toString(),
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Earnings Tile Sub-widget
class _EarningsTile extends StatelessWidget {
  final String label;
  final String amount;
  final String? trips;
  final bool highlight;

  const _EarningsTile({
    required this.label,
    required this.amount,
    this.trips,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: SpacingConstants.xs),
        Text(
          amount,
          style: AppTextStyles.driverStatsValue.copyWith(
            fontSize: 18,
            color: highlight 
                ? AppColors.primaryColor 
                : AppColors.textPrimaryColor,
          ),
        ),
        if (trips != null) ...[
          const SizedBox(height: 2),
          Text(trips!, style: AppTextStyles.caption),
        ],
      ],
    );
  }
}
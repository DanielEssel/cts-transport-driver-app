// presentation/widgets/stats_row.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/design_constants.dart';
import '../../../../core/utils/extensions.dart'; // Import your extensions
import '../providers/driver_stats_provider.dart';
import 'stat_card.dart';

class StatsRow extends ConsumerWidget {
  const StatsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(driverStatsNotifierProvider);

    return statsAsync.when(
      data: (stats) => Row(
        children: [
          StatCard(
            label: 'Rating',
            value: stats.rating.toRating(),
            suffix: '★',
            icon: Icons.star_rounded,
            accentColor: const Color(0xFFFFB74D), // Star Gold
          ),
          const SizedBox(width: SpacingConstants.sm),
          StatCard(
            label: 'Trips',
            value: stats.completedTrips.toString(),
            icon: Icons.directions_car_filled_rounded,
            accentColor: AppColors.primaryColor,
          ),
          const SizedBox(width: SpacingConstants.sm),
          StatCard(
            label: 'Acceptance',
            value: stats.acceptanceRate.toPercentage(),
            icon: Icons.check_circle_rounded,
            accentColor: AppColors.successColor,
          ),
        ],
      ),
      loading: () => const _StatsLoadingState(),
      error: (error, _) => _StatsErrorState(message: error.toString()),
    );
  }
}

// Sub-widgets for cleaner code
class _StatsLoadingState extends StatelessWidget {
  const _StatsLoadingState();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (index) => const Expanded(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: LinearProgressIndicator(minHeight: 2, color: AppColors.borderColor),
        ),
      )),
    );
  }
}

class _StatsErrorState extends StatelessWidget {
  final String message;
  const _StatsErrorState({required this.message});
  @override
  Widget build(BuildContext context) {
    return Text('Stats unavailable', style: AppTextStyles.caption.copyWith(color: AppColors.errorColor));
  }
}
// presentation/widgets/loading_shimmer.dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/constants/design_constants.dart';
import '../../../../core/constants/app_colors.dart';

class LoadingShimmer extends StatelessWidget {
  const LoadingShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.borderColor,
      highlightColor: AppColors.backgroundLightColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
        child: Column(
          children: [
            _buildShimmerBox(height: 120),
            const SizedBox(height: SpacingConstants.lg),
            Row(
              children: [
                Expanded(child: _buildShimmerBox(height: 90)),
                const SizedBox(width: SpacingConstants.md),
                Expanded(child: _buildShimmerBox(height: 90)),
                const SizedBox(width: SpacingConstants.md),
                Expanded(child: _buildShimmerBox(height: 90)),
              ],
            ),
            const SizedBox(height: SpacingConstants.lg),
            _buildShimmerBox(height: 160),
            const SizedBox(height: SpacingConstants.lg),
            _buildShimmerBox(height: 200),
          ],
        ),
      ),
    );
  }
  
  Widget _buildShimmerBox({required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(RadiusConstants.md),
      ),
    );
  }
}






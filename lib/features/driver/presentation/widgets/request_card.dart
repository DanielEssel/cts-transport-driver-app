// presentation/widgets/request_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../domain/entities/ride_request.dart';
import 'meta_chip.dart';

class RequestCard extends StatefulWidget {
  final RideRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  
  const RequestCard({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });
  
  @override
  State<RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<RequestCard>
    with SingleTickerProviderStateMixin {
  final bool _isAccepting = false;
  late AnimationController _timerController;
  static const int _requestTimeout = 30;
  
  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _requestTimeout),
    )..forward();
    
    _timerController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        widget.onDecline();
      }
    });
  }
  
  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final currencyFmt = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundLightColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTimerBar(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(request, currencyFmt),
                const SizedBox(height: 14),
                _buildPassengerInfo(request),
                const SizedBox(height: 14),
                _buildRouteIndicator(request.fromAddress, request.toAddress),
                const SizedBox(height: 12),
                _buildTripMeta(request),
                const SizedBox(height: 16),
                _buildActionButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTimerBar() {
    return AnimatedBuilder(
      animation: _timerController,
      builder: (context, _) {
        final remaining = 1.0 - _timerController.value;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: LinearProgressIndicator(
            value: remaining,
            minHeight: 4,
            backgroundColor: AppColors.borderColor.withOpacity(0.5),
            valueColor: AlwaysStoppedAnimation<Color>(
              remaining > 0.4
                  ? AppColors.successColor
                  : remaining > 0.2
                      ? const Color(0xFFFFB74D)
                      : AppColors.errorColor,
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildHeader(RideRequest request, NumberFormat currencyFmt) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: request.requestType.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                request.requestType.displayName,
                style: AppTextStyles.caption.copyWith(
                  color: request.requestType.accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              Formatters.timeAgo(request.createdAt),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondaryColor,
              ),
            ),
          ],
        ),
        Text(
          currencyFmt.format(request.fareAmount),
          style: AppTextStyles.cardPrice,
        ),
      ],
    );
  }
  
  // Additional widget methods...
}
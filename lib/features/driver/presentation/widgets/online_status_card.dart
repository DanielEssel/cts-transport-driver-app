// presentation/widgets/online_status_card.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import 'animated_power_button.dart';

class OnlineStatusCard extends StatelessWidget {
  final bool isOnline;
  final bool isToggling;
  final VoidCallback onToggle;
  
  const OnlineStatusCard({
    super.key,
    required this.isOnline,
    required this.isToggling,
    required this.onToggle,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isToggling ? null : onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isOnline
                ? [const Color(0xFF11C76F), const Color(0xFF0BA855)]
                : [const Color(0xFF3A3A4A), const Color(0xFF2E2E3E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (isOnline ? AppColors.successColor : const Color(0xFF3A3A4A))
                  .withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOnline ? 'You\'re Online' : 'You\'re Offline',
                    style: AppTextStyles.heading3.copyWith(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isOnline
                        ? 'Accepting ride & delivery requests'
                        : 'Tap the button to start earning',
                    style: AppTextStyles.subtitle.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  if (isOnline) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Location sharing active',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            AnimatedPowerButton(
              isOnline: isOnline,
              isToggling: isToggling,
            ),
          ],
        ),
      ),
    );
  }
}


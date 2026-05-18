// presentation/widgets/driver_app_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../features/driver/constants/driver_constants.dart';
import '../../../../core/constants/design_constants.dart';
import '../../../../features/driver/models/driver_types.dart';
import 'package:flutter/services.dart';

class DriverAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final bool onlineStatus;
  final int unreadNotifications;
  final DriverProfile profile;           // ✅ accept directly
  final VoidCallback onProfileTap;
  final VoidCallback onNotificationsTap;

  const DriverAppBar({
    super.key,
    required this.onlineStatus,
    required this.unreadNotifications,
    required this.profile,               // ✅
    required this.onProfileTap,
    required this.onNotificationsTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ❌ Remove: final profileAsync = ref.watch(driverProfileNotifierProvider);
    // ✅ Use profile directly in _buildProfileButton and _buildTitle
    return AppBar(
      backgroundColor: AppColors.backgroundColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: _buildProfileButton(context),
      title: _buildTitle(),
      actions: [
        _buildNotificationButton(context),
        const SizedBox(width: SpacingConstants.xs),
      ],
    );
  }

  Widget _buildProfileButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SpacingConstants.sm),
      child: GestureDetector(
        onTap: onProfileTap,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: onlineStatus ? AppColors.successColor : AppColors.borderColor,
              width: 2.5,
            ),
          ),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primaryLightColor,
            backgroundImage: profile.photoUrl != null
                ? CachedNetworkImageProvider(profile.photoUrl!)
                : null,
            child: profile.photoUrl == null
                ? Text(
                    profile.displayInitial,
                    style: AppTextStyles.heading4.copyWith(
                      color: AppColors.primaryColor,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Hello, ${profile.displayNameShort} 👋',
          style: AppTextStyles.driverGreeting,
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: onlineStatus
                    ? AppColors.successColor
                    : AppColors.textDisabledColor,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              onlineStatus ? 'Online · Accepting Rides' : 'Offline',
              style: AppTextStyles.riderStatus.copyWith(
                color: onlineStatus
                    ? AppColors.successColor
                    : AppColors.textSecondaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildNotificationButton(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(
            Icons.notifications_outlined,
            color: AppColors.textPrimaryColor,
            size: 26,
          ),
          onPressed: onNotificationsTap,
        ),
        if (unreadNotifications > 0)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: AppColors.errorColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  unreadNotifications > DriverConstants.maxUnreadNotifications
                      ? DriverConstants.notificationBadgeText
                      : '$unreadNotifications',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

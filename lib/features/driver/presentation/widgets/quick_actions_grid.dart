// lib/features/driver/presentation/widgets/quick_actions_grid.dart

import 'package:flutter/material.dart';
import 'package:cts_transport_driver_app/core/constants/app_colors.dart';

class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({
    super.key,
    required this.onHistoryTap,
    required this.onWalletTap,
    required this.onSupportTap,
    required this.onSettingsTap,
  });

  final VoidCallback onHistoryTap;
  final VoidCallback onWalletTap;
  final VoidCallback onSupportTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _Action(Icons.history_rounded,                'History',  onHistoryTap),
      _Action(Icons.account_balance_wallet_rounded, 'Wallet',   onWalletTap),
      _Action(Icons.headset_mic_rounded,            'Support',  onSupportTap),
      _Action(Icons.settings_rounded,               'Settings', onSettingsTap),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      children: actions.map((a) => _ActionTile(action: a)).toList(),
    );
  }
}

// ── Data ─────────────────────────────────────────────────────────────────────

class _Action {
  const _Action(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

// ── Tile ─────────────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});
  final _Action action;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: action.onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primaryLightColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              action.icon,
              color: AppColors.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            action.label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
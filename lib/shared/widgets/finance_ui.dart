// lib/shared/widgets/finance_ui.dart
//
// Shared presentation for the money screens (Earnings, Wallet, History): the
// hero card on the Wallet gradient, stat tiles, status pills, service badges
// and the loading / empty / error views. Presentation only: callers pass the
// values they already have, and nothing here reads or computes money.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_theme.dart';

final _ghs = NumberFormat('#,##0.00', 'en_US');

/// 'GH₵ 1,234.50'. Signs are the caller's: pass the absolute amount.
String formatGhs(num amount) => 'GH₵ ${_ghs.format(amount)}';

// ── Status pills ─────────────────────────────────────────────────────────────

enum StatusTone { success, pending, failed, neutral }

/// Text and fill for a [StatusTone]; every pair is 4.5:1 or better.
({Color fg, Color bg}) statusColors(StatusTone tone) => switch (tone) {
      StatusTone.success => (
          fg: AppTheme.primaryDeep,
          bg: AppTheme.primarySubtle
        ),
      StatusTone.pending => (
          fg: AppTheme.warningText,
          bg: AppTheme.warningLight
        ),
      StatusTone.failed => (fg: AppTheme.dangerText, bg: AppTheme.dangerLight),
      StatusTone.neutral => (
          fg: AppTheme.textSecondary,
          bg: AppTheme.background
        ),
    };

class StatusPill extends StatelessWidget {
  final String label;
  final StatusTone tone;
  final IconData? icon;

  const StatusPill({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = statusColors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(20),
        border: tone == StatusTone.neutral
            ? Border.all(color: AppTheme.divider)
            : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: c.fg),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: c.fg,
              )),
        ),
      ]),
    );
  }
}

// ── Service badges ───────────────────────────────────────────────────────────

enum ServiceTone { ride, delivery, gas }

/// The Ride / Delivery / Gas accent, its tint, icon and name.
({Color fg, Color bg, IconData icon, String label}) serviceStyle(
        ServiceTone s) =>
    switch (s) {
      ServiceTone.ride => (
          fg: AppTheme.primaryDark,
          bg: AppTheme.primarySubtle,
          icon: Icons.directions_car_rounded,
          label: 'Ride',
        ),
      ServiceTone.delivery => (
          fg: AppTheme.serviceDelivery,
          bg: AppTheme.serviceDeliveryTint,
          icon: Icons.inventory_2_rounded,
          label: 'Delivery',
        ),
      ServiceTone.gas => (
          fg: AppTheme.serviceGas,
          bg: AppTheme.serviceGasTint,
          icon: Icons.local_gas_station_rounded,
          label: 'Gas',
        ),
    };

class ServiceBadge extends StatelessWidget {
  final ServiceTone service;
  const ServiceBadge({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    final s = serviceStyle(service);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(s.icon, size: 12, color: s.fg),
        const SizedBox(width: 4),
        Flexible(
          child: Text(s.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: s.fg,
              )),
        ),
      ]),
    );
  }
}

// ── Cards ────────────────────────────────────────────────────────────────────

/// The white card used across the money screens.
class FinanceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  const FinanceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Container(
      decoration: BoxDecoration(
        color: color ?? AppTheme.surface,
        borderRadius: radius,
        border: Border.all(color: borderColor ?? AppTheme.divider),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// A headline figure on the Wallet gradient. Small text (the label, caption
/// and stats) sits on [AppTheme.onGradientScrim]; the amount is large.
class FinanceHeroCard extends StatelessWidget {
  final String label;

  /// Pre-formatted amount; ignored while [loading].
  final String amount;
  final String? caption;
  final bool loading;
  final List<FinanceHeroStat> stats;
  final Widget? footer;

  const FinanceHeroCard({
    super.key,
    required this.label,
    required this.amount,
    this.caption,
    this.loading = false,
    this.stats = const [],
    this.footer,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppTheme.primaryGlow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OnScrim(
              child: Text(label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  )),
            ),
            const SizedBox(height: 12),
            if (loading)
              Semantics(
                label: 'Loading',
                child: Container(
                  width: 160,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              )
            else
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(amount,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      height: 1.1,
                    )),
              ),
            if (caption != null || stats.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.onGradientScrim,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (caption != null)
                      Text(caption!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.4,
                          )),
                    if (caption != null && stats.isNotEmpty)
                      const SizedBox(height: 10),
                    if (stats.isNotEmpty)
                      Wrap(spacing: 20, runSpacing: 10, children: stats),
                  ],
                ),
              ),
            ],
            if (footer != null) ...[
              const SizedBox(height: 16),
              footer!,
            ],
          ],
        ),
      );
}

class _OnScrim extends StatelessWidget {
  final Widget child;
  const _OnScrim({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.onGradientScrim,
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      );
}

/// A small label / value pair inside a [FinanceHeroCard].
class FinanceHeroStat extends StatelessWidget {
  final String label;
  final String value;
  const FinanceHeroStat(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              )),
        ],
      );
}

/// An icon, a figure and its label on a white tile.
class FinanceStatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;

  const FinanceStatTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => FinanceCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  )),
            ),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                )),
          ],
        ),
      );
}

/// A title that may wrap or shorten beside an amount that never does: the
/// amount keeps up to [amountShare] of the width and scales down past that.
class FinanceTitleAmountRow extends StatelessWidget {
  final Widget title;
  final Widget amount;
  final double amountShare;

  const FinanceTitleAmountRow({
    super.key,
    required this.title,
    required this.amount,
    this.amountShare = 0.6,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, c) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: c.maxWidth * amountShare),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: amount,
              ),
            ),
          ],
        ),
      );
}

/// A label / value row; [emphasis] for totals.
class FinanceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasis;
  final Color? valueColor;

  const FinanceRow(
    this.label,
    this.value, {
    super.key,
    this.emphasis = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    fontSize: emphasis ? 15 : 14,
                    fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
                    color: emphasis
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                  )),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: emphasis ? 16 : 14,
                    fontWeight: emphasis ? FontWeight.w800 : FontWeight.w600,
                    color: valueColor ??
                        (emphasis
                            ? AppTheme.primaryDark
                            : AppTheme.textPrimary),
                  )),
            ),
          ],
        ),
      );
}

class FinanceSectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const FinanceSectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Text(text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              )),
        ),
        if (trailing != null) trailing!,
      ]);
}

/// A light info note: explains where a figure comes from.
class FinanceNote extends StatelessWidget {
  final String text;
  final IconData icon;
  const FinanceNote(this.text,
      {super.key, this.icon = Icons.info_outline_rounded});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppTheme.textSecondary,
                )),
          ),
        ],
      );
}

// ── Loading / empty / error ──────────────────────────────────────────────────

class FinanceLoadingView extends StatelessWidget {
  final String label;
  const FinanceLoadingView({super.key, required this.label});

  @override
  Widget build(BuildContext context) => Center(
        child: Semantics(
          label: label,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                  strokeWidth: 3, color: AppTheme.primary),
            ),
            const SizedBox(height: 14),
            Text(label,
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textSecondary)),
          ]),
        ),
      );
}

/// Empty and error states. With [onRetry], shows a deep-green Try again.
class FinanceStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final bool isError;
  final String? detail;
  final VoidCallback? onRetry;

  const FinanceStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.isError = false,
    this.detail,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color:
                      isError ? AppTheme.dangerLight : AppTheme.primarySubtle,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(icon,
                    size: 34,
                    color:
                        isError ? AppTheme.dangerText : AppTheme.primaryDark),
              ),
              const SizedBox(height: 18),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  )),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: AppTheme.textSecondary,
                  )),
              if (detail != null) ...[
                const SizedBox(height: 8),
                Text(detail!,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    )),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 22),
                FilledButton.icon(
                  key: const ValueKey('finance-retry'),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(160, 48),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}

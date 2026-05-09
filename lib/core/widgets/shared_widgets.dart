import 'package:flutter/material.dart';
import '../../../../app/app_theme.dart';
import '../../features/earnings/models/earning_record.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/earnings/providers/earnings_provider.dart';

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final earningsAsync = ref.watch(earningsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Earnings'),
        backgroundColor: AppTheme.surface,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'Daily'),
            Tab(text: 'Weekly'),
          ],
        ),
      ),
      body: earningsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (earnings) {
          final weekTotal =
              earnings.fold(0.0, (s, r) => s + r.netEarnings) as double;
          final weekTrips = earnings.fold(0, (s, r) => s + r.totalTrips);
          final todayEarnings =
              earnings.isNotEmpty ? earnings.first.netEarnings : 0.0;

          return TabBarView(
            controller: _tabController,
            children: [
              _DailyView(
                earnings: earnings,
                todayEarnings: todayEarnings,
                todayTrips: earnings.isNotEmpty ? earnings.first.totalTrips : 0,
              ),
              _WeeklyView(
                earnings: earnings,
                weekTotal: weekTotal,
                weekTrips: weekTrips,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Daily View ────────────────────────────────────────────────────────────────
class _DailyView extends StatelessWidget {
  final List<EarningsRecord> earnings;
  final double todayEarnings;
  final int todayTrips;

  const _DailyView({
    required this.earnings,
    required this.todayEarnings,
    required this.todayTrips,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TodaySummaryCard(
            todayEarnings: todayEarnings,
            todayTrips: todayTrips,
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Last 7 Days'),
          const SizedBox(height: 12),
          _BarChart(earnings: earnings),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Breakdown'),
          const SizedBox(height: 12),
          ...earnings.map((e) => _EarningsTile(record: e)),
        ],
      ),
    );
  }
}

class _TodaySummaryCard extends StatelessWidget {
  final double todayEarnings;
  final int todayTrips;

  const _TodaySummaryCard({
    required this.todayEarnings,
    required this.todayTrips,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Net Earnings",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'GH₵ ${todayEarnings.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _MiniStat(
                label: 'Trips',
                value: '$todayTrips',
                color: Colors.white,
              ),
              const SizedBox(width: 24),
              _MiniStat(
                label: 'Platform fee (15%)',
                value:
                    'GH₵ ${_calculatePlatformFee(todayEarnings).toStringAsFixed(2)}',
                color: Colors.white70,
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _calculatePlatformFee(double netEarnings) {
    return netEarnings * 0.15 / 0.85;
  }
}

// ── Weekly View ───────────────────────────────────────────────────────────────
class _WeeklyView extends StatelessWidget {
  final List<EarningsRecord> earnings;
  final double weekTotal;
  final int weekTrips;

  const _WeeklyView({
    required this.earnings,
    required this.weekTotal,
    required this.weekTrips,
  });

  @override
  Widget build(BuildContext context) {
    final avgPerTrip = weekTrips > 0 ? weekTotal / weekTrips : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _SummaryCards(
            weekTotal: weekTotal,
            weekTrips: weekTrips,
            avgPerTrip: avgPerTrip,
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Daily Net Earnings'),
          const SizedBox(height: 12),
          _BarChart(earnings: earnings),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final double weekTotal;
  final int weekTrips;
  final double avgPerTrip;

  const _SummaryCards({
    required this.weekTotal,
    required this.weekTrips,
    required this.avgPerTrip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Week Total',
                value: 'GH₵ ${weekTotal.toStringAsFixed(0)}',
                icon: Icons.account_balance_wallet_rounded,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'Total Trips',
                value: '$weekTrips',
                icon: Icons.route_rounded,
                color: AppTheme.info,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Avg per Trip',
                value: 'GH₵ ${avgPerTrip.toStringAsFixed(2)}',
                icon: Icons.trending_up_rounded,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'Avg per Day',
                value: 'GH₵ ${(weekTotal / 7).toStringAsFixed(2)}',
                icon: Icons.calendar_today_rounded,
                color: AppTheme.primaryDark,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Bar Chart ─────────────────────────────────────────────────────────────────
class _BarChart extends StatelessWidget {
  final List<EarningsRecord> earnings;

  const _BarChart({required this.earnings});

  @override
  Widget build(BuildContext context) {
    final maxVal =
        earnings.fold(0.0, (m, e) => e.netEarnings > m ? e.netEarnings : m);
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      height: 160,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(earnings.length, (i) {
          if (earnings.isEmpty) {
            return const SizedBox(
              height: 160,
              child: Center(child: Text("No earnings yet")),
            );
          }
          final ratio = maxVal > 0 ? earnings[i].netEarnings / maxVal : 0.0;
          final isToday = i == earnings.length - 1;
          final dayLabel = days[
              (DateTime.now().weekday - 1 - (earnings.length - 1 - i)) % 7];

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _BarColumn(
                netEarnings: earnings[i].netEarnings,
                ratio: ratio,
                isToday: isToday,
                dayLabel: dayLabel,
                index: i,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _BarColumn extends StatelessWidget {
  final double netEarnings;
  final double ratio;
  final bool isToday;
  final String dayLabel;
  final int index;

  const _BarColumn({
    required this.netEarnings,
    required this.ratio,
    required this.isToday,
    required this.dayLabel,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'GH₵${netEarnings.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 9,
            color: isToday ? AppTheme.primary : AppTheme.textSecondary,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: Duration(milliseconds: 400 + index * 60),
          height: (ratio * 100).clamp(4, 100),
          decoration: BoxDecoration(
            color: isToday
                ? AppTheme.primary
                : AppTheme.primary.withValues(alpha: 0.3),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isToday ? 'Today' : dayLabel,
          style: TextStyle(
            fontSize: 10,
            color: isToday ? AppTheme.primary : AppTheme.textSecondary,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ── Earnings Tile ─────────────────────────────────────────────────────────────
class _EarningsTile extends StatelessWidget {
  final EarningsRecord record;

  const _EarningsTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final isToday = _isToday(record.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isToday ? AppTheme.primaryLight : AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isToday
              ? AppTheme.primary.withValues(alpha: 0.3)
              : AppTheme.divider,
        ),
      ),
      child: Row(
        children: [
          _DateBadge(
            date: record.date,
            isToday: isToday,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _EarningsInfo(
              date: record.date,
              isToday: isToday,
              totalTrips: record.totalTrips,
              platformFee: record.platformFee,
            ),
          ),
          _EarningsAmount(
            netEarnings: record.netEarnings,
            totalEarnings: record.totalEarnings,
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }
}

class _DateBadge extends StatelessWidget {
  final DateTime date;
  final bool isToday;

  const _DateBadge({
    required this.date,
    required this.isToday,
  });

  String get dayLabel {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: isToday ? AppTheme.primary : AppTheme.divider,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            dayLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isToday ? Colors.white70 : AppTheme.textSecondary,
            ),
          ),
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isToday ? Colors.white : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningsInfo extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final int totalTrips;
  final double platformFee;

  const _EarningsInfo({
    required this.date,
    required this.isToday,
    required this.totalTrips,
    required this.platformFee,
  });

  String get fullDayLabel {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isToday ? 'Today' : fullDayLabel,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$totalTrips trips · Platform fee: GH₵${platformFee.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _EarningsAmount extends StatelessWidget {
  final double netEarnings;
  final double totalEarnings;

  const _EarningsAmount({
    required this.netEarnings,
    required this.totalEarnings,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'GH₵ ${netEarnings.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'gross: GH₵${totalEarnings.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── Mini Stat ─────────────────────────────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

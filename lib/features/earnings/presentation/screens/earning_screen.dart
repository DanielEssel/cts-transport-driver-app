import 'package:flutter/material.dart';
import '../../../jobs/data/mock_data.dart';
import '../../../../app/app_theme.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../models/earning_record.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<EarningsRecord> _earnings;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _earnings = MockDataService.getMockEarnings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  double get _weekTotal =>
      _earnings.fold(0, (s, r) => s + r.netEarnings);
  int get _weekTrips => _earnings.fold(0, (s, r) => s + r.totalTrips);
  double get _todayEarnings =>
      _earnings.isNotEmpty ? _earnings.first.netEarnings : 0;

  @override
  Widget build(BuildContext context) {
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _DailyView(
            earnings: _earnings,
            todayEarnings: _todayEarnings,
            todayTrips:
                _earnings.isNotEmpty ? _earnings.first.totalTrips : 0,
          ),
          _WeeklyView(
            earnings: _earnings,
            weekTotal: _weekTotal,
            weekTrips: _weekTrips,
          ),
        ],
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
          // Today summary card
          Container(
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
                        color: Colors.white),
                    const SizedBox(width: 24),
                    _MiniStat(
                        label: 'Platform fee (15%)',
                        value:
                            'GH₵ ${(todayEarnings * 0.15 / 0.85).toStringAsFixed(2)}',
                        color: Colors.white70),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const SectionHeader(title: 'Last 7 Days'),
          const SizedBox(height: 12),

          // Bar chart
          _BarChart(earnings: earnings),
          const SizedBox(height: 24),

          // Daily breakdown list
          const SectionHeader(title: 'Breakdown'),
          const SizedBox(height: 12),

          ...earnings.map((e) => _EarningsTile(record: e)),
        ],
      ),
    );
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
    final avgPerTrip =
        weekTrips > 0 ? weekTotal / weekTrips : 0.0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Summary row
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Week Total',
                  value:
                      'GH₵ ${weekTotal.toStringAsFixed(0)}',
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
                  value:
                      'GH₵ ${avgPerTrip.toStringAsFixed(2)}',
                  icon: Icons.trending_up_rounded,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Avg per Day',
                  value:
                      'GH₵ ${(weekTotal / 7).toStringAsFixed(2)}',
                  icon: Icons.calendar_today_rounded,
                  color: AppTheme.primaryDark,
                ),
              ),
            ],
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

// ── Bar Chart ─────────────────────────────────────────────────────────────────
class _BarChart extends StatelessWidget {
  final List<EarningsRecord> earnings;

  const _BarChart({required this.earnings});

  @override
  Widget build(BuildContext context) {
    final maxVal =
        earnings.fold(0.0, (m, e) => e.netEarnings > m ? e.netEarnings : m);
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      height: 160,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(earnings.length, (i) {
          final e = earnings[earnings.length - 1 - i];
          final ratio = maxVal > 0 ? e.netEarnings / maxVal : 0.0;
          final isToday = i == earnings.length - 1;
          final dayLabel = days[
              (DateTime.now().weekday - 1 - (earnings.length - 1 - i)) % 7];

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'GH₵${e.netEarnings.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 9,
                      color: isToday
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                      fontWeight: isToday
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: Duration(milliseconds: 400 + i * 60),
                    height: (ratio * 100).clamp(4, 100),
                    decoration: BoxDecoration(
                      color: isToday
                          ? AppTheme.primary
                          : AppTheme.primary.withOpacity(0.3),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isToday ? 'Today' : dayLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: isToday
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                      fontWeight: isToday
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

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
              ? AppTheme.primary.withOpacity(0.3)
              : AppTheme.divider,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isToday
                  ? AppTheme.primary
                  : AppTheme.divider,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _dayLabel(record.date),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isToday
                        ? Colors.white70
                        : AppTheme.textSecondary,
                  ),
                ),
                Text(
                  '${record.date.day}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isToday
                        ? Colors.white
                        : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday ? 'Today' : _fullDayLabel(record.date),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '${record.totalTrips} trips · Platform fee: GH₵${record.platformFee.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'GH₵ ${record.netEarnings.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              Text(
                'gross: GH₵${record.totalEarnings.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  String _dayLabel(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[d.weekday - 1];
  }

  String _fullDayLabel(DateTime d) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[d.weekday - 1];
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.7))),
        Text(value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}
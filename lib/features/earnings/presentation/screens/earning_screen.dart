// lib/features/earnings/presentation/earnings_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../../../../app/app_theme.dart';
import '../../models/earning_record.dart';
import '../../../earnings/providers/earnings_provider.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late EarningsProvider _earningsProvider;

  List<EarningsRecord> _earnings = [];
  bool _loading = true;
  String? _error;

  // Period selection for weekly view
  String _selectedPeriod = 'week'; // week, month, year
  Map<String, dynamic> _summaryData = {};

  // Pull-to-refresh
  final RefreshIndicator _refreshIndicator = const RefreshIndicator(
    onRefresh: _onRefresh,
    child: SizedBox(),
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _earningsProvider = EarningsProvider();
    _loadEarnings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  static Future<void> _onRefresh() async {
    // Refresh logic will be called from the widget
  }

  // ───────────────── FETCH DATA FROM FIREBASE ─────────────────
  Future<void> _loadEarnings() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final driverId = FirebaseAuth.instance.currentUser?.uid;
      if (driverId == null) throw Exception('User not logged in');

      final now = DateTime.now();
      final startDate = _getStartDate(now, _selectedPeriod);

      // Fetch completed trips from Firestore
      final tripsQuery = await FirebaseFirestore.instance
          .collection('trips')
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'completed')
          .where('completedAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .orderBy('completedAt', descending: true)
          .get();

      // Group trips by date
      final Map<String, List<QueryDocumentSnapshot>> tripsByDate = {};

      for (var doc in tripsQuery.docs) {
        final data = doc.data();
        final completedAt = (data['completedAt'] as Timestamp).toDate();
        final dateKey = DateFormat('yyyy-MM-dd').format(completedAt);

        tripsByDate.putIfAbsent(dateKey, () => []).add(doc);
      }

      // Build earnings records
      final earningsList = <EarningsRecord>[];
      double totalNetEarnings = 0;
      int totalTrips = 0;

      for (var dateKey in tripsByDate.keys) {
        final trips = tripsByDate[dateKey]!;
        double dailyGross = 0;

        for (var trip in trips) {
  final data = trip.data() as Map<String, dynamic>?;

  if (data == null) continue;

  final fare = (data['finalFare'] ?? data['fare'] ?? 0) as num;

  dailyGross += fare.toDouble();
}

        final platformFee = dailyGross * 0.15; // 15% platform fee
        final netEarnings = dailyGross - platformFee;
        final date = DateFormat('yyyy-MM-dd').parse(dateKey);

        earningsList.add(EarningsRecord(
          dayId: dateKey,
          totalTrips: trips.length,
          totalEarnings: dailyGross,
          grossEarnings: dailyGross,
          platformFee: platformFee,
          netEarnings: netEarnings,
        ));

        totalNetEarnings += netEarnings;
        totalTrips += trips.length;
      }

      // Sort by date ascending
      earningsList.sort((a, b) => a.dayId.compareTo(b.dayId));

      // Calculate summary
      _summaryData = {
        'totalNetEarnings': totalNetEarnings,
        'totalTrips': totalTrips,
        'avgPerTrip': totalTrips > 0 ? totalNetEarnings / totalTrips : 0,
        'avgPerDay': earningsList.isNotEmpty
            ? totalNetEarnings / earningsList.length
            : 0,
      };

      setState(() {
        _earnings = earningsList;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading earnings: $e');
      setState(() {
        _error = e.toString();
        _loading = false;
      });

      // Show error snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load earnings: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  DateTime _getStartDate(DateTime now, String period) {
    switch (period) {
      case 'week':
        return now.subtract(Duration(days: now.weekday - 1));
      case 'month':
        return DateTime(now.year, now.month, 1);
      case 'year':
        return DateTime(now.year, 1, 1);
      default:
        return now.subtract(const Duration(days: 7));
    }
  }

  // ───────────────── SAFE GETTERS ─────────────────
  List<EarningsRecord> get earnings => _earnings;

  double get _weekTotal => earnings.fold(0, (s, r) => s + r.netEarnings);
  int get _weekTrips => earnings.fold(0, (s, r) => s + r.totalTrips);

  double get _todayEarnings {
    if (earnings.isEmpty) return 0;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayRecord = earnings
        .where((e) => DateFormat('yyyy-MM-dd').format(e.date) == today)
        .firstOrNull;
    return todayRecord?.netEarnings ?? 0;
  }

  int get _todayTrips {
    if (earnings.isEmpty) return 0;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayRecord = earnings
        .where((e) => DateFormat('yyyy-MM-dd').format(e.date) == today)
        .firstOrNull;
    return todayRecord?.totalTrips ?? 0;
  }

  // ───────────────── UI ─────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Error loading earnings', style: AppTheme.heading4),
              const SizedBox(height: 8),
              const Text('Error loading earnings', style: AppTheme.caption),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadEarnings,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Earnings'),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        actions: [
          // Period filter for weekly view
          if (_tabController.index == 1)
            PopupMenuButton<String>(
              icon: const Icon(Icons.filter_list),
              onSelected: (value) {
                setState(() {
                  _selectedPeriod = value;
                  _loadEarnings();
                });
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'week',
                  child: Text('This Week'),
                ),
                const PopupMenuItem(
                  value: 'month',
                  child: Text('This Month'),
                ),
                const PopupMenuItem(
                  value: 'year',
                  child: Text('This Year'),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: _exportEarnings,
            tooltip: 'Export earnings report',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'Daily View'),
            Tab(text: 'Weekly Analysis'),
          ],
          onTap: (index) {
            if (index == 1 && _earnings.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No earnings data available for this period'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadEarnings();
        },
        child: TabBarView(
          controller: _tabController,
          children: [
            _DailyView(
              earnings: earnings,
              todayEarnings: _todayEarnings,
              todayTrips: _todayTrips,
              onRefresh: _loadEarnings,
            ),
            _WeeklyView(
              earnings: earnings,
              weekTotal: _weekTotal,
              weekTrips: _weekTrips,
              summaryData: _summaryData,
              period: _selectedPeriod,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportEarnings() async {
    try {
      // Create CSV content
      final buffer = StringBuffer();
      buffer
          .writeln('Date,Trips,Gross Earnings,Platform Fee (15%),Net Earnings');

      for (var record in earnings.reversed) {
        buffer.writeln('${DateFormat('yyyy-MM-dd').format(record.date)},'
            '${record.totalTrips},'
            '${record.totalEarnings.toStringAsFixed(2)},'
            '${record.platformFee.toStringAsFixed(2)},'
            '${record.netEarnings.toStringAsFixed(2)}');
      }

      // Add summary
      buffer.writeln();
      buffer.writeln('Summary');
      buffer.writeln('Total Trips,${const Text('Total Trips')}');
      buffer.writeln('Total Net Earnings,${const Text('Total Net Earnings')}');
      buffer.writeln('Average Per Trip,${const Text('Average Per Trip')}');

      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: buffer.toString()));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Earnings data copied to clipboard'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ── Daily View (Enhanced) ────────────────────────────────────────────────
class _DailyView extends StatelessWidget {
  final List<EarningsRecord> earnings;
  final double todayEarnings;
  final int todayTrips;
  final VoidCallback onRefresh;

  const _DailyView({
    required this.earnings,
    required this.todayEarnings,
    required this.todayTrips,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (earnings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No earnings yet',
              style: AppTheme.heading4.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete your first trip to see earnings',
              style: AppTheme.caption.copyWith(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Today summary card with shimmer effect and animation
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            builder: (context, value, child) {
              return Opacity(opacity: value, child: child);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
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
                        value: todayTrips > 0
                            ? 'GH₵ ${(todayEarnings * 0.15 / 0.85).toStringAsFixed(2)}'
                            : 'GH₵ 0.00',
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Achievement badges if applicable
          if (_getStreakDays() >= 3)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🔥 ${_getStreakDays()} Day Streak!',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const Text(
                          'Keep up the great work!',
                          style: AppTheme.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          const SectionHeader(title: 'Last 7 Days'),
          const SizedBox(height: 12),

          // Interactive bar chart
          _EnhancedBarChart(earnings: earnings),
          const SizedBox(height: 24),

          // Daily breakdown list with search
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionHeader(title: 'Breakdown'),
              TextButton.icon(
                onPressed: () => _showSearchDialog(context),
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Search'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ...earnings.reversed.map((e) => _EnhancedEarningsTile(record: e)),
        ],
      ),
    );
  }

  int _getStreakDays() {
    // Calculate consecutive days with trips
    if (earnings.isEmpty) return 0;

    int streak = 0;
    final today = DateTime.now();

    for (int i = 0; i < earnings.length; i++) {
      final record = earnings[earnings.length - 1 - i];
      final expectedDate = today.subtract(Duration(days: i));

      if (record.date.year == expectedDate.year &&
          record.date.month == expectedDate.month &&
          record.date.day == expectedDate.day &&
          record.totalTrips > 0) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Search Earnings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Enter date (YYYY-MM-DD)',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onSubmitted: (value) {
                try {
                  final date = DateFormat('yyyy-MM-dd').parse(value);
                  final record = earnings.firstWhere(
                    (e) =>
                        e.date.year == date.year &&
                        e.date.month == date.month &&
                        e.date.day == date.day,
                  );
                  Navigator.pop(context);
                  _showEarningDetails(context, record);
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('No earnings found for this date')),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showEarningDetails(BuildContext context, EarningsRecord record) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(record.date),
              style: AppTheme.heading4,
            ),
            const SizedBox(height: 16),
            _DetailRow('Trips Completed', '${record.totalTrips}'),
            _DetailRow('Gross Earnings',
                'GH₵ ${record.totalEarnings.toStringAsFixed(2)}'),
            _DetailRow('Platform Fee (15%)',
                'GH₵ ${record.platformFee.toStringAsFixed(2)}'),
            const Divider(height: 32),
            _DetailRow(
              'Net Earnings',
              'GH₵ ${record.netEarnings.toStringAsFixed(2)}',
              isTotal: true,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ── Weekly View (Enhanced) ───────────────────────────────────────────────
class _WeeklyView extends StatelessWidget {
  final List<EarningsRecord> earnings;
  final double weekTotal;
  final int weekTrips;
  final Map<String, dynamic> summaryData;
  final String period;

  const _WeeklyView({
    required this.earnings,
    required this.weekTotal,
    required this.weekTrips,
    required this.summaryData,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    if (earnings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No data for selected period'),
          ],
        ),
      );
    }

    final avgPerTrip = summaryData['avgPerTrip'] ?? 0.0;
    final avgPerDay = summaryData['avgPerDay'] ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Summary stats with animations
          Row(
            children: [
              Expanded(
                child: _AnimatedStatCard(
                  label: period == 'week'
                      ? 'Week Total'
                      : period == 'month'
                          ? 'Month Total'
                          : 'Year Total',
                  value: 'GH₵ ${weekTotal.toStringAsFixed(0)}',
                  icon: Icons.account_balance_wallet_rounded,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AnimatedStatCard(
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
                child: _AnimatedStatCard(
                  label: 'Avg per Trip',
                  value: 'GH₵ ${avgPerTrip.toStringAsFixed(2)}',
                  icon: Icons.trending_up_rounded,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AnimatedStatCard(
                  label: 'Avg per Day',
                  value: 'GH₵ ${avgPerDay.toStringAsFixed(2)}',
                  icon: Icons.calendar_today_rounded,
                  color: AppTheme.primaryDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Performance indicator
          _PerformanceIndicator(
            weekTotal: weekTotal,
            weekTrips: weekTrips,
            avgPerTrip: avgPerTrip,
          ),

          const SizedBox(height: 24),

          const SectionHeader(title: 'Daily Earnings Trend'),
          const SizedBox(height: 12),
          _EnhancedBarChart(earnings: earnings),

          const SizedBox(height: 24),

          // Projected earnings
          if (period == 'week' && earnings.isNotEmpty)
            _ProjectedEarnings(
              currentTotal: weekTotal,
              currentTrips: weekTrips,
              daysRemaining: 7 - earnings.length,
            ),

          const SizedBox(height: 16),

          // Export and share buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _exportReport(context),
                  icon: const Icon(Icons.download),
                  label: const Text('Export Report'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _shareReport(context),
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _exportReport(BuildContext context) async {
    try {
      final buffer = StringBuffer();
      buffer.writeln(
          'Earnings Report - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}');
      buffer.writeln('Period: $period');
      buffer.writeln('Total Earnings: GH₵ ${weekTotal.toStringAsFixed(2)}');
      buffer.writeln('Total Trips: $weekTrips');
      buffer.writeln(
          'Average per Trip: GH₵ ${(weekTotal / weekTrips).toStringAsFixed(2)}');
      buffer.writeln();
      buffer.writeln('Daily Breakdown:');
      buffer.writeln('Date,Trips,Earnings');

      for (var record in earnings) {
        buffer.writeln('${DateFormat('yyyy-MM-dd').format(record.date)},'
            '${record.totalTrips},'
            'GH₵ ${record.netEarnings.toStringAsFixed(2)}');
      }

      await Clipboard.setData(ClipboardData(text: buffer.toString()));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report copied to clipboard'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export: $e')),
        );
      }
    }
  }

  void _shareReport(BuildContext context) {
    // Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share feature coming soon')),
    );
  }
}

// ── Enhanced Bar Chart with Tooltips ──────────────────────────────────────
class _EnhancedBarChart extends StatelessWidget {
  final List<EarningsRecord> earnings;

  const _EnhancedBarChart({required this.earnings});

  @override
  Widget build(BuildContext context) {
    if (earnings.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: Text('No data to display')),
      );
    }

    final maxVal =
        earnings.fold(0.0, (m, e) => e.netEarnings > m ? e.netEarnings : m);
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      height: 180,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(earnings.length, (i) {
          final e = earnings[i];
          final ratio = maxVal > 0 ? e.netEarnings / maxVal : 0.0;
          final isToday = DateFormat('yyyy-MM-dd').format(e.date) ==
              DateFormat('yyyy-MM-dd').format(DateTime.now());
          final dayLabel = days[e.date.weekday - 1];

          return Expanded(
            child: GestureDetector(
              onTap: () => _showTooltip(context, e, dayLabel),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedContainer(
                      duration: Duration(milliseconds: 300 + i * 50),
                      height: (ratio * 100).clamp(4, 100),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isToday
                              ? [AppTheme.primary, AppTheme.primaryDark]
                              : [
                                  AppTheme.primary.withOpacity(0.5),
                                  AppTheme.primary.withOpacity(0.3)
                                ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isToday ? 'Today' : dayLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            isToday ? AppTheme.primary : AppTheme.textSecondary,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'GH₵${e.netEarnings.toStringAsFixed(0)}',
                      style:const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  void _showTooltip(BuildContext context, EarningsRecord record, String day) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$day, ${DateFormat('MMM d').format(record.date)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow('Trips', '${record.totalTrips}'),
            const SizedBox(height: 8),
            _DetailRow(
                'Net Earnings', 'GH₵ ${record.netEarnings.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _DetailRow('Gross Earnings',
                'GH₵ ${record.totalEarnings.toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ── Enhanced Earnings Tile ────────────────────────────────────────────────
class _EnhancedEarningsTile extends StatelessWidget {
  final EarningsRecord record;

  const _EnhancedEarningsTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final isToday = _isToday(record.date);

    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Opacity(opacity: value, child: child);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isToday ? AppTheme.primaryLight : AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                isToday ? AppTheme.primary.withOpacity(0.3) : AppTheme.divider,
          ),
        ),
        child: ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isToday ? AppTheme.primary : AppTheme.divider,
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
                    color: isToday ? Colors.white70 : AppTheme.textSecondary,
                  ),
                ),
                Text(
                  '${record.date.day}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isToday ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          title: Text(
            isToday ? 'Today' : _fullDayLabel(record.date),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '${record.totalTrips} trips · Fee: GH₵${record.platformFee.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'GH₵ ${record.netEarnings.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              Text(
                'Gross: GH₵${record.totalEarnings.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
          onTap: () => _showDetails(context),
        ),
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

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(record.date),
              style: AppTheme.heading4,
            ),
            const SizedBox(height: 16),
            _DetailRow('Completed Trips', '${record.totalTrips}'),
            _DetailRow('Gross Earnings',
                'GH₵ ${record.totalEarnings.toStringAsFixed(2)}'),
            _DetailRow('Platform Fee (15%)',
                'GH₵ ${record.platformFee.toStringAsFixed(2)}'),
            const Divider(height: 32),
            _DetailRow(
              'Net Earnings',
              'GH₵ ${record.netEarnings.toStringAsFixed(2)}',
              isTotal: true,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Supporting Widgets ────────────────────────────────────────────────────

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
        Text(label,
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.7))),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

class _AnimatedStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _AnimatedStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, value, child) {
        return Opacity(opacity: value, child: child);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(value,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _PerformanceIndicator extends StatelessWidget {
  final double weekTotal;
  final int weekTrips;
  final double avgPerTrip;

  const _PerformanceIndicator({
    required this.weekTotal,
    required this.weekTrips,
    required this.avgPerTrip,
  });

  @override
  Widget build(BuildContext context) {
    // Benchmark: GHS 500/week or GHS 20/trip
    final earningsTargetMet = weekTotal >= 500;
    final tripsTargetMet = weekTrips >= 25;
    final avgTargetMet = avgPerTrip >= 20;

    final performanceScore = ((earningsTargetMet ? 40 : 0) +
        (tripsTargetMet ? 30 : 0) +
        (avgTargetMet ? 30 : 0));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Performance Score',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '$performanceScore%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: performanceScore >= 70 ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: performanceScore / 100,
            backgroundColor: Colors.grey[200],
            color: performanceScore >= 70 ? Colors.green : Colors.orange,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: [
              _PerformanceBadge(
                text: 'Weekly Target',
                met: earningsTargetMet,
                target: 'GHS 500',
              ),
              _PerformanceBadge(
                text: 'Trips Target',
                met: tripsTargetMet,
                target: '25 trips',
              ),
              _PerformanceBadge(
                text: 'Avg/Trip Target',
                met: avgTargetMet,
                target: 'GHS 20',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PerformanceBadge extends StatelessWidget {
  final String text;
  final bool met;
  final String target;

  const _PerformanceBadge({
    required this.text,
    required this.met,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: met ? Colors.green[100] : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            met ? Icons.check_circle : Icons.timer,
            size: 14,
            color: met ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: met ? Colors.green[800] : Colors.grey[700],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '($target)',
            style: TextStyle(
              fontSize: 10,
              color: met ? Colors.green[600] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectedEarnings extends StatelessWidget {
  final double currentTotal;
  final int currentTrips;
  final int daysRemaining;

  const _ProjectedEarnings({
    required this.currentTotal,
    required this.currentTrips,
    required this.daysRemaining,
  });

  @override
  Widget build(BuildContext context) {
    final avgPerDay = currentTotal / (7 - daysRemaining);
    final projectedTotal = currentTotal + (avgPerDay * daysRemaining);
    final projectedTrips = currentTrips +
        ((currentTrips / (7 - daysRemaining)) * daysRemaining).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[50]!, Colors.purple[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📈 Projected Week End',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'GH₵ ${projectedTotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                    const Text('Total Earnings',
                        style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              Container(height: 40, width: 1, color: Colors.purple[200]),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$projectedTrips',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                    const Text('Total Trips', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              Container(height: 40, width: 1, color: Colors.purple[200]),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$daysRemaining',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                    const Text('Days Left', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _DetailRow(
    this.label,
    this.value, {
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal ? AppTheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}

// Helper widget for section header if not defined
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const SectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: const Text('See All'),
          ),
      ],
    );
  }
}

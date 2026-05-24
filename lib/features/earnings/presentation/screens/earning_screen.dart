// lib/features/earnings/presentation/screens/earning_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────────────────────────────────────

class _C {
  static const bg = Color(0xFFF0F2F8);
  static const card = Color(0xFFFFFFFF);
  static const primary = Color(0xFF1A56DB);
  static const primaryDim = Color(0xFFEBF0FD);
  static const success = Color(0xFF0E9F6E);
  static const successDim = Color(0xFFDEF7EC);
  static const warning = Color(0xFFE3A008);
  static const warningDim = Color(0xFFFDF3D0);
  static const error = Color(0xFFE02424);
  static const textPrimary = Color(0xFF111928);
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5E7EB);

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────

class _DailyRecord {
  final DateTime date;
  final int trips;
  final int deliveries;
  final int gasOrders;
  final double gross;
  final double platformFee;
  final double net;

  int get totalJobs => trips + deliveries + gasOrders;

  const _DailyRecord({
    required this.date,
    required this.trips,
    required this.deliveries,
    required this.gasOrders,
    required this.gross,
    required this.platformFee,
    required this.net,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // State
  List<_DailyRecord> _records = [];
  bool _loading = true;
  String? _error;
  String _period = 'week'; // week | month | year

  static const double _platformFeeRate = 0.15;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ── Data loading ────────────────────────────────────────────────────────────

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not authenticated');

      final now = DateTime.now();
      final start = _startDate(now);
      final ts = Timestamp.fromDate(start);

      // ── Fetch all three collections in parallel ──
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('trips')
            .where('driverId', isEqualTo: uid)
            .where('status', isEqualTo: 'completed')
            .where('completedAt', isGreaterThanOrEqualTo: ts)
            .orderBy('completedAt', descending: false)
            .get(),
        FirebaseFirestore.instance
            .collection('deliveries')
            .where('driverId', isEqualTo: uid)
            .where('status', isEqualTo: 'completed')
            .where('completedAt', isGreaterThanOrEqualTo: ts)
            .orderBy('completedAt', descending: false)
            .get(),
        FirebaseFirestore.instance
            .collection('gas_orders')
            .where('driverId', isEqualTo: uid)
            .where('status', isEqualTo: 'delivered')
            .where('deliveredAt', isGreaterThanOrEqualTo: ts)
            .orderBy('deliveredAt', descending: false)
            .get(),
      ]);

      final tripSnap = results[0];
      final deliverySnap = results[1];
      final gasSnap = results[2];

      // ── Group by date ──
      final Map<String, Map<String, dynamic>> byDate = {};

      void addEntry(QueryDocumentSnapshot doc, String type) {
        final d = doc.data() as Map<String, dynamic>;
        final tsField = type == 'gas' ? 'deliveredAt' : 'completedAt';
        final date = (d[tsField] as Timestamp?)?.toDate() ?? now;
        final key = DateFormat('yyyy-MM-dd').format(date);
        final fare = type == 'trip'
            ? (d['finalFare'] ?? d['estimatedFare'] ?? 0) as num
            : type == 'delivery'
                ? (d['actualFare'] ?? d['estimatedFare'] ?? 0) as num
                : (d['actualFare'] ?? d['totalPrice'] ?? 0) as num;

        byDate.putIfAbsent(
            key,
            () => {
                  'date': date,
                  'trips': 0,
                  'deliveries': 0,
                  'gasOrders': 0,
                  'gross': 0.0,
                });
        byDate[key]!['gross'] =
            (byDate[key]!['gross'] as double) + fare.toDouble();
        if (type == 'trip') byDate[key]!['trips']++;
        if (type == 'delivery') byDate[key]!['deliveries']++;
        if (type == 'gas') byDate[key]!['gasOrders']++;
      }

      for (final doc in tripSnap.docs) {
        addEntry(doc, 'trip');
      }
      for (final doc in deliverySnap.docs) {
        addEntry(doc, 'delivery');
      }
      for (final doc in gasSnap.docs) {
        addEntry(doc, 'gas');
      }

      // ── Build records ──
      final records = byDate.entries.map((e) {
        final gross = e.value['gross'] as double;
        final fee = gross * _platformFeeRate;
        return _DailyRecord(
          date: e.value['date'] as DateTime,
          trips: e.value['trips'] as int,
          deliveries: e.value['deliveries'] as int,
          gasOrders: e.value['gasOrders'] as int,
          gross: gross,
          platformFee: fee,
          net: gross - fee,
        );
      }).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      if (mounted) {
        setState(() {
          _records = records;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  DateTime _startDate(DateTime now) {
    switch (_period) {
      case 'month':
        return DateTime(now.year, now.month, 1);
      case 'year':
        return DateTime(now.year, 1, 1);
      default: // week — Monday
        return now.subtract(Duration(days: now.weekday - 1));
    }
  }

  // ── Computed ────────────────────────────────────────────────────────────────

  double get _totalNet => _records.fold(0, (s, r) => s + r.net);
  double get _totalGross => _records.fold(0, (s, r) => s + r.gross);
  int get _totalJobs => _records.fold(0, (s, r) => s + r.totalJobs);

  _DailyRecord? get _today {
    final key = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      return _records
          .firstWhere((r) => DateFormat('yyyy-MM-dd').format(r.date) == key);
    } catch (_) {
      return null;
    }
  }

  // ── Export ──────────────────────────────────────────────────────────────────

  Future<void> _export() async {
    final buf = StringBuffer();
    buf.writeln('CTS Transport — Earnings Report');
    buf.writeln('Period: $_period');
    buf.writeln(
        'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
    buf.writeln();
    buf.writeln(
        'Date,Trips,Deliveries,Gas Orders,Gross (GH₵),Fee (GH₵),Net (GH₵)');
    for (final r in _records.reversed) {
      buf.writeln(
        '${DateFormat('yyyy-MM-dd').format(r.date)},'
        '${r.trips},${r.deliveries},${r.gasOrders},'
        '${r.gross.toStringAsFixed(2)},'
        '${r.platformFee.toStringAsFixed(2)},'
        '${r.net.toStringAsFixed(2)}',
      );
    }
    buf.writeln();
    buf.writeln('TOTALS,,,,${_totalGross.toStringAsFixed(2)},'
        '${(_totalGross * _platformFeeRate).toStringAsFixed(2)},'
        '${_totalNet.toStringAsFixed(2)}');

    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report copied to clipboard ✓')),
      );
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        title: const Text('Earnings',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: _C.card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Period',
            onSelected: (v) {
              setState(() => _period = v);
              _load();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'week', child: Text('This Week')),
              const PopupMenuItem(value: 'month', child: Text('This Month')),
              const PopupMenuItem(value: 'year', child: Text('This Year')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Export CSV',
            onPressed: _records.isEmpty ? null : _export,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: _C.primary,
          unselectedLabelColor: _C.textSecondary,
          indicatorColor: _C.primary,
          indicatorWeight: 2.5,
          tabs: const [
            Tab(text: 'Daily'),
            Tab(text: 'Summary'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  color: _C.primary,
                  onRefresh: () async => _load(),
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _DailyTab(
                        records: _records,
                        today: _today,
                        period: _period,
                      ),
                      _SummaryTab(
                        records: _records,
                        totalNet: _totalNet,
                        totalGross: _totalGross,
                        totalJobs: _totalJobs,
                        period: _period,
                      ),
                    ],
                  ),
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DAILY TAB
// ─────────────────────────────────────────────────────────────────────────────

class _DailyTab extends StatelessWidget {
  final List<_DailyRecord> records;
  final _DailyRecord? today;
  final String period;

  const _DailyTab({
    required this.records,
    required this.today,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const _EmptyView();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        // ── Today hero card ──
        _TodayCard(today: today),
        const SizedBox(height: 20),

        // ── Bar chart ──
        _BarChart(records: records),
        const SizedBox(height: 24),

        // ── Streak ──
        _StreakBanner(records: records),
        const SizedBox(height: 20),

        // ── Section label ──
        const _Label('Daily Breakdown'),
        const SizedBox(height: 12),

        // ── Records list ──
        ...records.reversed.map(
            (r) => _DayTile(record: r, onTap: () => _showDetail(context, r))),
      ],
    );
  }

  void _showDetail(BuildContext context, _DailyRecord r) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _DetailSheet(record: r),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUMMARY TAB
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryTab extends StatelessWidget {
  final List<_DailyRecord> records;
  final double totalNet;
  final double totalGross;
  final int totalJobs;
  final String period;

  const _SummaryTab({
    required this.records,
    required this.totalNet,
    required this.totalGross,
    required this.totalJobs,
    required this.period,
  });

  int get _tripCount => records.fold(0, (s, r) => s + r.trips);
  int get _deliveryCount => records.fold(0, (s, r) => s + r.deliveries);
  int get _gasCount => records.fold(0, (s, r) => s + r.gasOrders);
  double get _avgPerJob => totalJobs > 0 ? totalNet / totalJobs : 0;
  double get _avgPerDay => records.isNotEmpty ? totalNet / records.length : 0;
  double get _totalFee => totalGross * 0.15;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const _EmptyView();

    final periodLabel = switch (period) {
      'month' => 'This Month',
      'year' => 'This Year',
      _ => 'This Week',
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        // ── Total card ──
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A56DB), Color(0xFF1E429F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A56DB).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$periodLabel Net Earnings',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                'GH₵ ${totalNet.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _HeroStat('Jobs', '$totalJobs'),
                  const SizedBox(width: 24),
                  _HeroStat('Gross', 'GH₵ ${totalGross.toStringAsFixed(0)}'),
                  const SizedBox(width: 24),
                  _HeroStat('Fee', 'GH₵ ${_totalFee.toStringAsFixed(0)}'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Stats grid ──
        Row(children: [
          Expanded(
              child: _StatCard(
            icon: Icons.directions_car_rounded,
            iconBg: _C.primaryDim,
            iconColor: _C.primary,
            label: 'Trips',
            value: '$_tripCount',
          )),
          const SizedBox(width: 10),
          Expanded(
              child: _StatCard(
            icon: Icons.local_shipping_rounded,
            iconBg: const Color(0xFFFDF3D0),
            iconColor: const Color(0xFFE3A008),
            label: 'Deliveries',
            value: '$_deliveryCount',
          )),
          const SizedBox(width: 10),
          Expanded(
              child: _StatCard(
            icon: Icons.local_fire_department_rounded,
            iconBg: const Color(0xFFFDE8D8),
            iconColor: Colors.deepOrange,
            label: 'Gas Orders',
            value: '$_gasCount',
          )),
        ]),

        const SizedBox(height: 10),

        Row(children: [
          Expanded(
              child: _StatCard(
            icon: Icons.trending_up_rounded,
            iconBg: _C.successDim,
            iconColor: _C.success,
            label: 'Avg/Job',
            value: 'GH₵ ${_avgPerJob.toStringAsFixed(2)}',
          )),
          const SizedBox(width: 10),
          Expanded(
              child: _StatCard(
            icon: Icons.calendar_today_rounded,
            iconBg: _C.primaryDim,
            iconColor: _C.primary,
            label: 'Avg/Day',
            value: 'GH₵ ${_avgPerDay.toStringAsFixed(2)}',
          )),
          const SizedBox(width: 10),
          Expanded(
              child: _StatCard(
            icon: Icons.work_history_rounded,
            iconBg: _C.warningDim,
            iconColor: _C.warning,
            label: 'Active Days',
            value: '${records.length}',
          )),
        ]),

        const SizedBox(height: 20),

        // ── Performance ──
        _PerformanceCard(
          totalNet: totalNet,
          totalJobs: totalJobs,
          avgPerJob: _avgPerJob,
          period: period,
        ),

        const SizedBox(height: 20),

        // ── Job breakdown ──
        const _Label('Job Breakdown'),
        const SizedBox(height: 12),
        _BreakdownBar(
          trips: _tripCount,
          deliveries: _deliveryCount,
          gasOrders: _gasCount,
        ),

        // ── Projection (week only) ──
        if (period == 'week' && records.isNotEmpty) ...[
          const SizedBox(height: 20),
          _ProjectionCard(
            records: records,
            netSoFar: totalNet,
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _TodayCard extends StatelessWidget {
  final _DailyRecord? today;
  const _TodayCard({required this.today});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A56DB), Color(0xFF1E429F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A56DB).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Today's Net",
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              today != null
                  ? 'GH₵ ${today!.net.toStringAsFixed(2)}'
                  : 'GH₵ 0.00',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _HeroStat('Jobs', '${today?.totalJobs ?? 0}'),
                const SizedBox(width: 20),
                _HeroStat('Trips', '${today?.trips ?? 0}'),
                const SizedBox(width: 20),
                _HeroStat('Deliveries', '${today?.deliveries ?? 0}'),
                const SizedBox(width: 20),
                _HeroStat('Gas', '${today?.gasOrders ?? 0}'),
              ],
            ),
          ],
        ),
      );
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  const _HeroStat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ],
      );
}

class _BarChart extends StatelessWidget {
  final List<_DailyRecord> records;
  const _BarChart({required this.records});

  @override
  Widget build(BuildContext context) {
    final max = records.fold(0.0, (m, r) => r.net > m ? r.net : m);
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _C.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('Earnings Trend'),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: records.map((r) {
                final ratio = max > 0 ? r.net / max : 0.0;
                final isToday = DateFormat('yyyy-MM-dd').format(r.date) ==
                    DateFormat('yyyy-MM-dd').format(DateTime.now());
                final dayIdx = r.date.weekday - 1;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Amount label
                        Text(
                          r.net > 0 ? 'GH₵${r.net.toStringAsFixed(0)}' : '',
                          style: TextStyle(
                            fontSize: 8,
                            color: isToday ? _C.primary : _C.textTertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Bar
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: (ratio * 80).clamp(4, 80),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isToday
                                  ? [_C.primary, const Color(0xFF1E429F)]
                                  : [
                                      _C.primary.withValues(alpha: 0.4),
                                      _C.primary.withValues(alpha: 0.2),
                                    ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          days[dayIdx.clamp(0, 6)],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                isToday ? FontWeight.w800 : FontWeight.w400,
                            color: isToday ? _C.primary : _C.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakBanner extends StatelessWidget {
  final List<_DailyRecord> records;
  const _StreakBanner({required this.records});

  int get _streak {
    int s = 0;
    final now = DateTime.now();
    for (int i = 0; i < records.length; i++) {
      final r = records[records.length - 1 - i];
      final expected =
          DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      if (r.date.year == expected.year &&
          r.date.month == expected.month &&
          r.date.day == expected.day &&
          r.totalJobs > 0) {
        s++;
      } else {
        break;
      }
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final streak = _streak;
    if (streak < 2) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.warningDim,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _C.warning.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text('🔥', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$streak-Day Streak!',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _C.warning,
                    fontSize: 14,
                  ),
                ),
                const Text(
                  'Keep it up — consistency builds income.',
                  style: TextStyle(
                    fontSize: 12,
                    color: _C.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  final _DailyRecord record;
  final VoidCallback onTap;
  const _DayTile({required this.record, required this.onTap});

  bool get _isToday {
    final n = DateTime.now();
    return record.date.year == n.year &&
        record.date.month == n.month &&
        record.date.day == n.day;
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _isToday ? _C.primary.withValues(alpha: 0.06) : _C.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isToday ? _C.primary.withValues(alpha: 0.25) : _C.border,
            ),
            boxShadow: _C.cardShadow,
          ),
          child: Row(
            children: [
              // Date badge
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _isToday ? _C.primary : _C.primaryDim,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('EEE').format(record.date).toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _isToday ? Colors.white70 : _C.primary,
                      ),
                    ),
                    Text(
                      '${record.date.day}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _isToday ? Colors.white : _C.primary,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isToday
                          ? 'Today'
                          : DateFormat('EEEE, MMM d').format(record.date),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: _C.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${record.totalJobs} jobs · '
                      '${record.trips}T '
                      '${record.deliveries}D '
                      '${record.gasOrders}G',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _C.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Net earnings
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'GH₵ ${record.net.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _C.primary,
                    ),
                  ),
                  Text(
                    'Fee: GH₵ ${record.platformFee.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: _C.textTertiary,
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                  size: 16, color: _C.textTertiary),
            ],
          ),
        ),
      );
}

class _DetailSheet extends StatelessWidget {
  final _DailyRecord record;
  const _DetailSheet({required this.record});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: _C.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(record.date),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            _Row('Trips', '${record.trips}'),
            _Row('Deliveries', '${record.deliveries}'),
            _Row('Gas Orders', '${record.gasOrders}'),
            const Divider(height: 24),
            _Row('Gross', 'GH₵ ${record.gross.toStringAsFixed(2)}'),
            _Row('Platform Fee (15%)',
                'GH₵ ${record.platformFee.toStringAsFixed(2)}'),
            const Divider(height: 24),
            _Row('Net Earnings', 'GH₵ ${record.net.toStringAsFixed(2)}',
                bold: true),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(backgroundColor: _C.primary),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      );
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _Row(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                  fontSize: bold ? 15 : 13,
                  color: bold ? _C.textPrimary : _C.textSecondary,
                )),
            Text(value,
                style: TextStyle(
                  fontSize: bold ? 16 : 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: bold ? _C.primary : _C.textPrimary,
                )),
          ],
        ),
      );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _C.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: iconColor, size: 15),
            ),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _C.textPrimary,
                  height: 1,
                )),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 10, color: _C.textTertiary)),
          ],
        ),
      );
}

class _PerformanceCard extends StatelessWidget {
  final double totalNet;
  final int totalJobs;
  final double avgPerJob;
  final String period;

  const _PerformanceCard({
    required this.totalNet,
    required this.totalJobs,
    required this.avgPerJob,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    final targets = switch (period) {
      'month' => (net: 2000.0, jobs: 100, avg: 20.0),
      'year' => (net: 24000.0, jobs: 1200, avg: 20.0),
      _ => (net: 500.0, jobs: 25, avg: 20.0),
    };

    final score = ((totalNet >= targets.net
                ? 40
                : (totalNet / targets.net * 40)) +
            (totalJobs >= targets.jobs ? 30 : (totalJobs / targets.jobs * 30)) +
            (avgPerJob >= targets.avg ? 30 : (avgPerJob / targets.avg * 30)))
        .clamp(0, 100)
        .toInt();

    final scoreColor = score >= 70 ? _C.success : _C.warning;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _C.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _Label('Performance Score'),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$score%',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: scoreColor,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              backgroundColor: _C.border,
              valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Badge(
                label: 'Earnings',
                met: totalNet >= targets.net,
                target: 'GH₵ ${targets.net.toStringAsFixed(0)}',
              ),
              _Badge(
                label: 'Jobs',
                met: totalJobs >= targets.jobs,
                target: '${targets.jobs} jobs',
              ),
              _Badge(
                label: 'Avg/Job',
                met: avgPerJob >= targets.avg,
                target: 'GH₵ ${targets.avg.toStringAsFixed(0)}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final bool met;
  final String target;
  const _Badge({required this.label, required this.met, required this.target});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: met ? _C.successDim : _C.border,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 12,
              color: met ? _C.success : _C.textTertiary,
            ),
            const SizedBox(width: 5),
            Text(
              '$label ($target)',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: met ? _C.success : _C.textSecondary,
              ),
            ),
          ],
        ),
      );
}

class _BreakdownBar extends StatelessWidget {
  final int trips;
  final int deliveries;
  final int gasOrders;
  const _BreakdownBar({
    required this.trips,
    required this.deliveries,
    required this.gasOrders,
  });

  @override
  Widget build(BuildContext context) {
    final total = trips + deliveries + gasOrders;
    if (total == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _C.cardShadow,
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                if (trips > 0)
                  Flexible(
                    flex: trips,
                    child: Container(
                      height: 12,
                      color: _C.primary,
                    ),
                  ),
                if (deliveries > 0)
                  Flexible(
                    flex: deliveries,
                    child: Container(
                      height: 12,
                      color: _C.warning,
                    ),
                  ),
                if (gasOrders > 0)
                  Flexible(
                    flex: gasOrders,
                    child: Container(
                      height: 12,
                      color: Colors.deepOrange,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BreakdownLegend(
                  color: _C.primary,
                  label: 'Trips',
                  count: trips,
                  total: total),
              _BreakdownLegend(
                  color: _C.warning,
                  label: 'Deliveries',
                  count: deliveries,
                  total: total),
              _BreakdownLegend(
                  color: Colors.deepOrange,
                  label: 'Gas',
                  count: gasOrders,
                  total: total),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreakdownLegend extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final int total;
  const _BreakdownLegend({
    required this.color,
    required this.label,
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $count (${(count / total * 100).round()}%)',
            style: const TextStyle(fontSize: 11, color: _C.textSecondary),
          ),
        ],
      );
}

class _ProjectionCard extends StatelessWidget {
  final List<_DailyRecord> records;
  final double netSoFar;
  const _ProjectionCard({required this.records, required this.netSoFar});

  @override
  Widget build(BuildContext context) {
    final daysActive = records.length;
    final daysRemaining = (7 - daysActive).clamp(0, 7);
    if (daysRemaining == 0) return const SizedBox.shrink();

    final avgPerDay = daysActive > 0 ? netSoFar / daysActive : 0;
    final projected = netSoFar + (avgPerDay * daysRemaining);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.primaryDim,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _C.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.auto_graph_rounded,
                    color: _C.primary, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Week Projection',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _C.primary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ProjStat(
                'Projected',
                'GH₵ ${projected.toStringAsFixed(0)}',
              ),
              Container(
                  width: 1,
                  height: 36,
                  color: _C.primary.withValues(alpha: 0.2)),
              _ProjStat('Days Left', '$daysRemaining'),
              Container(
                  width: 1,
                  height: 36,
                  color: _C.primary.withValues(alpha: 0.2)),
              _ProjStat('Avg/Day', 'GH₵ ${avgPerDay.toStringAsFixed(0)}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProjStat extends StatelessWidget {
  final String label;
  final String value;
  const _ProjStat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _C.primary,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 10, color: _C.textSecondary)),
        ],
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: _C.textPrimary,
        ),
      );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _C.primaryDim,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  color: _C.primary, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('No earnings yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _C.textPrimary,
                )),
            const SizedBox(height: 6),
            const Text(
              'Complete your first trip,\ndelivery or gas order.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _C.textSecondary),
            ),
          ],
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE8E8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.cloud_off_rounded,
                    color: _C.error, size: 36),
              ),
              const SizedBox(height: 16),
              const Text('Could not load earnings',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _C.textPrimary,
                  )),
              const SizedBox(height: 8),
              Text(error,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 12, color: _C.textSecondary)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: FilledButton.styleFrom(backgroundColor: _C.primary),
              ),
            ],
          ),
        ),
      );
}

// lib/features/earnings/presentation/screens/earning_screen.dart
//
// Fixes vs original:
//
//  BUG 1 — EARNINGS NOT UPDATING (root cause)
//    Original used Future.wait + .get() — a one-shot read. Once the screen
//    loaded, no new data arrived regardless of completed trips.
//    Fix: three StreamSubscription listeners (.snapshots()). Any write to
//    trips/deliveries/gas_orders triggers _recompute() and setState immediately.
//
//  BUG 2 — WEEK START DATE MISSING MONDAY MORNING DATA
//    now.subtract(Duration(days: now.weekday - 1)) preserves the current
//    time-of-day. On Wednesday at 14:30, start = Monday at 14:30, so any
//    trip completed Monday before 14:30 is excluded by the Firestore >= query.
//    Fix: floor to midnight — DateTime(y, m, d) with no time args.
//
//  BUG 3 — HARDCODED FEE RATE IN _SummaryTab
//    _totalFee used 0.15 literal instead of the class constant.
//    Fix: pass feeRate down as a parameter so there is one source of truth.
//
//  BUG 4 — _today GETTER RE-CREATED DateFormat ON EVERY CALL
//    Minor perf issue; moved to a cached field.
//
//  IMPROVEMENT — Subscriptions are cancelled before re-subscribing on period
//    change, and in dispose(). Partial-load guard: _recompute() waits until
//    all three snapshots have arrived before updating UI, preventing a flash
//    of incomplete data.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../../app/app_theme.dart';
import '../../../../shared/widgets/finance_ui.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

/// One day's completed jobs. Net and fee are this screen's estimate (fares
/// less [_EarningsScreenState._platformFeeRate]), not a wallet figure.
class DailyEarningsRecord {
  final DateTime date;
  final int trips;
  final int deliveries;
  final int gasOrders;
  final double gross;
  final double platformFee;
  final double net;

  int get totalJobs => trips + deliveries + gasOrders;

  const DailyEarningsRecord({
    required this.date,
    required this.trips,
    required this.deliveries,
    required this.gasOrders,
    required this.gross,
    required this.platformFee,
    required this.net,
  });
}

/// 'This Week' / 'This Month' / 'This Year'.
String earningsPeriodLabel(String period) => switch (period) {
      'month' => 'This Month',
      'year' => 'This Year',
      _ => 'This Week',
    };

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

  // ── State ──────────────────────────────────────────────────────────────────
  List<DailyEarningsRecord> _records = [];
  bool _loading = true;
  String? _error;
  String _period = 'week'; // week | month | year

  static const double _platformFeeRate = 0.15;

  // ── FIX 1: StreamSubscriptions replace Future.wait + .get() ───────────────
  //
  // Three subscriptions — one per Firestore collection.
  // When any document in these collections changes (new trip completed,
  // fare updated, etc.) the corresponding snapshot updates, _recompute()
  // runs, and setState() pushes new data to the UI immediately.
  StreamSubscription<QuerySnapshot>? _tripSub;
  StreamSubscription<QuerySnapshot>? _deliverySub;
  StreamSubscription<QuerySnapshot>? _gasSub;

  // Latest raw snapshots — all three must be non-null before recomputing
  // to avoid a flash of partial data on the first load.
  QuerySnapshot? _tripSnap;
  QuerySnapshot? _deliverySnap;
  QuerySnapshot? _gasSnap;

  // ── FIX 4: Cache the date formatter ───────────────────────────────────────
  static final _dateKey = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _subscribe();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _cancelSubscriptions(); // ← always cancel, no leaks
    super.dispose();
  }

  // ── Subscription lifecycle ─────────────────────────────────────────────────

  void _cancelSubscriptions() {
    _tripSub?.cancel();
    _deliverySub?.cancel();
    _gasSub?.cancel();
    _tripSub = _deliverySub = _gasSub = null;
    // Reset snapshots so partial-load guard works on re-subscribe
    _tripSnap = _deliverySnap = _gasSnap = null;
  }

  void _subscribe() {
    _cancelSubscriptions();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _error = 'Not authenticated';
          _loading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final ts = Timestamp.fromDate(_startDate(DateTime.now()));

    // ── Trips ──────────────────────────────────────────────────────────────
    _tripSub = FirebaseFirestore.instance
        .collection('trips')
        .where('driverId', isEqualTo: uid)
        .where('status', isEqualTo: 'completed')
        .where('completedAt', isGreaterThanOrEqualTo: ts)
        .orderBy('completedAt')
        .snapshots()
        .listen(
      (snap) {
        _tripSnap = snap;
        _recompute();
      },
      onError: _onStreamError,
    );

    // ── Deliveries ─────────────────────────────────────────────────────────
    _deliverySub = FirebaseFirestore.instance
        .collection('deliveries')
        .where('driverId', isEqualTo: uid)
        .where('status', isEqualTo: 'completed')
        .where('completedAt', isGreaterThanOrEqualTo: ts)
        .orderBy('completedAt')
        .snapshots()
        .listen(
      (snap) {
        _deliverySnap = snap;
        _recompute();
      },
      onError: _onStreamError,
    );

    // ── Gas orders ─────────────────────────────────────────────────────────
    _gasSub = FirebaseFirestore.instance
        .collection('gas_orders')
        .where('driverId', isEqualTo: uid)
        .where('status', isEqualTo: 'delivered')
        .where('deliveredAt', isGreaterThanOrEqualTo: ts)
        .orderBy('deliveredAt')
        .snapshots()
        .listen(
      (snap) {
        _gasSnap = snap;
        _recompute();
      },
      onError: _onStreamError,
    );
  }

  void _onStreamError(Object e) {
    if (mounted) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ── Recompute ──────────────────────────────────────────────────────────────
  //
  // Called by every stream listener. Waits until all three snapshots have
  // arrived before updating state, preventing a flash of partial data.

  void _recompute() {
    if (!mounted) return;

    // Partial-load guard — all three collections must have responded
    final tripSnap = _tripSnap;
    final deliverySnap = _deliverySnap;
    final gasSnap = _gasSnap;
    if (tripSnap == null || deliverySnap == null || gasSnap == null) return;

    try {
      final now = DateTime.now();
      final byDate = <String, Map<String, dynamic>>{};

      void addEntry(QueryDocumentSnapshot doc, String type) {
        final d = doc.data() as Map<String, dynamic>;
        final tsField = type == 'gas' ? 'deliveredAt' : 'completedAt';
        final date = (d[tsField] as Timestamp?)?.toDate() ?? now;
        final key = _dateKey.format(date);

        final num fare = type == 'trip'
            ? (d['finalFare'] ?? d['estimatedFare'] ?? 0) as num
            : (d['actualFare'] ??
                (type == 'delivery' ? d['estimatedFare'] : d['totalPrice']) ??
                0) as num;

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

      final records = byDate.entries.map((e) {
        final gross = e.value['gross'] as double;
        final fee = gross * _platformFeeRate;
        return DailyEarningsRecord(
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

      setState(() {
        _records = records;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ── FIX 2: Week start is floored to midnight ───────────────────────────────
  //
  // Original: now.subtract(Duration(days: now.weekday - 1))
  //   → preserves time-of-day, e.g. Wednesday 14:30 → Monday 14:30.
  //   Any trip completed Monday before 14:30 is excluded.
  //
  // Fixed: DateTime(y, m, d) with no time args → midnight (00:00:00.000).

  DateTime _startDate(DateTime now) {
    switch (_period) {
      case 'month':
        return DateTime(now.year, now.month, 1);
      case 'year':
        return DateTime(now.year, 1, 1);
      default: // week — Monday at midnight
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(monday.year, monday.month, monday.day);
    }
  }

  // ── Computed ───────────────────────────────────────────────────────────────

  double get _totalNet => _records.fold(0, (s, r) => s + r.net);
  double get _totalGross => _records.fold(0, (s, r) => s + r.gross);
  int get _totalJobs => _records.fold(0, (s, r) => s + r.totalJobs);

  // FIX 4: _today no longer rebuilds a DateFormat on every call
  DailyEarningsRecord? get _today {
    final key = _dateKey.format(DateTime.now());
    try {
      return _records.firstWhere((r) => _dateKey.format(r.date) == key);
    } catch (_) {
      return null;
    }
  }

  // ── Export (unchanged) ─────────────────────────────────────────────────────

  Future<void> _export() async {
    final buf = StringBuffer();
    buf.writeln('CTS Go Driver — Earnings Report');
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

  void _selectPeriod(String v) {
    if (v == _period) return;
    setState(() => _period = v);
    _subscribe(); // re-subscribe with new date range
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Earnings'),
        backgroundColor: AppTheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Copy report (CSV)',
            onPressed: _records.isEmpty ? null : _export,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.primaryDark,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          dividerColor: AppTheme.divider,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          tabs: const [
            Tab(text: 'Daily'),
            Tab(text: 'Summary'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
            child: EarningsPeriodSelector(
              period: _period,
              onChanged: _selectPeriod,
            ),
          ),
          Expanded(
            child: _loading
                ? const FinanceLoadingView(label: 'Loading earnings…')
                : _error != null
                    ? FinanceStateView(
                        icon: Icons.cloud_off_rounded,
                        title: 'Could not load earnings',
                        message: _error == 'Not authenticated'
                            ? 'Sign in again to see your earnings.'
                            : 'Check your connection and try again.',
                        detail:
                            _error == 'Not authenticated' ? null : _error,
                        isError: true,
                        onRetry: _subscribe,
                      )
                    : RefreshIndicator(
                        color: AppTheme.primaryDark,
                        // Pull-to-refresh re-subscribes (re-creates queries with
                        // fresh start date) — useful for forced refresh
                        onRefresh: () async => _subscribe(),
                        child: TabBarView(
                          controller: _tabs,
                          children: [
                            EarningsDailyView(
                              records: _records,
                              today: _today,
                              period: _period,
                              feeRate: _platformFeeRate,
                            ),
                            // FIX 3: pass feeRate instead of hardcoding 0.15 again
                            EarningsSummaryView(
                              records: _records,
                              totalNet: _totalNet,
                              totalGross: _totalGross,
                              totalJobs: _totalJobs,
                              period: _period,
                              feeRate: _platformFeeRate,
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PERIOD SELECTOR
// ─────────────────────────────────────────────────────────────────────────────

class EarningsPeriodSelector extends StatelessWidget {
  final String period;
  final ValueChanged<String> onChanged;

  const EarningsPeriodSelector({
    super.key,
    required this.period,
    required this.onChanged,
  });

  static const periods = [
    ('week', 'This Week'),
    ('month', 'This Month'),
    ('year', 'This Year'),
  ];

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            for (final (value, label) in periods)
              Expanded(
                child: Semantics(
                  selected: value == period,
                  button: true,
                  child: Material(
                    color: value == period
                        ? AppTheme.primaryDark
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      key: ValueKey('earnings-period-$value'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onChanged(value),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: value == period
                                      ? AppTheme.onPrimary
                                      : AppTheme.textSecondary,
                                )),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// DAILY TAB
// ─────────────────────────────────────────────────────────────────────────────

class EarningsDailyView extends StatelessWidget {
  final List<DailyEarningsRecord> records;
  final DailyEarningsRecord? today;
  final String period;
  final double feeRate;

  const EarningsDailyView({
    super.key,
    required this.records,
    required this.today,
    required this.period,
    required this.feeRate,
  });

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return _EarningsEmpty(period: period);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        EarningsTodayCard(today: today, feeRate: feeRate),
        const SizedBox(height: 16),
        EarningsTrendChart(records: records, period: period),
        _StreakBanner(records: records),
        const SizedBox(height: 20),
        const FinanceSectionLabel('Daily breakdown'),
        const SizedBox(height: 12),
        ...records.reversed.map((r) => EarningsDayTile(
            record: r, onTap: () => _showDetail(context, r))),
      ],
    );
  }

  void _showDetail(BuildContext context, DailyEarningsRecord r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85),
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => EarningsDayDetail(record: r, feeRate: feeRate),
    );
  }
}

String _feeNote(double feeRate) =>
    'Estimated from completed job fares, less the '
    '${(feeRate * 100).round()}% platform fee. Your withdrawable balance '
    'is in Wallet.';

class EarningsTodayCard extends StatelessWidget {
  final DailyEarningsRecord? today;
  final double feeRate;
  const EarningsTodayCard(
      {super.key, required this.today, required this.feeRate});

  @override
  Widget build(BuildContext context) => FinanceHeroCard(
        key: const ValueKey('earnings-today-card'),
        label: "Today's net earnings",
        amount: formatGhs(today?.net ?? 0),
        caption: _feeNote(feeRate),
        stats: [
          FinanceHeroStat('Jobs', '${today?.totalJobs ?? 0}'),
          FinanceHeroStat('Trips', '${today?.trips ?? 0}'),
          FinanceHeroStat('Deliveries', '${today?.deliveries ?? 0}'),
          FinanceHeroStat('Gas', '${today?.gasOrders ?? 0}'),
        ],
      );
}

/// Net per day. Up to a week fits the card; longer periods scroll
/// sideways, opening on the most recent day.
class EarningsTrendChart extends StatelessWidget {
  final List<DailyEarningsRecord> records;
  final String period;
  const EarningsTrendChart(
      {super.key, required this.records, required this.period});

  static final _fmt = DateFormat('yyyy-MM-dd');
  static const _barArea = 84.0;

  @override
  Widget build(BuildContext context) {
    final max = records.fold(0.0, (m, r) => r.net > m ? r.net : m);
    final todayKey = _fmt.format(DateTime.now());
    final fits = records.length <= 7;

    Widget bar(DailyEarningsRecord r) {
      final ratio = max > 0 ? r.net / max : 0.0;
      final isToday = _fmt.format(r.date) == todayKey;
      final label = period == 'week'
          ? DateFormat('E').format(r.date)
          : DateFormat('d MMM').format(r.date);
      return Semantics(
        label: '$label, ${formatGhs(r.net)}',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  r.net > 0 ? r.net.toStringAsFixed(0) : '',
                  style: TextStyle(
                    fontSize: 11,
                    color: isToday
                        ? AppTheme.primaryDark
                        : AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                height: (ratio * _barArea).clamp(4, _barArea),
                decoration: BoxDecoration(
                  gradient: isToday
                      ? const LinearGradient(
                          colors: [AppTheme.primaryDark, AppTheme.primary],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        )
                      : null,
                  color: isToday
                      ? null
                      : AppTheme.primary.withValues(alpha: 0.35),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                    color: isToday
                        ? AppTheme.primaryDark
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FinanceCard(
      key: const ValueKey('earnings-trend-chart'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FinanceSectionLabel('Net per day'),
          const SizedBox(height: 4),
          const Text('GH₵, estimated',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 14),
          SizedBox(
            height: _barArea + 44,
            child: fits
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final r in records) Expanded(child: bar(r)),
                    ],
                  )
                : ListView(
                    scrollDirection: Axis.horizontal,
                    reverse: true, // newest at the right, shown first
                    children: [
                      for (final r in records.reversed)
                        SizedBox(width: 48, child: bar(r)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _StreakBanner extends StatelessWidget {
  final List<DailyEarningsRecord> records;
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

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: FinanceCard(
        color: AppTheme.warningLight,
        borderColor: AppTheme.warning.withValues(alpha: 0.3),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.local_fire_department_rounded,
                color: AppTheme.warningText, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$streak-day streak',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.warningText,
                          fontSize: 15)),
                  const SizedBox(height: 2),
                  const Text('Keep it up — consistency builds income.',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.warningText)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EarningsDayTile extends StatelessWidget {
  final DailyEarningsRecord record;
  final VoidCallback onTap;
  const EarningsDayTile({super.key, required this.record, required this.onTap});

  bool get _isToday {
    final n = DateTime.now();
    return record.date.year == n.year &&
        record.date.month == n.month &&
        record.date.day == n.day;
  }

  @override
  Widget build(BuildContext context) {
    final counts = [
      if (record.trips > 0)
        (ServiceTone.ride, '${record.trips} ${record.trips == 1 ? 'trip' : 'trips'}'),
      if (record.deliveries > 0)
        (
          ServiceTone.delivery,
          '${record.deliveries} ${record.deliveries == 1 ? 'delivery' : 'deliveries'}'
        ),
      if (record.gasOrders > 0)
        (ServiceTone.gas, '${record.gasOrders} gas'),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FinanceCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        color: _isToday ? AppTheme.primaryLight : null,
        borderColor:
            _isToday ? AppTheme.primary.withValues(alpha: 0.35) : null,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isToday ? AppTheme.primaryDark : AppTheme.primarySubtle,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('EEE').format(record.date).toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _isToday ? Colors.white : AppTheme.primaryDeep,
                      ),
                    ),
                    Text(
                      '${record.date.day}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _isToday ? Colors.white : AppTheme.primaryDeep,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FinanceTitleAmountRow(
                    amountShare: 0.5,
                    title: Text(
                      _isToday
                          ? 'Today'
                          : DateFormat('EEEE, MMM d').format(record.date),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.textPrimary),
                    ),
                    amount: Text(
                      formatGhs(record.net),
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryDark),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    runSpacing: 2,
                    children: [
                      for (final (tone, text) in counts)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(serviceStyle(tone).icon,
                              size: 13, color: serviceStyle(tone).fg),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(text,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary)),
                          ),
                        ]),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Fee ${formatGhs(record.platformFee)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

class EarningsDayDetail extends StatelessWidget {
  final DailyEarningsRecord record;
  final double feeRate;
  const EarningsDayDetail(
      {super.key, required this.record, required this.feeRate});

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppTheme.divider,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                DateFormat('EEEE, MMMM d, yyyy').format(record.date),
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 14),
              FinanceRow('Trips', '${record.trips}'),
              FinanceRow('Deliveries', '${record.deliveries}'),
              FinanceRow('Gas orders', '${record.gasOrders}'),
              const Divider(height: 24, color: AppTheme.divider),
              FinanceRow('Gross fares', formatGhs(record.gross)),
              FinanceRow('Platform fee (${(feeRate * 100).round()}%)',
                  '− ${formatGhs(record.platformFee)}'),
              const Divider(height: 24, color: AppTheme.divider),
              FinanceRow('Net earnings', formatGhs(record.net),
                  emphasis: true),
              const SizedBox(height: 10),
              FinanceNote(_feeNote(feeRate)),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SUMMARY TAB  — feeRate is now a parameter, not a hardcoded literal
// ─────────────────────────────────────────────────────────────────────────────

class EarningsSummaryView extends StatelessWidget {
  final List<DailyEarningsRecord> records;
  final double totalNet;
  final double totalGross;
  final int totalJobs;
  final String period;
  final double feeRate; // FIX 3: single source of truth

  const EarningsSummaryView({
    super.key,
    required this.records,
    required this.totalNet,
    required this.totalGross,
    required this.totalJobs,
    required this.period,
    required this.feeRate,
  });

  int get _tripCount => records.fold(0, (s, r) => s + r.trips);
  int get _deliveryCount => records.fold(0, (s, r) => s + r.deliveries);
  int get _gasCount => records.fold(0, (s, r) => s + r.gasOrders);
  double get _avgPerJob => totalJobs > 0 ? totalNet / totalJobs : 0;
  double get _avgPerDay => records.isNotEmpty ? totalNet / records.length : 0;
  double get _totalFee => totalGross * feeRate; // was hardcoded 0.15

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return _EarningsEmpty(period: period);

    final ride = serviceStyle(ServiceTone.ride);
    final delivery = serviceStyle(ServiceTone.delivery);
    final gas = serviceStyle(ServiceTone.gas);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        FinanceHeroCard(
          key: const ValueKey('earnings-period-card'),
          label: '${earningsPeriodLabel(period)} · net earnings',
          amount: formatGhs(totalNet),
          caption: _feeNote(feeRate),
          stats: [
            FinanceHeroStat('Jobs', '$totalJobs'),
            FinanceHeroStat('Gross', formatGhs(totalGross)),
            FinanceHeroStat('Fee', formatGhs(_totalFee)),
          ],
        ),

        const SizedBox(height: 16),

        // ── Stats grid ──
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: FinanceStatTile(
            icon: ride.icon,
            iconBg: ride.bg,
            iconColor: ride.fg,
            label: 'Trips',
            value: '$_tripCount',
          )),
          const SizedBox(width: 10),
          Expanded(
              child: FinanceStatTile(
            icon: delivery.icon,
            iconBg: delivery.bg,
            iconColor: delivery.fg,
            label: 'Deliveries',
            value: '$_deliveryCount',
          )),
          const SizedBox(width: 10),
          Expanded(
              child: FinanceStatTile(
            icon: gas.icon,
            iconBg: gas.bg,
            iconColor: gas.fg,
            label: 'Gas orders',
            value: '$_gasCount',
          )),
        ]),

        const SizedBox(height: 10),

        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: FinanceStatTile(
            icon: Icons.trending_up_rounded,
            iconBg: AppTheme.primarySubtle,
            iconColor: AppTheme.primaryDark,
            label: 'Avg / job',
            value: formatGhs(_avgPerJob),
          )),
          const SizedBox(width: 10),
          Expanded(
              child: FinanceStatTile(
            icon: Icons.calendar_today_rounded,
            iconBg: AppTheme.primarySubtle,
            iconColor: AppTheme.primaryDark,
            label: 'Avg / active day',
            value: formatGhs(_avgPerDay),
          )),
          const SizedBox(width: 10),
          Expanded(
              child: FinanceStatTile(
            icon: Icons.work_history_rounded,
            iconBg: AppTheme.warningLight,
            iconColor: AppTheme.warningText,
            label: 'Active days',
            value: '${records.length}',
          )),
        ]),

        const SizedBox(height: 16),

        _PerformanceCard(
          totalNet: totalNet,
          totalJobs: totalJobs,
          avgPerJob: _avgPerJob,
          period: period,
        ),

        const SizedBox(height: 20),

        const FinanceSectionLabel('Job breakdown'),
        const SizedBox(height: 12),
        _BreakdownBar(
          trips: _tripCount,
          deliveries: _deliveryCount,
          gasOrders: _gasCount,
        ),

        if (period == 'week' && records.isNotEmpty)
          _ProjectionCard(records: records, netSoFar: totalNet),
      ],
    );
  }
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

    final tone = score >= 70 ? StatusTone.success : StatusTone.pending;

    return FinanceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FinanceSectionLabel('Performance score',
              trailing: StatusPill(label: '$score%', tone: tone)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              backgroundColor: AppTheme.divider,
              valueColor: AlwaysStoppedAnimation<Color>(
                  score >= 70 ? AppTheme.primary : AppTheme.warning),
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
                  target: formatGhs(targets.net)),
              _Badge(
                  label: 'Jobs',
                  met: totalJobs >= targets.jobs,
                  target: '${targets.jobs} jobs'),
              _Badge(
                  label: 'Avg / job',
                  met: avgPerJob >= targets.avg,
                  target: formatGhs(targets.avg)),
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
  Widget build(BuildContext context) {
    final c = statusColors(met ? StatusTone.success : StatusTone.neutral);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(20),
        border: met ? null : Border.all(color: AppTheme.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 14,
            color: c.fg,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text('$label ($target)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.fg,
                )),
          ),
        ],
      ),
    );
  }
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

    final ride = serviceStyle(ServiceTone.ride).fg;
    final delivery = serviceStyle(ServiceTone.delivery).fg;
    final gas = serviceStyle(ServiceTone.gas).fg;

    return FinanceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                if (trips > 0)
                  Flexible(
                      flex: trips,
                      child: Container(height: 12, color: ride)),
                if (deliveries > 0)
                  Flexible(
                      flex: deliveries,
                      child: Container(height: 12, color: delivery)),
                if (gasOrders > 0)
                  Flexible(
                      flex: gasOrders,
                      child: Container(height: 12, color: gas)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _BreakdownLegend(
                  color: ride, label: 'Trips', count: trips, total: total),
              _BreakdownLegend(
                  color: delivery,
                  label: 'Deliveries',
                  count: deliveries,
                  total: total),
              _BreakdownLegend(
                  color: gas, label: 'Gas', count: gasOrders, total: total),
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
          Flexible(
            child: Text(
              '$label: $count (${(count / total * 100).round()}%)',
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
        ],
      );
}

class _ProjectionCard extends StatelessWidget {
  final List<DailyEarningsRecord> records;
  final double netSoFar;
  const _ProjectionCard({required this.records, required this.netSoFar});

  @override
  Widget build(BuildContext context) {
    final daysActive = records.length;
    final daysRemaining = (7 - daysActive).clamp(0, 7);
    if (daysRemaining == 0) return const SizedBox.shrink();

    final avgPerDay = daysActive > 0 ? netSoFar / daysActive : 0;
    final projected = netSoFar + (avgPerDay * daysRemaining);

    Widget stat(String label, String value) => Expanded(
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryDeep)),
              ),
              const SizedBox(height: 2),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.primaryDeep)),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: FinanceCard(
        color: AppTheme.primarySubtle,
        borderColor: AppTheme.primary.withValues(alpha: 0.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_graph_rounded,
                    color: AppTheme.primaryDeep, size: 20),
                SizedBox(width: 8),
                Text('Week projection',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryDeep,
                        fontSize: 15)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                stat('Projected', formatGhs(projected)),
                stat('Days left', '$daysRemaining'),
                stat('Avg / day', formatGhs(avgPerDay)),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
                'An estimate at your current daily average, not a guarantee.',
                style: TextStyle(fontSize: 12, color: AppTheme.primaryDeep)),
          ],
        ),
      ),
    );
  }
}

class _EarningsEmpty extends StatelessWidget {
  final String period;
  const _EarningsEmpty({required this.period});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        // Scrollable so pull-to-refresh still works when empty.
        builder: (_, c) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: FinanceStateView(
              icon: Icons.account_balance_wallet_rounded,
              title: 'No earnings ${earningsPeriodLabel(period).toLowerCase()}',
              message: 'Completed trips, deliveries and gas orders '
                  'will appear here.',
            ),
          ),
        ),
      );
}

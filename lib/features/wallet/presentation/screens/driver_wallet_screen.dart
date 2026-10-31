import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/app_theme.dart';
import '../../../../shared/widgets/finance_ui.dart';

// ── Driver transaction categories ─────────────────────────────────────────────
//
//  Every document in /transactions that belongs to a driver MUST have:
//    • driverId  : String   (driver's UID)          ← was missing; used to be userId
//    • category  : String   (see _kTxCategory* consts below)
//    • type      : 'credit' | 'debit'
//    • amount    : num
//    • status    : 'completed' | 'pending' | 'failed'
//    • createdAt : Timestamp
//    • description : String  (human-readable label)
//
//  Optional fields:
//    • rideId    : String   (for trip_earning / commission)
//    • method    : String   (for withdrawal: 'MTN MoMo' etc.)
//    • phoneNumber: String  (for withdrawal)
//
const _kCatTripEarning = 'trip_earning'; // credit  – driver's cut of a fare
const _kCatWithdrawal = 'withdrawal'; // debit   – payout to mobile money
const _kCatBonus = 'bonus'; // credit  – promo / incentive
const _kCatCommission = 'commission'; // debit   – platform fee deducted
const _kCatPenalty = 'penalty'; // debit   – cancellation / violation
const _kCatReferral = 'referral'; // credit  – referral reward

/// Smallest withdrawal the sheet accepts (checked before calling the server).
const kMinWithdrawalGhs = 10.0;

/// Shown once the payout request is accepted: a request, not a payment.
String withdrawalRequestedMessage(double amount, String phone) =>
    'Withdrawal of GH₵ ${amount.toStringAsFixed(2)} requested. It shows as '
    'Pending until the payment to $phone is confirmed.';

// ── Screen ─────────────────────────────────────────────────────────────────────
class DriverWalletScreen extends StatefulWidget {
  const DriverWalletScreen({super.key});

  @override
  State<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends State<DriverWalletScreen>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  final _fns = FirebaseFunctions.instanceFor(region: 'europe-west2');
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Streams ──────────────────────────────────────────────────────────────
  //  REMOVED: _walletSub (was duplicate of _driverSub, both hit drivers/{uid})
  StreamSubscription<DocumentSnapshot>? _earningsSub;
  StreamSubscription<DocumentSnapshot>? _driverSub;
  StreamSubscription<QuerySnapshot>? _txSub;
  StreamSubscription<User?>? _authSub;

  // ── Data ─────────────────────────────────────────────────────────────────
  /// Withdrawable balance stored on drivers/{uid}.walletBalance.
  /// This is distinct from totalEarnings (lifetime counter, never decremented).
  double _walletBalance = 0;

  double _todayEarnings = 0;
  double _weekEarnings = 0;
  double _totalEarnings = 0; // lifetime, from drivers/{uid}.totalEarnings
  int _completedTrips = 0;

  /// FIX: only driver-specific transactions (queried by driverId).
  List<Map<String, dynamic>> _txList = [];

  // ── Loading ───────────────────────────────────────────────────────────────
  bool _loadingDriver = true;
  bool _loadingEarnings = true;
  bool _loadingTx = true;

  // A failed stream shows an error with Try again, never a zero amount.
  bool _driverError = false;
  bool _earningsError = false;
  bool _txError = false;

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      // Cancel old listeners
      _driverSub?.cancel();
      _earningsSub?.cancel();
      _txSub?.cancel();

      if (user == null) {
        return;
      }

      // Re-subscribe for the new authenticated user
      _subscribeAll();
    });

    if (_uid.isNotEmpty) {
      _subscribeAll();
    }
  }

  void _subscribeAll() {
    _subscribeDriver();
    _subscribeEarnings();
    _subscribeTx();
  }

  // ── drivers/{uid} – balance + trip counters ───────────────────────────────

  //
  void _subscribeDriver() {
    _driverSub?.cancel();
    _driverSub = _db.collection('drivers').doc(_uid).snapshots().listen((doc) {
      if (!mounted) return;
      final d = doc.data() ?? {};
      setState(() {
        // walletBalance is the correct withdrawable field.
        // totalEarnings is the lifetime counter – kept for the earnings card.
        _walletBalance = (d['walletBalance'] as num?)?.toDouble() ?? 0;

        _completedTrips = (d['completedTrips'] as num?)?.toInt() ?? 0;
        _loadingDriver = false;
        _driverError = false;
      });
    }, onError: (_) {
      if (mounted) {
        setState(() {
          _loadingDriver = false;
          _driverError = true;
        });
      }
    });
  }

  // ── drivers/{uid}/earnings/summary – richer period breakdown ─────────────
  //
  //  Expected Firestore fields:
  //    todayEarnings    : num
  //    weekEarnings     : num
  //    lifetimeEarnings : num  (mirrors drivers/{uid}.totalEarnings)
  //
  void _subscribeEarnings() {
    _earningsSub?.cancel();
    _earningsSub = _db
        .collection('drivers')
        .doc(_uid)
        .collection('earnings')
        .doc('summary')
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      final d = doc.data() ?? {};
      setState(() {
        _todayEarnings =
            (d['todayEarnings'] as num?)?.toDouble() ?? _todayEarnings;
        _weekEarnings = (d['weekEarnings'] as num?)?.toDouble() ?? 0;
        _totalEarnings =
            (d['lifetimeEarnings'] as num?)?.toDouble() ?? _totalEarnings;
        _totalEarnings = (d['totalEarnings'] as num?)?.toDouble() ?? 0;
        _loadingEarnings = false;
        _earningsError = false;
      });
    }, onError: (_) {
      if (mounted) {
        setState(() {
          _loadingEarnings = false;
          _earningsError = true;
        });
      }
    });
  }

  // ── Driver transactions ───────────────────────────────────────────────────
  //
  //  FIX: query by 'driverId' NOT 'userId'.
  //
  //  'userId' → passenger wallet transactions (top-ups, ride payments)
  //  'driverId' → driver earnings, withdrawals, bonuses, commissions
  //
  //  Required Firestore composite index:
  //    Collection : transactions
  //    Fields     : driverId ASC, createdAt DESC
  //
  void _subscribeTx() {
    _txSub?.cancel();
    _txSub = _db
        .collection('transactions')
        .where('userId', isEqualTo: _uid) // ← THE FIX
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _txList = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _loadingTx = false;
        _txError = false;
      });
    }, onError: (e) {
      // If index is missing Firestore throws a permission / index error.
      // Surface it so the developer can create the composite index.
      debugPrint('[DriverWallet] _subscribeTx error: $e');
      if (mounted) {
        setState(() {
          _loadingTx = false;
          _txError = true;
        });
      }
    });
  }

  // ── Refresh ───────────────────────────────────────────────────────────────
  Future<void> _refresh() async {
    // Re-subscribe to all three streams — forces fresh data from Firestore
    if (mounted) {
      _subscribeDriver(); // triggers _walletBalance rebuild
      _subscribeEarnings();
      _subscribeTx();
    }
  }

  // ── Withdrawal ────────────────────────────────────────────────────────────
  //
  //  The Cloud Function 'requestWithdrawal' is responsible for:
  //    1. Validating amount ≤ drivers/{uid}.walletBalance
  //    2. Decrementing drivers/{uid}.walletBalance
  //    3. Writing a /transactions doc with category='withdrawal', type='debit',
  //       driverId=uid  (NOT userId)
  //
  // FIND and REPLACE the entire _requestWithdrawal method:
  Future<void> _requestWithdrawal({
    required double amount,
    required String method,
    required String phone,
  }) async {
    // Map UI label → Bridge network code
    const networkMap = {
      'MTN MoMo': 'MTN',
      'Telecel Cash': 'TELECEL',
      'AirtelTigo Money': 'AIRTELTIGO',
    };

    final bridgeNetwork = networkMap[method];
    if (bridgeNetwork == null) {
      _snack('Please select a valid MoMo network', isError: true);
      return;
    }

    // Validate Ghana phone number format
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10 || !digits.startsWith('0')) {
      _snack('Enter a valid 10-digit Ghana mobile number', isError: true);
      return;
    }

    try {
      final result = await _fns.httpsCallable('initiateBridgePayout').call({
        'amount': amount,
        'phone': digits,
        'network': bridgeNetwork,
      });

      if (!mounted) return;

      if (result.data['success'] == true) {
        Navigator.pop(context);
        // initiateBridgePayout sends the payout to Bridge at once and returns
        // { success, transactionId } once Bridge accepts it; the result is
        // confirmed later, so this confirms the request, not a payment.
        _snack(
          (result.data['message'] as String?) ??
              withdrawalRequestedMessage(amount, phone),
          isSuccess: true,
        );
      } else {
        _snack(result.data['message'] ?? 'Withdrawal failed', isError: true);
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) _snack(e.message ?? 'Withdrawal failed', isError: true);
    } catch (_) {
      if (mounted) _snack('Something went wrong. Try again.', isError: true);
    }
  }

  void _snack(String msg, {bool isSuccess = false, bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess
            ? AppTheme.primaryDark
            : isError
                ? AppTheme.danger
                : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
  }

  // ── Withdraw sheet ────────────────────────────────────────────────────────
  void _showWithdrawSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WithdrawSheet(
        balance: _walletBalance,
        onInvalid: (msg) => _snack(msg, isError: true),
        onSubmit: (amount, method, phone) =>
            _requestWithdrawal(amount: amount, method: method, phone: phone),
      ),
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();

    _driverSub?.cancel();
    _earningsSub?.cancel();
    _txSub?.cancel();

    _tabController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Wallet & Earnings'),
        backgroundColor: AppTheme.surface,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryDark,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          dividerColor: AppTheme.divider,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          tabs: const [Tab(text: 'Overview'), Tab(text: 'Transactions')],
        ),
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryDark,
        onRefresh: _refresh,
        child: TabBarView(
          controller: _tabController,
          children: [_buildOverviewTab(), _buildTransactionsTab()],
        ),
      ),
    );
  }

  // ── Overview tab ──────────────────────────────────────────────────────────
  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        WalletBalanceCard(
          balance: _walletBalance,
          loading: _loadingDriver,
          error: _driverError,
          onWithdraw: _showWithdrawSheet,
          onRetry: _refresh,
        ),
        const SizedBox(height: 16),
        WalletEarningsCard(
          todayEarnings: _todayEarnings,
          weekEarnings: _weekEarnings,
          totalEarnings: _totalEarnings,
          completedTrips: _completedTrips,
          loading: _loadingEarnings || _loadingDriver,
          error: _earningsError,
        ),
        const SizedBox(height: 16),
        // FIX: QuickStats now receives driver-only txList (driverId-queried)
        if (!_loadingTx && !_txError) WalletQuickStats(txList: _txList),
      ],
    );
  }

  // ── Transactions tab ──────────────────────────────────────────────────────
  Widget _buildTransactionsTab() {
    if (_loadingTx) {
      return const FinanceLoadingView(label: 'Loading transactions…');
    }
    if (_txError) {
      return _scrollable(FinanceStateView(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load transactions',
        message: 'Check your connection and try again.',
        isError: true,
        onRetry: _refresh,
      ));
    }
    if (_txList.isEmpty) {
      return _scrollable(const FinanceStateView(
        icon: Icons.receipt_long_rounded,
        title: 'No transactions yet',
        message: 'Your earnings and withdrawals will appear here.',
      ));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: _txList.length,
      itemBuilder: (_, i) => WalletTransactionTile(tx: _txList[i]),
    );
  }

  /// Keeps pull-to-refresh working on the empty and error views.
  Widget _scrollable(Widget child) => LayoutBuilder(
        builder: (_, c) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: child,
          ),
        ),
      );
}

// ── Wallet card ────────────────────────────────────────────────────────────────
class WalletBalanceCard extends StatelessWidget {
  final double balance;
  final bool loading;
  final bool error;
  final VoidCallback onWithdraw;
  final VoidCallback onRetry;

  const WalletBalanceCard({
    super.key,
    required this.balance,
    required this.loading,
    required this.error,
    required this.onWithdraw,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // The balance is unknown while loading or after an error, so Withdraw
    // waits for it.
    final ready = !loading && !error;
    return FinanceHeroCard(
      key: const ValueKey('wallet-balance-card'),
      label: 'Wallet balance',
      amount: error ? 'Unavailable' : formatGhs(balance),
      loading: loading,
      caption: error
          ? 'We could not load your balance. Pull down or tap Try again.'
          : 'Available for withdrawal · minimum '
              '${formatGhs(kMinWithdrawalGhs)} per request',
      footer: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          key: const ValueKey('wallet-withdraw'),
          onPressed: error ? onRetry : (ready ? onWithdraw : null),
          icon: Icon(error ? Icons.refresh_rounded : Icons.arrow_upward_rounded,
              size: 18),
          label: Text(error ? 'Try again' : 'Withdraw funds'),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.primaryDeep,
            disabledBackgroundColor: Colors.white.withValues(alpha: 0.6),
            disabledForegroundColor: AppTheme.textSecondary,
            side: BorderSide.none,
            minimumSize: const Size.fromHeight(48),
            textStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }
}

// ── Earnings card ──────────────────────────────────────────────────────────────
class WalletEarningsCard extends StatelessWidget {
  final double todayEarnings;
  final double weekEarnings;
  final double totalEarnings;
  final int completedTrips;
  final bool loading;
  final bool error;

  const WalletEarningsCard({
    super.key,
    required this.todayEarnings,
    required this.weekEarnings,
    required this.totalEarnings,
    required this.completedTrips,
    required this.loading,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) => FinanceCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primarySubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.trending_up_rounded,
                    color: AppTheme.primaryDark, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(child: FinanceSectionLabel('Earnings')),
            ]),
            const SizedBox(height: 10),
            if (error)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: FinanceNote('Earnings could not be loaded. '
                    'Pull down to refresh.',
                    icon: Icons.cloud_off_rounded),
              )
            else ...[
              _row('Today', todayEarnings),
              _row('This week', weekEarnings),
              _row('All time', totalEarnings),
            ],
            const Divider(height: 20, color: AppTheme.divider),
            Row(children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.primaryDark, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    loading ? 'Loading trips…' : '$completedTrips trips completed',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    )),
              ),
            ]),
          ],
        ),
      );

  Widget _row(String label, double value) => loading
      ? Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 14, color: AppTheme.textSecondary))),
            Container(
              width: 80,
              height: 16,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ]),
        )
      : FinanceRow(label, formatGhs(value));
}

// ── Quick stats ────────────────────────────────────────────────────────────────
//
//  FIX: Stats now correctly computed from driver-only transactions.
//
//  "Total In"  = trip_earning + bonus + referral  (type == 'credit')
//  "Total Out" = withdrawal + commission + penalty (type == 'debit')
//  "Pending"   = any tx with status == 'pending'
//
class WalletQuickStats extends StatelessWidget {
  final List<Map<String, dynamic>> txList;
  const WalletQuickStats({super.key, required this.txList});

  @override
  Widget build(BuildContext context) {
    // Only driver credit categories count as "earnings in"
    const creditCats = {
      _kCatTripEarning,
      _kCatBonus,
      _kCatReferral,
    };

    final totalIn = txList
        .where((t) =>
            t['type'] == 'credit' &&
            creditCats.contains(t['category'] as String?))
        .fold(0.0, (s, t) => s + ((t['amount'] as num?)?.toDouble() ?? 0));

    final totalOut = txList
        .where((t) => t['type'] == 'debit')
        .fold(0.0, (s, t) => s + ((t['amount'] as num?)?.toDouble() ?? 0));

    final pending = txList.where((t) => t['status'] == 'pending').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: FinanceStatTile(
            icon: Icons.arrow_downward_rounded,
            iconColor: AppTheme.primaryDark,
            iconBg: AppTheme.primarySubtle,
            label: 'Total in',
            value: formatGhs(totalIn),
          )),
          const SizedBox(width: 10),
          Expanded(
              child: FinanceStatTile(
            icon: Icons.arrow_upward_rounded,
            iconColor: AppTheme.dangerText,
            iconBg: AppTheme.dangerLight,
            label: 'Total out',
            value: formatGhs(totalOut),
          )),
          const SizedBox(width: 10),
          Expanded(
              child: FinanceStatTile(
            icon: Icons.hourglass_top_rounded,
            iconColor: AppTheme.warningText,
            iconBg: AppTheme.warningLight,
            label: 'Pending',
            value: '$pending',
          )),
        ]),
        const SizedBox(height: 10),
        FinanceNote(txList.length >= 50
            ? 'Based on your 50 most recent transactions.'
            : 'Based on your recent transactions.'),
      ],
    );
  }
}

// ── Transaction tile ───────────────────────────────────────────────────────────
//
//  FIX: Added category badge so driver can distinguish trip_earning
//       from bonus, commission, penalty, withdrawal at a glance.
//
class WalletTransactionTile extends StatelessWidget {
  final Map<String, dynamic> tx;
  const WalletTransactionTile({super.key, required this.tx});

  // Map category → human label
  static String _catLabel(String? cat) => switch (cat) {
        _kCatTripEarning => 'Trip',
        _kCatWithdrawal => 'Withdrawal',
        _kCatBonus => 'Bonus',
        _kCatCommission => 'Commission',
        _kCatPenalty => 'Penalty',
        _kCatReferral => 'Referral',
        _ => 'Transaction',
      };

  /// The stored status as shown; completed (or missing) shows no pill.
  static ({String label, StatusTone tone})? statusOf(String? status) =>
      switch (status) {
        null || '' || 'completed' => null,
        'pending' => (label: 'Pending', tone: StatusTone.pending),
        'failed' => (label: 'Failed', tone: StatusTone.failed),
        final s => (
            label: s[0].toUpperCase() + s.substring(1).replaceAll('_', ' '),
            tone: StatusTone.neutral,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final isCredit = tx['type'] == 'credit';
    final failed = tx['status'] == 'failed';
    final status = statusOf(tx['status'] as String?);
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final desc = tx['description'] as String? ?? '—';
    final ts = (tx['createdAt'] as Timestamp?)?.toDate();
    final fmt = DateFormat('MMM d · h:mm a');

    final amountColor = failed
        ? AppTheme.textSecondary
        : isCredit
            ? AppTheme.primaryDark
            : AppTheme.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FinanceCard(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isCredit ? AppTheme.primarySubtle : AppTheme.dangerLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCredit
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: isCredit ? AppTheme.primaryDark : AppTheme.dangerText,
              size: 20,
              semanticLabel: isCredit ? 'Money in' : 'Money out',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FinanceTitleAmountRow(
                  title: Text(desc,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  amount: Text(
                    '${isCredit ? '+' : '−'} ${formatGhs(amount)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: amountColor,
                      decoration: failed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(ts == null ? 'Date unavailable' : fmt.format(ts),
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                    StatusPill(
                      label: _catLabel(tx['category'] as String?),
                      tone: StatusTone.neutral,
                    ),
                    if (status != null)
                      StatusPill(label: status.label, tone: status.tone),
                  ],
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Withdraw sheet ─────────────────────────────────────────────────────────────
//
//  The checks run in the original order with the original messages; the
//  server call and its result handling stay in the screen ([onSubmit]).
//
class WithdrawSheet extends StatefulWidget {
  final double balance;
  final void Function(String message) onInvalid;
  final Future<void> Function(double amount, String method, String phone)
      onSubmit;

  const WithdrawSheet({
    super.key,
    required this.balance,
    required this.onInvalid,
    required this.onSubmit,
  });

  static const networks = [
    ('MTN MoMo', Icons.phone_android_rounded),
    ('Telecel Cash', Icons.credit_card_rounded),
    ('AirtelTigo Money', Icons.account_balance_wallet_rounded),
  ];

  @override
  State<WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<WithdrawSheet> {
  final _amountCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _method;
  bool _processing = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final phone = _phoneCtrl.text.trim();

    if (amount < kMinWithdrawalGhs) {
      widget.onInvalid('Minimum withdrawal is GH₵ 10');
      return;
    }
    // FIX: validate against walletBalance, not totalEarnings
    if (amount > widget.balance) {
      widget.onInvalid('Insufficient wallet balance');
      return;
    }
    if (phone.isEmpty) {
      widget.onInvalid('Enter your mobile number');
      return;
    }

    setState(() => _processing = true);
    await widget.onSubmit(amount, _method!, phone);
    if (mounted) setState(() => _processing = false);
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                    child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                )),
                const SizedBox(height: 18),
                const Text('Withdraw funds',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    )),
                const SizedBox(height: 4),
                Text(
                  'Available balance: ${formatGhs(widget.balance)}',
                  style: const TextStyle(
                      fontSize: 14, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount (GH₵)',
                    hintText: 'Min GH₵ ${kMinWithdrawalGhs.toStringAsFixed(0)}',
                    prefixText: 'GH₵ ',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile money number',
                    hintText: '024XXXXXXX',
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Mobile money network',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    )),
                const SizedBox(height: 10),
                for (final (name, icon) in WithdrawSheet.networks)
                  _NetworkOption(
                    name: name,
                    icon: icon,
                    selected: _method == name,
                    onTap: _processing
                        ? null
                        : () => setState(() => _method = name),
                  ),
                const SizedBox(height: 8),
                const FinanceNote(
                  'Your withdrawal is sent to your mobile money provider. '
                  'It shows as Pending until the payment is confirmed.',
                  icon: Icons.schedule_rounded,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('withdraw-submit'),
                    onPressed:
                        (_method == null || _processing) ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: _processing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Request withdrawal',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            )),
                  ),
                ),
                if (_method == null) ...[
                  const SizedBox(height: 8),
                  const Center(
                    child: Text('Choose a network to continue',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}

class _NetworkOption extends StatelessWidget {
  final String name;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const _NetworkOption({
    required this.name,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? AppTheme.primarySubtle : AppTheme.background,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: selected ? AppTheme.primaryDark : AppTheme.divider,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(children: [
                Icon(icon,
                    size: 20,
                    color: selected
                        ? AppTheme.primaryDark
                        : AppTheme.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppTheme.primaryDeep
                              : AppTheme.textPrimary,
                        ))),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      color: AppTheme.primaryDark, size: 20),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

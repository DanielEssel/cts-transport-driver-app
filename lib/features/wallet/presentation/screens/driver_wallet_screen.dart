
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kPrimary       = Color(0xFF16A34A);
const _kPrimaryDark   = Color(0xFF15803D);
const _kPrimaryDim    = Color(0xFFDCFCE7);
const _kSurface       = Colors.white;
const _kBg            = Color(0xFFF8FAF9);
const _kBorder        = Color(0xFFE5E7EB);
const _kTextPrimary   = Color(0xFF111827);
const _kTextSecondary = Color(0xFF6B7280);
const _kTextTertiary  = Color(0xFF9CA3AF);
const _kSuccess       = Color(0xFF16A34A);
const _kSuccessDim    = Color(0xFFDCFCE7);
const _kError         = Color(0xFFDC2626);
const _kErrorDim      = Color(0xFFFEE2E2);
const _kWarning       = Color(0xFFD97706);
const _kWarningDim    = Color(0xFFFEF3C7);
const _kPurple        = Color(0xFF7C3AED);
const _kPurpleDim     = Color(0xFFEDE9FE);

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
const _kCatTripEarning  = 'trip_earning';   // credit  – driver's cut of a fare
const _kCatWithdrawal   = 'withdrawal';     // debit   – payout to mobile money
const _kCatBonus        = 'bonus';          // credit  – promo / incentive
const _kCatCommission   = 'commission';     // debit   – platform fee deducted
const _kCatPenalty      = 'penalty';        // debit   – cancellation / violation
const _kCatReferral     = 'referral';       // credit  – referral reward

// ── Screen ─────────────────────────────────────────────────────────────────────
class DriverWalletScreen extends StatefulWidget {
  const DriverWalletScreen({super.key});

  @override
  State<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends State<DriverWalletScreen>
    with SingleTickerProviderStateMixin {

  final _db  = FirebaseFirestore.instance;
  final _fns = FirebaseFunctions.instance;
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Streams ──────────────────────────────────────────────────────────────
  //  REMOVED: _walletSub (was duplicate of _driverSub, both hit drivers/{uid})
  StreamSubscription<DocumentSnapshot>? _earningsSub;
  StreamSubscription<DocumentSnapshot>? _driverSub;
  StreamSubscription<QuerySnapshot>?    _txSub;
  StreamSubscription<User?>? _authSub;

  // ── Data ─────────────────────────────────────────────────────────────────
  /// Withdrawable balance stored on drivers/{uid}.walletBalance.
  /// This is distinct from totalEarnings (lifetime counter, never decremented).
  double _walletBalance   = 0;

  double _todayEarnings   = 0;
  double _weekEarnings    = 0;
  double _totalEarnings   = 0;   // lifetime, from drivers/{uid}.totalEarnings
  int    _completedTrips  = 0;

  /// FIX: only driver-specific transactions (queried by driverId).
  List<Map<String, dynamic>> _txList = [];

  // ── Loading ───────────────────────────────────────────────────────────────
  bool _loadingDriver   = true;
  bool _loadingEarnings = true;
  bool _loadingTx       = true;

  late final TabController _tabController;

  @override
void initState() {
  super.initState();

  _tabController = TabController(length: 2, vsync: this);

  _authSub = FirebaseAuth.instance
      .authStateChanges()
      .listen((user) {

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
    _driverSub = _db
        .collection('drivers')
        .doc(_uid)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      final d = doc.data() ?? {};
      setState(() {
        // walletBalance is the correct withdrawable field.
        // totalEarnings is the lifetime counter – kept for the earnings card.
        _walletBalance  = (d['walletBalance']  as num?)?.toDouble() ?? 0;
        
        _completedTrips = (d['completedTrips'] as num?)?.toInt()    ?? 0;
        _loadingDriver  = false;
      });
    }, onError: (_) {
      if (mounted) setState(() => _loadingDriver = false);
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
        _todayEarnings   = (d['todayEarnings']    as num?)?.toDouble() ?? _todayEarnings;
        _weekEarnings    = (d['weekEarnings']     as num?)?.toDouble() ?? 0;
        _totalEarnings   = (d['lifetimeEarnings'] as num?)?.toDouble() ?? _totalEarnings;
        _totalEarnings  = (d['totalEarnings']  as num?)?.toDouble() ?? 0;
        _loadingEarnings = false;
      });
    }, onError: (_) {
      if (mounted) setState(() => _loadingEarnings = false);
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
        .where('driverId', isEqualTo: _uid)   // ← THE FIX
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _txList    = snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList();
        _loadingTx = false;
      });
    }, onError: (e) {
      // If index is missing Firestore throws a permission / index error.
      // Surface it so the developer can create the composite index.
      debugPrint('[DriverWallet] _subscribeTx error: $e');
      if (mounted) setState(() => _loadingTx = false);
    });
  }

  // ── Refresh ───────────────────────────────────────────────────────────────
  Future<void> _refresh() async {
  await Future.delayed(const Duration(milliseconds: 500));
}

  // ── Withdrawal ────────────────────────────────────────────────────────────
  //
  //  The Cloud Function 'requestWithdrawal' is responsible for:
  //    1. Validating amount ≤ drivers/{uid}.walletBalance
  //    2. Decrementing drivers/{uid}.walletBalance
  //    3. Writing a /transactions doc with category='withdrawal', type='debit',
  //       driverId=uid  (NOT userId)
  //
  Future<void> _requestWithdrawal({
    required double amount,
    required String method,
    required String phone,
  }) async {
    try {
      final result = await _fns
          .httpsCallable('requestWithdrawal')
          .call({
        'amount':      amount,
        'method':      method,
        'phoneNumber': phone,
      });

      if (!mounted) return;

      if (result.data['success'] == true) {
        Navigator.pop(context);
        _snack('GH₵ ${amount.toStringAsFixed(2)} withdrawal requested ✓',
            isSuccess: true);
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
        content:         Text(msg),
        backgroundColor: isSuccess ? _kSuccess : isError ? _kError : null,
        behavior:        SnackBarBehavior.floating,
        shape:           RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
  }

  // ── Withdraw sheet ────────────────────────────────────────────────────────
  void _showWithdrawSheet() {
    final amountCtrl = TextEditingController();
    final phoneCtrl  = TextEditingController();
    String? method;
    bool    processing = false;

    showModalBottomSheet<void>(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: const BoxDecoration(
            color:        _kSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize:       MainAxisSize.min,
              children: [
                Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color:        _kBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                )),
                const SizedBox(height: 20),
                const Text('Withdraw Funds',
                    style: TextStyle(
                      fontSize:   20,
                      fontWeight: FontWeight.w800,
                      color:      _kTextPrimary,
                    )),
                const SizedBox(height: 4),
                Text(
                  'Available balance: GH₵ ${_walletBalance.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 13, color: _kTextSecondary),
                ),
                const SizedBox(height: 24),

                _InputField(
                  controller:   amountCtrl,
                  label:        'Amount (GH₵)',
                  hint:         'Min GH₵ 10',
                  prefix:       'GH₵ ',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 14),
                _InputField(
                  controller:   phoneCtrl,
                  label:        'Mobile Money Number',
                  hint:         '024XXXXXXX',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                const Text('Payment Method',
                    style: TextStyle(
                      fontSize:   13,
                      fontWeight: FontWeight.w700,
                      color:      _kTextPrimary,
                    )),
                const SizedBox(height: 10),

                ...[
                  ('MTN MoMo',         '📱'),
                  ('Vodafone Cash',    '💳'),
                  ('AirtelTigo Money', '💰'),
                  ('Bank Transfer',    '🏦'),
                ].map((m) {
                  final selected = method == m.$1;
                  return GestureDetector(
                    onTap: () => setSheet(() => method = m.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin:   const EdgeInsets.only(bottom: 8),
                      padding:  const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color:        selected
                            ? _kPrimaryDim
                            : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border:       Border.all(
                          color: selected ? _kPrimary : _kBorder,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(children: [
                        Text(m.$2, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(m.$1,
                            style: TextStyle(
                              fontSize:   14,
                              fontWeight: FontWeight.w600,
                              color: selected ? _kPrimary : _kTextPrimary,
                            ))),
                        if (selected)
                          const Icon(Icons.check_circle_rounded,
                              color: _kPrimary, size: 20),
                      ]),
                    ),
                  );
                }),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: (method == null || processing) ? null : () async {
                      final amount =
                          double.tryParse(amountCtrl.text.trim()) ?? 0;
                      final phone = phoneCtrl.text.trim();

                      if (amount < 10) {
                        _snack('Minimum withdrawal is GH₵ 10', isError: true);
                        return;
                      }
                      // FIX: validate against walletBalance, not totalEarnings
                      if (amount > _walletBalance) {
                        _snack('Insufficient wallet balance', isError: true);
                        return;
                      }
                      if (phone.isEmpty) {
                        _snack('Enter your mobile number', isError: true);
                        return;
                      }

                      setSheet(() => processing = true);
                      await _requestWithdrawal(
                          amount: amount, method: method!, phone: phone);
                      if (ctx.mounted) setSheet(() => processing = false);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor:         _kPrimary,
                      disabledBackgroundColor: _kBorder,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape:   RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: processing
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Request Withdrawal',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize:   15,
                            )),
                  ),
                ),
              ],
            ),
          ),
        ),
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
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('Wallet & Earnings',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        backgroundColor:  _kSurface,
        elevation:        0,
        surfaceTintColor: Colors.transparent,
        bottom: TabBar(
          controller:          _tabController,
          labelColor:          _kPrimary,
          unselectedLabelColor: _kTextSecondary,
          indicatorColor:      _kPrimary,
          indicatorWeight:     2.5,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [Tab(text: 'Overview'), Tab(text: 'Transactions')],
        ),
      ),
      body: RefreshIndicator(
        color:     _kPrimary,
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
        _WalletCard(
          balance:    _walletBalance,
          loading:    _loadingDriver,
          onWithdraw: _showWithdrawSheet,
        ),
        const SizedBox(height: 16),
        _EarningsCard(
          todayEarnings:  _todayEarnings,
          weekEarnings:   _weekEarnings,
          totalEarnings:  _totalEarnings,
          completedTrips: _completedTrips,
          loading:        _loadingEarnings || _loadingDriver,
        ),
        const SizedBox(height: 16),
        // FIX: QuickStats now receives driver-only txList (driverId-queried)
        _QuickStats(txList: _txList),
      ],
    );
  }

  // ── Transactions tab ──────────────────────────────────────────────────────
  Widget _buildTransactionsTab() {
    if (_loadingTx) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }
    if (_txList.isEmpty) {
      return const _EmptyTx();
    }
    return ListView.builder(
      padding:     const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount:   _txList.length,
      itemBuilder: (_, i) => _TxTile(tx: _txList[i]),
    );
  }
}

// ── Wallet card ────────────────────────────────────────────────────────────────
class _WalletCard extends StatelessWidget {
  final double       balance;
  final bool         loading;
  final VoidCallback onWithdraw;
  const _WalletCard({
    required this.balance,
    required this.loading,
    required this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kPrimary, _kPrimaryDark],
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color:      _kPrimary.withValues(alpha: 0.35),
              blurRadius: 24,
              offset:     const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Wallet Balance',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:        Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.account_balance_wallet_rounded,
                        color: Colors.white70, size: 12),
                    SizedBox(width: 5),
                    Text('CTSRide Driver',
                        style: TextStyle(
                          color:      Colors.white70,
                          fontSize:   10,
                          fontWeight: FontWeight.w600,
                        )),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            loading
                ? Container(
                    width: 160, height: 44,
                    decoration: BoxDecoration(
                      color:        Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  )
                : Text(
                    'GH₵ ${balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color:         Colors.white,
                      fontSize:      42,
                      fontWeight:    FontWeight.w900,
                      letterSpacing: -1,
                      height:        1,
                    ),
                  ),
            const SizedBox(height: 6),
            const Text('Available for withdrawal',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onWithdraw,
                icon:  const Icon(Icons.arrow_upward_rounded,
                    color: Colors.white, size: 16),
                label: const Text('Withdraw Funds',
                    style: TextStyle(
                      color:      Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize:   14,
                    )),
                style: OutlinedButton.styleFrom(
                  side:    const BorderSide(color: Colors.white38, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape:   RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      );
}

// ── Earnings card ──────────────────────────────────────────────────────────────
class _EarningsCard extends StatelessWidget {
  final double todayEarnings;
  final double weekEarnings;
  final double totalEarnings;
  final int    completedTrips;
  final bool   loading;

  const _EarningsCard({
    required this.todayEarnings,
    required this.weekEarnings,
    required this.totalEarnings,
    required this.completedTrips,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color:        _kPrimaryDim,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.trending_up_rounded,
                    color: _kPrimary, size: 18),
              ),
              const SizedBox(width: 12),
              const Text('Earnings',
                  style: TextStyle(
                    fontSize:   16,
                    fontWeight: FontWeight.w700,
                    color:      _kTextPrimary,
                  )),
            ]),
            const SizedBox(height: 16),
            const Divider(height: 1, color: _kBorder),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _EarningItem(
                label: 'Today',
                value: 'GH₵ ${todayEarnings.toStringAsFixed(2)}',
                color: _kPrimary,
                loading: loading,
              )),
              Container(width: 1, height: 40, color: _kBorder),
              Expanded(child: _EarningItem(
                label: 'This Week',
                value: 'GH₵ ${weekEarnings.toStringAsFixed(2)}',
                color: Colors.blue,
                loading: loading,
              )),
              Container(width: 1, height: 40, color: _kBorder),
              Expanded(child: _EarningItem(
                label: 'All Time',
                value: 'GH₵ ${totalEarnings.toStringAsFixed(2)}',
                color: Colors.purple,
                loading: loading,
              )),
            ]),
            const SizedBox(height: 16),
            const Divider(height: 1, color: _kBorder),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.check_circle_rounded,
                  color: _kPrimary, size: 16),
              const SizedBox(width: 8),
              Text('$completedTrips trips completed',
                  style: const TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w600,
                    color:      _kTextSecondary,
                  )),
            ]),
          ],
        ),
      );
}

class _EarningItem extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  final bool   loading;
  const _EarningItem({
    required this.label,
    required this.value,
    required this.color,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(label,
              style: const TextStyle(
                fontSize:   11,
                color:      _kTextTertiary,
                fontWeight: FontWeight.w500,
              )),
          const SizedBox(height: 6),
          loading
              ? Container(
                  width: 60, height: 18,
                  decoration: BoxDecoration(
                    color:        _kBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )
              : Text(value,
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w800,
                    color:      color,
                  ),
                  textAlign: TextAlign.center),
        ],
      );
}

// ── Quick stats ────────────────────────────────────────────────────────────────
//
//  FIX: Stats now correctly computed from driver-only transactions.
//
//  "Total In"  = trip_earning + bonus + referral  (type == 'credit')
//  "Total Out" = withdrawal + commission + penalty (type == 'debit')
//  "Pending"   = any tx with status == 'pending'
//
class _QuickStats extends StatelessWidget {
  final List<Map<String, dynamic>> txList;
  const _QuickStats({required this.txList});

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

    final pending =
        txList.where((t) => t['status'] == 'pending').length;

    return Row(children: [
      Expanded(child: _StatChip(
        icon:      Icons.arrow_downward_rounded,
        iconColor: _kSuccess,
        iconBg:    _kSuccessDim,
        label:     'Total In',
        value:     'GH₵ ${totalIn.toStringAsFixed(2)}',
      )),
      const SizedBox(width: 10),
      Expanded(child: _StatChip(
        icon:      Icons.arrow_upward_rounded,
        iconColor: _kError,
        iconBg:    _kErrorDim,
        label:     'Total Out',
        value:     'GH₵ ${totalOut.toStringAsFixed(2)}',
      )),
      const SizedBox(width: 10),
      Expanded(child: _StatChip(
        icon:      Icons.hourglass_top_rounded,
        iconColor: _kWarning,
        iconBg:    _kWarningDim,
        label:     'Pending',
        value:     '$pending',
      )),
    ]);
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final Color    iconBg;
  final String   label;
  final String   value;
  const _StatChip({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset:     const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color:        iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 15),
            ),
            const SizedBox(height: 10),
            Text(value,
                style: const TextStyle(
                  fontSize:   13,
                  fontWeight: FontWeight.w800,
                  color:      _kTextPrimary,
                  height:     1,
                )),
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: _kTextTertiary)),
          ],
        ),
      );
}

// ── Transaction tile ───────────────────────────────────────────────────────────
//
//  FIX: Added category badge so driver can distinguish trip_earning
//       from bonus, commission, penalty, withdrawal at a glance.
//
class _TxTile extends StatelessWidget {
  final Map<String, dynamic> tx;
  const _TxTile({required this.tx});

  // Map category → human label + colour
  static ({String label, Color color, Color bg}) _catMeta(String? cat) =>
      switch (cat) {
        _kCatTripEarning => (
            label: 'Trip',
            color: _kSuccess,
            bg:    _kSuccessDim,
          ),
        _kCatWithdrawal  => (
            label: 'Withdrawal',
            color: _kError,
            bg:    _kErrorDim,
          ),
        _kCatBonus       => (
            label: 'Bonus',
            color: _kPurple,
            bg:    _kPurpleDim,
          ),
        _kCatCommission  => (
            label: 'Commission',
            color: _kWarning,
            bg:    _kWarningDim,
          ),
        _kCatPenalty     => (
            label: 'Penalty',
            color: _kError,
            bg:    _kErrorDim,
          ),
        _kCatReferral    => (
            label: 'Referral',
            color: Colors.blue,
            bg:    const Color(0xFFDBEAFE),
          ),
        _                => (
            label: 'Transaction',
            color: _kTextSecondary,
            bg:    const Color(0xFFF3F4F6),
          ),
      };

  @override
  Widget build(BuildContext context) {
    final isCredit  = tx['type'] == 'credit';
    final isPending = tx['status'] == 'pending';
    final amount    = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final desc      = tx['description'] as String? ?? '—';
    final ts        = (tx['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final fmt       = DateFormat('MMM d · h:mm a');
    final cat       = _catMeta(tx['category'] as String?);

    return Container(
      margin:  const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color:        isCredit ? _kSuccessDim : _kErrorDim,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isCredit
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
            color: isCredit ? _kSuccess : _kError,
            size:  18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(desc,
                  style: const TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w600,
                    color:      _kTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                Text(fmt.format(ts),
                    style: const TextStyle(
                        fontSize: 11, color: _kTextTertiary)),
                const SizedBox(width: 6),
                // Category badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color:        cat.bg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(cat.label,
                      style: TextStyle(
                        fontSize:   9,
                        fontWeight: FontWeight.w700,
                        color:      cat.color,
                      )),
                ),
                if (isPending) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color:        _kWarningDim,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Pending',
                        style: TextStyle(
                          fontSize:   9,
                          fontWeight: FontWeight.w700,
                          color:      _kWarning,
                        )),
                  ),
                ],
              ]),
            ],
          ),
        ),
        Text(
          '${isCredit ? '+' : '-'} GH₵ ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize:   14,
            fontWeight: FontWeight.w800,
            color:      isCredit ? _kSuccess : _kError,
          ),
        ),
      ]),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────
class _EmptyTx extends StatelessWidget {
  const _EmptyTx();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color:        _kPrimaryDim,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    color: _kPrimary, size: 36),
              ),
              const SizedBox(height: 16),
              const Text('No transactions yet',
                  style: TextStyle(
                    fontSize:   16,
                    fontWeight: FontWeight.w700,
                    color:      _kTextPrimary,
                  )),
              const SizedBox(height: 8),
              const Text(
                'Your earnings and withdrawals\nwill appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: _kTextSecondary, height: 1.5),
              ),
            ],
          ),
        ),
      );
}

// ── Input field ────────────────────────────────────────────────────────────────
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String                label;
  final String                hint;
  final String?               prefix;
  final TextInputType         keyboardType;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.prefix,
    required this.keyboardType,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller:   controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14, color: _kTextPrimary),
        decoration: InputDecoration(
          labelText:  label,
          hintText:   hint,
          prefixText: prefix,
          filled:     true,
          fillColor:  const Color(0xFFF9FAFB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:   const BorderSide(color: _kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:   const BorderSide(color: _kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:   const BorderSide(color: _kPrimary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 14),
        ),
      );
}
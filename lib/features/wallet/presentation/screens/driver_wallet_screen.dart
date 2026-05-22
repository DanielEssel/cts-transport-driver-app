// lib/features/wallet/presentation/screens/driver_wallet_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────────────────────────────────────

class _C {
  static const bg            = Color(0xFFF0F2F8);
  static const card          = Color(0xFFFFFFFF);
  static const primary       = Color(0xFF0E9F6E);
  static const primaryDim    = Color(0xFFEBF0FD);
  static const success       = Color(0xFF0E9F6E);
  static const successDim    = Color(0xFFDEF7EC);
  static const warning       = Color(0xFFE3A008);
  static const warningDim    = Color(0xFFFDF3D0);
  static const error         = Color(0xFFE02424);
  static const errorDim      = Color(0xFFFDE8E8);
  static const textPrimary   = Color(0xFF0FA958);
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary  = Color(0xFF9CA3AF);
  static const border        = Color(0xFFE5E7EB);

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color:      Colors.black.withValues(alpha: 0.05),
      blurRadius: 16,
      offset:     const Offset(0, 4),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class DriverWalletScreen extends StatefulWidget {
  const DriverWalletScreen({super.key});

  @override
  State<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends State<DriverWalletScreen> {
  final _db        = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;
  final _uid       = FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Streams ──
  StreamSubscription<DocumentSnapshot>? _walletSub;
  StreamSubscription<QuerySnapshot>?    _txSub;

  double                _balance      = 0.0;
  List<Map<String, dynamic>> _txList  = [];
  bool                  _loadingWallet = true;
  bool                  _loadingTx     = true;

  @override
  void initState() {
    super.initState();
    _subscribeWallet();
    _subscribeTx();
  }

  @override
  void dispose() {
    _walletSub?.cancel();
    _txSub?.cancel();
    super.dispose();
  }

  // ── Wallet stream ─────────────────────────────────────────────────────────

  void _subscribeWallet() {
    _walletSub = _db
        .collection('wallets')
        .doc(_uid)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      if (doc.exists) {
        setState(() {
          _balance       = (doc.data()?['balance'] as num?)?.toDouble() ?? 0.0;
          _loadingWallet = false;
        });
      } else {
        setState(() { _loadingWallet = false; });
      }
    }, onError: (_) {
      if (mounted) setState(() { _loadingWallet = false; });
    });
  }

  // ── Transactions stream ───────────────────────────────────────────────────

  void _subscribeTx() {
    _txSub = _db
        .collection('transactions')
        .where('userId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _txList    = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _loadingTx = false;
      });
    }, onError: (_) {
      if (mounted) setState(() { _loadingTx = false; });
    });
  }

  // ── Withdrawal ────────────────────────────────────────────────────────────

  Future<void> _requestWithdrawal({
    required double amount,
    required String method,
    required String phoneNumber,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('requestWithdrawal')
          .call({
        'amount':      amount,
        'method':      method,
        'phoneNumber': phoneNumber,
      });

      if (mounted && result.data['success'] == true) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('GH₵ ${amount.toStringAsFixed(2)} withdrawal requested'),
            ]),
            backgroundColor: _C.success,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text(e.message ?? 'Withdrawal failed'),
          backgroundColor: _C.error,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text(e.toString()),
          backgroundColor: _C.error,
        ));
      }
    }
  }

  // ── Withdraw sheet ────────────────────────────────────────────────────────

  void _showWithdrawSheet() {
    final amountCtrl = TextEditingController();
    final phoneCtrl  = TextEditingController();
    String? method;
    bool    isProcessing = false;

    showModalBottomSheet(
      context:          context,
      isScrollControlled: true,
      backgroundColor:  Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: const BoxDecoration(
            color:        _C.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left:   24,
            right:  24,
            top:    24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize:       MainAxisSize.min,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 38, height: 4,
                    decoration: BoxDecoration(
                      color:        _C.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text('Withdraw Funds',
                    style: TextStyle(
                      fontSize:   20,
                      fontWeight: FontWeight.w800,
                      color:      _C.textPrimary,
                    )),
                const SizedBox(height: 4),
                Text(
                  'Available: GH₵ ${_balance.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 13, color: _C.textSecondary),
                ),
                const SizedBox(height: 20),

                // Amount
                _Field(
                  controller:  amountCtrl,
                  label:       'Amount (GH₵)',
                  hint:        'Min GH₵ 10',
                  prefix:      'GH₵ ',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // Phone
                _Field(
                  controller:  phoneCtrl,
                  label:       'Mobile Money Number',
                  hint:        '024XXXXXXX',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                // Method
                const Text('Payment Method',
                    style: TextStyle(
                      fontSize:   13,
                      fontWeight: FontWeight.w700,
                      color:      _C.textPrimary,
                    )),
                const SizedBox(height: 10),

                ...[ 
                  ('MTN MoMo',       '📱'),
                  ('Vodafone Cash',  '💳'),
                  ('AirtelTigo Money','💰'),
                  ('Bank Transfer',  '🏦'),
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
                            ? _C.primaryDim
                            : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border:       Border.all(
                          color: selected ? _C.primary : _C.border,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(m.$2,
                              style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              m.$1,
                              style: TextStyle(
                                fontSize:   14,
                                fontWeight: FontWeight.w600,
                                color:      selected
                                    ? _C.primary
                                    : _C.textPrimary,
                              ),
                            ),
                          ),
                          if (selected)
                            const Icon(Icons.check_circle_rounded,
                                color: _C.primary, size: 20),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: (method == null || isProcessing)
                        ? null
                        : () async {
                            final amount =
                                double.tryParse(amountCtrl.text) ?? 0;
                            final phone = phoneCtrl.text.trim();

                            if (amount < 10) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Minimum withdrawal is GH₵ 10')),
                              );
                              return;
                            }
                            if (amount > _balance) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Insufficient balance')),
                              );
                              return;
                            }
                            if (phone.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Enter your mobile number')),
                              );
                              return;
                            }

                            setSheet(() => isProcessing = true);
                            await _requestWithdrawal(
                              amount:      amount,
                              method:      method!,
                              phoneNumber: phone,
                            );
                            setSheet(() => isProcessing = false);
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: _C.primary,
                      disabledBackgroundColor:
                          _C.border,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: isProcessing
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color:       Colors.white))
                        : const Text('Request Withdrawal',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize:   15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        title: const Text('Wallet',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor:  _C.card,
        elevation:        0,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        color:     _C.primary,
        onRefresh: () async {
          _subscribeWallet();
          _subscribeTx();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            // ── Balance card ──
            _BalanceCard(
              balance:  _balance,
              loading:  _loadingWallet,
              onWithdraw: _showWithdrawSheet,
            ),

            const SizedBox(height: 20),

            // ── Stats strip ──
            _StatsStrip(txList: _txList),

            const SizedBox(height: 24),

            // ── Transaction header ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Transactions',
                    style: TextStyle(
                      fontSize:   16,
                      fontWeight: FontWeight.w700,
                      color:      _C.textPrimary,
                    )),
                Text(
                  '${_txList.length} records',
                  style: const TextStyle(
                      fontSize: 12, color: _C.textTertiary),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Transaction list ──
            if (_loadingTx)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ))
            else if (_txList.isEmpty)
              const _EmptyTx()
            else
              ..._txList.map((tx) => _TxTile(tx: tx)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BALANCE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  final double       balance;
  final bool         loading;
  final VoidCallback onWithdraw;

  const _BalanceCard({
    required this.balance,
    required this.loading,
    required this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A56DB), Color(0xFF1E429F)],
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color:      const Color(0xFF1A56DB).withValues(alpha: 0.35),
              blurRadius: 24,
              offset:     const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Decorative top row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Available Balance',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 13)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:        Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_balance_wallet_rounded,
                          color: Colors.white70, size: 12),
                      SizedBox(width: 5),
                      Text('Driver Wallet',
                          style: TextStyle(
                            color:      Colors.white70,
                            fontSize:   10,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            loading
                ? Container(
                    width: 180, height: 44,
                    decoration: BoxDecoration(
                      color:        Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  )
                : Text(
                    'GH₵ ${balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color:       Colors.white,
                      fontSize:    40,
                      fontWeight:  FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),

            const SizedBox(height: 20),

            // Actions row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onWithdraw,
                    icon:  const Icon(Icons.arrow_upward_rounded,
                        color: Colors.white, size: 16),
                    label: const Text('Withdraw',
                        style: TextStyle(
                          color:      Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize:   13,
                        )),
                    style: OutlinedButton.styleFrom(
                      side:    const BorderSide(
                          color: Colors.white38, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape:   RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// STATS STRIP
// ─────────────────────────────────────────────────────────────────────────────

class _StatsStrip extends StatelessWidget {
  final List<Map<String, dynamic>> txList;
  const _StatsStrip({required this.txList});

  @override
  Widget build(BuildContext context) {
    final credits    = txList.where((t) => t['type'] == 'credit');
    final debits     = txList.where((t) => t['type'] == 'debit');
    final totalIn    = credits.fold(
        0.0, (s, t) => s + ((t['amount'] as num?)?.toDouble() ?? 0));
    final totalOut   = debits.fold(
        0.0, (s, t) => s + ((t['amount'] as num?)?.toDouble() ?? 0));
    final pending    = txList
        .where((t) => t['status'] == 'pending')
        .length;

    return Row(
      children: [
        Expanded(child: _StatTile(
          icon:      Icons.arrow_downward_rounded,
          iconColor: _C.success,
          iconBg:    _C.successDim,
          label:     'Total In',
          value:     'GH₵ ${totalIn.toStringAsFixed(2)}',
        )),
        const SizedBox(width: 10),
        Expanded(child: _StatTile(
          icon:      Icons.arrow_upward_rounded,
          iconColor: _C.error,
          iconBg:    _C.errorDim,
          label:     'Total Out',
          value:     'GH₵ ${totalOut.toStringAsFixed(2)}',
        )),
        const SizedBox(width: 10),
        Expanded(child: _StatTile(
          icon:      Icons.hourglass_top_rounded,
          iconColor: _C.warning,
          iconBg:    _C.warningDim,
          label:     'Pending',
          value:     '$pending',
        )),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final Color    iconBg;
  final String   label;
  final String   value;

  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:        _C.card,
          borderRadius: BorderRadius.circular(14),
          boxShadow:    _C.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color:        iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 15),
            ),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                  fontSize:   13,
                  fontWeight: FontWeight.w800,
                  color:      _C.textPrimary,
                  height:     1,
                )),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: _C.textTertiary)),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// TRANSACTION TILE
// ─────────────────────────────────────────────────────────────────────────────

class _TxTile extends StatelessWidget {
  final Map<String, dynamic> tx;
  const _TxTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isCredit  = tx['type'] == 'credit';
    final isPending = tx['status'] == 'pending';
    final amount    = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final desc      = tx['description'] as String? ?? '—';
    final ts        = (tx['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final fmt       = DateFormat('MMM d · h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        _C.card,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: _C.border),
        boxShadow:    _C.cardShadow,
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color:        isCredit ? _C.successDim : _C.errorDim,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCredit
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: isCredit ? _C.success : _C.error,
              size:  18,
            ),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(desc,
                    style: const TextStyle(
                      fontSize:   13,
                      fontWeight: FontWeight.w600,
                      color:      _C.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(fmt.format(ts),
                        style: const TextStyle(
                            fontSize: 11, color: _C.textTertiary)),
                    if (isPending) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:        _C.warningDim,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Pending',
                            style: TextStyle(
                              fontSize:   9,
                              fontWeight: FontWeight.w700,
                              color:      _C.warning,
                            )),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Amount
          Text(
            '${isCredit ? '+' : '-'} GH₵ ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize:   14,
              fontWeight: FontWeight.w800,
              color:      isCredit ? _C.success : _C.error,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyTx extends StatelessWidget {
  const _EmptyTx();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color:        _C.primaryDim,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                    Icons.receipt_long_rounded,
                    color: _C.primary, size: 32),
              ),
              const SizedBox(height: 14),
              const Text('No transactions yet',
                  style: TextStyle(
                    fontSize:   16,
                    fontWeight: FontWeight.w700,
                    color:      _C.textPrimary,
                  )),
              const SizedBox(height: 6),
              const Text(
                'Your earnings and withdrawals\nwill appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: _C.textSecondary),
              ),
            ],
          ),
        ),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String                label;
  final String                hint;
  final String?               prefix;
  final TextInputType         keyboardType;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.prefix,
    required this.keyboardType,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller:  controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14, color: _C.textPrimary),
        decoration: InputDecoration(
          labelText:  label,
          hintText:   hint,
          prefixText: prefix,
          filled:     true,
          fillColor:  const Color(0xFFF9FAFB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:   const BorderSide(color: _C.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:   const BorderSide(color: _C.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:   const BorderSide(color: _C.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
        ),
      );
}
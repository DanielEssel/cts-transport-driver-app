// features/driver/presentation/withdrawal_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class WithdrawalScreen extends StatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  double _balance = 0.0;
  String _selectedMethod = 'Mobile Money';
  String _selectedNetwork = 'MTN';
  String _accountNumber = '';
  String _accountName = '';
  bool _isLoading = true;
  bool _isWithdrawing = false;

  static const _methods = ['Mobile Money', 'Bank Transfer'];
  static const _networks = ['MTN', 'Vodafone', 'AirtelTigo'];
  static const _minWithdrawal = 50.0;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(_uid)
          .collection('earnings')
          .doc('summary')
          .get();

      if (snap.exists) {
        final data = snap.data()!;
        setState(() {
          _balance =
              (data['totalBalance'] as num?)?.toDouble() ?? 0.0;
        });
      }

      // Load saved payout info
      final driverSnap = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(_uid)
          .get();

      if (driverSnap.exists) {
        final d = driverSnap.data()!;
        final payout =
            d['payoutInfo'] as Map<String, dynamic>? ?? {};
        setState(() {
          _selectedMethod =
              payout['method'] as String? ?? 'Mobile Money';
          _selectedNetwork =
              payout['network'] as String? ?? 'MTN';
          _accountNumber =
              payout['accountNumber'] as String? ?? '';
          _accountName = payout['accountName'] as String? ?? '';
        });
      }
    } catch (_) {} finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;

    final confirmed = await _showConfirmDialog(amount);
    if (confirmed != true) return;

    setState(() => _isWithdrawing = true);

    try {
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final earningsRef = FirebaseFirestore.instance
            .collection('drivers')
            .doc(_uid)
            .collection('earnings')
            .doc('summary');

        final snap = await txn.get(earningsRef);
        final currentBalance =
            (snap.data()?['totalBalance'] as num?)?.toDouble() ?? 0;

        if (currentBalance < amount) {
          throw Exception('Insufficient balance');
        }

        // Deduct balance
        txn.update(earningsRef, {
          'totalBalance': FieldValue.increment(-amount),
        });

        // Save payout info
        txn.update(
          FirebaseFirestore.instance.collection('drivers').doc(_uid),
          {
            'payoutInfo': {
              'method': _selectedMethod,
              'network': _selectedNetwork,
              'accountNumber': _accountNumber,
              'accountName': _accountName,
            }
          },
        );

        // Create withdrawal record
        final withdrawalRef = FirebaseFirestore.instance
            .collection('withdrawals')
            .doc();
        txn.set(withdrawalRef, {
          'driverId': _uid,
          'amount': amount,
          'method': _selectedMethod,
          'network': _selectedNetwork,
          'accountNumber': _accountNumber,
          'accountName': _accountName,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      setState(() => _balance -= amount);
      _amountCtrl.clear();
      _showSuccess(amount);
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.errorColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _isWithdrawing = false);
    }
  }

  Future<bool?> _showConfirmDialog(double amount) {
    final fmt = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Withdrawal',
            style: AppTextStyles.heading4),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConfirmRow(label: 'Amount', value: fmt.format(amount)),
            _ConfirmRow(label: 'Method', value: _selectedMethod),
            if (_selectedMethod == 'Mobile Money')
              _ConfirmRow(label: 'Network', value: _selectedNetwork),
            _ConfirmRow(label: 'Account', value: _accountNumber),
            const SizedBox(height: 8),
            Text(
              'Funds arrive within 24 hours on business days.',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondaryColor),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showSuccess(double amount) {
    final fmt = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.successColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.successColor, size: 36),
            ),
            const SizedBox(height: 14),
            const Text('Withdrawal Submitted', style: AppTextStyles.heading4),
            const SizedBox(height: 6),
            Text(
              fmt.format(amount),
              style: AppTextStyles.driverStatsValue.copyWith(
                color: AppColors.successColor,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Expected within 24 business hours',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondaryColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        title: const Text('Withdraw Earnings', style: AppTextStyles.heading3),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Balance card ─────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF11C76F),
                            Color(0xFF0BA855)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.successColor
                                .withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Available Balance',
                            style: AppTextStyles.subtitle
                                .copyWith(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            fmt.format(_balance),
                            style: AppTextStyles.driverStatsValue.copyWith(
                              color: Colors.white,
                              fontSize: 32,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Min. withdrawal: ${fmt.format(_minWithdrawal)}',
                            style: AppTextStyles.caption
                                .copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),
                    const Text('Withdrawal Amount',
                        style: AppTextStyles.heading4),
                    const SizedBox(height: 12),

                    // ── Amount field ─────────────────
                    TextFormField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'))
                      ],
                      decoration: _inputDecoration('Amount (GHS)',
                          prefix: 'GHS '),
                      style: AppTextStyles.driverStatsValue
                          .copyWith(fontSize: 20),
                      validator: (v) {
                        final val = double.tryParse(v ?? '');
                        if (val == null) return 'Enter a valid amount';
                        if (val < _minWithdrawal) {
                          return 'Minimum withdrawal is GHS $_minWithdrawal';
                        }
                        if (val > _balance) return 'Insufficient balance';
                        return null;
                      },
                    ),

                    // Quick amount buttons
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [50.0, 100.0, 200.0, 500.0].map((amt) {
                        final enabled = amt <= _balance;
                        return GestureDetector(
                          onTap: enabled
                              ? () => _amountCtrl.text =
                                  amt.toStringAsFixed(0)
                              : null,
                          child: Chip(
                            label: Text('GHS ${amt.toStringAsFixed(0)}',
                                style: AppTextStyles.caption.copyWith(
                                    color: enabled
                                        ? AppColors.primaryColor
                                        : AppColors.textDisabledColor)),
                            backgroundColor: enabled
                                ? AppColors.primaryColor
                                    .withValues(alpha: 0.08)
                                : AppColors.backgroundLightColor,
                            side: BorderSide(
                              color: enabled
                                  ? AppColors.primaryColor
                                      .withValues(alpha: 0.3)
                                  : AppColors.borderColor,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),
                    const Text('Payout Method',
                        style: AppTextStyles.heading4),
                    const SizedBox(height: 12),

                    // ── Method ───────────────────────
                    DropdownButtonFormField<String>(
                      initialValue: _selectedMethod,
                      decoration: _inputDecoration('Payout Method'),
                      items: _methods
                          .map((m) =>
                              DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedMethod = v!),
                    ),

                    if (_selectedMethod == 'Mobile Money') ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedNetwork,
                        decoration: _inputDecoration('Network'),
                        items: _networks
                            .map((n) => DropdownMenuItem(
                                value: n, child: Text(n)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedNetwork = v!),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // ── Account number ───────────────
                    TextFormField(
                      initialValue: _accountNumber,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration(
                        _selectedMethod == 'Mobile Money'
                            ? 'Mobile Number'
                            : 'Account Number',
                      ),
                      onSaved: (v) => _accountNumber = v?.trim() ?? '',
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                    ),

                    const SizedBox(height: 14),

                    // ── Account name ─────────────────
                    TextFormField(
                      initialValue: _accountName,
                      decoration: _inputDecoration('Account Name'),
                      onSaved: (v) => _accountName = v?.trim() ?? '',
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                    ),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _isWithdrawing ? null : _submitWithdrawal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isWithdrawing
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text('Withdraw Funds',
                                style: AppTextStyles.buttonSmall),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(String label, {String? prefix}) =>
      InputDecoration(
        labelText: label,
        prefixText: prefix,
        labelStyle: AppTextStyles.bodySmall
            .copyWith(color: AppColors.textSecondaryColor),
        filled: true,
        fillColor: AppColors.backgroundLightColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.errorColor, width: 1.5),
        ),
      );
}

class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;
  const _ConfirmRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondaryColor)),
          Text(value,
              style: AppTextStyles.bodySmall
                  .copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
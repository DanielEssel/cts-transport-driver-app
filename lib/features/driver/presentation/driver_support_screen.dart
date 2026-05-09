// features/driver/presentation/driver_support_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class DriverSupportScreen extends StatefulWidget {
  const DriverSupportScreen({super.key});

  @override
  State<DriverSupportScreen> createState() => _DriverSupportScreenState();
}

class _DriverSupportScreenState extends State<DriverSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _selectedCategory = 'Account Issue';
  bool _isSubmitting = false;

  static const _categories = [
    'Account Issue',
    'Payment Problem',
    'Trip Dispute',
    'App Bug',
    'Other',
  ];

  static const _faqs = [
    _FAQ(
      q: 'How do I withdraw my earnings?',
      a: 'Go to Wallet → Withdraw. Minimum withdrawal is GHS 50. Funds arrive within 24 hours on business days.',
    ),
    _FAQ(
      q: 'What happens if a passenger cancels?',
      a: 'If a passenger cancels after you\'ve accepted, you receive a cancellation fee based on your distance to pickup.',
    ),
    _FAQ(
      q: 'How is my rating calculated?',
      a: 'Your rating is the average of your last 500 trip reviews. Ratings below 4.5 may affect your account standing.',
    ),
    _FAQ(
      q: 'How do I report a passenger?',
      a: 'After a trip, tap the trip in history and select "Report Passenger". Our team reviews all reports within 48h.',
    ),
    _FAQ(
      q: 'My location isn\'t updating correctly',
      a: 'Ensure location permissions are set to "Always Allow". Restart the app and check your GPS signal.',
    ),
  ];

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('supportTickets').add({
        'driverId': uid,
        'category': _selectedCategory,
        'subject': _subjectCtrl.text.trim(),
        'message': _messageCtrl.text.trim(),
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
        'userType': 'driver',
      });

      if (!mounted) return;
      _subjectCtrl.clear();
      _messageCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Ticket submitted. We\'ll respond within 24 hours.'),
            ],
          ),
          backgroundColor: AppColors.successColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit. Please try again.'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse('https://wa.me/233200000000');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _callSupport() async {
    final uri = Uri(scheme: 'tel', path: '+233200000000');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        title: const Text('Help & Support', style: AppTextStyles.heading3),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Quick contact ──────────────────────
          const _SectionHeader(title: 'Contact Us'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ContactCard(
                  icon: Icons.phone_rounded,
                  label: 'Call Us',
                  subtitle: '24/7 Support',
                  color: AppColors.successColor,
                  onTap: _callSupport,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ContactCard(
                  icon: Icons.chat_rounded,
                  label: 'WhatsApp',
                  subtitle: 'Chat Now',
                  color: const Color(0xFF25D366),
                  onTap: _openWhatsApp,
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ── FAQs ───────────────────────────────
          const _SectionHeader(title: 'Frequently Asked Questions'),
          const SizedBox(height: 12),
          ..._faqs.map((faq) => _FAQTile(faq: faq)),

          const SizedBox(height: 28),

          // ── Submit ticket ──────────────────────
          const _SectionHeader(title: 'Submit a Ticket'),
          const SizedBox(height: 4),
          Text(
            'Can\'t find your answer? Send us a message.',
            style: AppTextStyles.subtitle
                .copyWith(color: AppColors.textSecondaryColor),
          ),
          const SizedBox(height: 16),

          Form(
            key: _formKey,
            child: Column(
              children: [
                // Category dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: _inputDecoration('Category'),
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedCategory = v ?? _categories[0]),
                ),
                const SizedBox(height: 14),

                // Subject
                TextFormField(
                  controller: _subjectCtrl,
                  decoration: _inputDecoration('Subject'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),

                // Message
                TextFormField(
                  controller: _messageCtrl,
                  decoration: _inputDecoration('Describe your issue'),
                  maxLines: 5,
                  validator: (v) => (v == null || v.trim().length < 20)
                      ? 'Please provide more detail (min 20 chars)'
                      : null,
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitTicket,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Submit Ticket',
                            style: AppTextStyles.buttonSmall),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle:
            AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryColor),
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
      );
}

// ── Supporting widgets ─────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) =>
      Text(title, style: AppTextStyles.heading4);
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ContactCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: AppTextStyles.bodySmall
                    .copyWith(fontWeight: FontWeight.w700)),
            Text(subtitle,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondaryColor)),
          ],
        ),
      ),
    );
  }
}

class _FAQ {
  final String q;
  final String a;
  const _FAQ({required this.q, required this.a});
}

class _FAQTile extends StatefulWidget {
  final _FAQ faq;
  const _FAQTile({required this.faq});

  @override
  State<_FAQTile> createState() => _FAQTileState();
}

class _FAQTileState extends State<_FAQTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.backgroundLightColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(widget.faq.q,
                style: AppTextStyles.bodySmall
                    .copyWith(fontWeight: FontWeight.w600)),
            trailing: AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 250),
              child: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondaryColor),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          ),
          if (_expanded)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                widget.faq.a,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondaryColor, height: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}
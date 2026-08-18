// lib/features/driver/presentation/widgets/promo_banner.dart
//
// Shows the highest-priority active promotion targeted at drivers (or all
// users). Reads the exact schema the admin panel writes:
//   title, subtitle, backgroundColor (hex), imageUrl, targetAudience,
//   active (bool), priority (int).
//
// The composite index (active + targetAudience + priority) already exists
// in Firestore, so this query resolves; if no promo matches, nothing renders.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DriverPromo {
  final String title;
  final String subtitle;
  final String backgroundColor; // hex, e.g. '#16a34a'
  final String imageUrl;

  const DriverPromo({
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
    required this.imageUrl,
  });

  factory DriverPromo.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return DriverPromo(
      title: d['title'] as String? ?? '',
      subtitle: d['subtitle'] as String? ?? '',
      backgroundColor: d['backgroundColor'] as String? ?? '#16A34A',
      imageUrl: d['imageUrl'] as String? ?? '',
    );
  }
}

// Highest-priority active promo for drivers or everyone.
final driverPromoProvider = StreamProvider.autoDispose<DriverPromo?>((ref) {
  return FirebaseFirestore.instance
      .collection('promotions')
      .where('active', isEqualTo: true)
      .where('targetAudience', whereIn: ['all', 'drivers'])
      .orderBy('priority', descending: true)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isNotEmpty ? DriverPromo.fromDoc(s.docs.first) : null);
});

Color _hexToColor(String hex) {
  final cleaned = hex.replaceAll('#', '').trim();
  final value = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
  return Color(int.tryParse(value, radix: 16) ?? 0xFF16A34A);
}

class DriverPromoBanner extends ConsumerWidget {
  const DriverPromoBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(driverPromoProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (promo) {
        if (promo == null) return const SizedBox.shrink();
        final bg = _hexToColor(promo.backgroundColor);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: bg.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      promo.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    if (promo.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        promo.subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (promo.imageUrl.isNotEmpty) ...[
                const SizedBox(width: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    promo.imageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const SizedBox(width: 60, height: 60),
                    loadingBuilder: (ctx, child, progress) =>
                        progress == null
                            ? child
                            : const SizedBox(
                                width: 60,
                                height: 60,
                                child: Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  ),
                                ),
                              ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../jobs/data/mock_data.dart';
import '../../../../app/app_theme.dart';
import '../../../trips/models/trip_model.dart';


class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  late List<TripRecord> _trips;
  String _filter = 'All'; // All, Rides, Deliveries

  @override
  void initState() {
    super.initState();
    _trips = MockDataService.getMockTripHistory();
  }

  List<TripRecord> get _filtered {
    if (_filter == 'Rides') return _trips.where((t) => !t.isDelivery).toList();
    if (_filter == 'Deliveries') return _trips.where((t) => t.isDelivery).toList();
    return _trips;
  }

  double get _totalEarnings =>
      _filtered.fold(0.0, (s, t) => s + t.fare);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Trip History'),
        backgroundColor: AppTheme.surface,
      ),
      body: Column(
        children: [
          // ── Summary banner ──
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryStat(
                    label: 'Total Trips',
                    value: '${_filtered.length}',
                    icon: Icons.route_rounded,
                  ),
                ),
                Container(
                    width: 1,
                    height: 40,
                    color: AppTheme.primary.withValues(alpha: 0.2)),
                Expanded(
                  child: _SummaryStat(
                    label: 'Total Earned',
                    value:
                        'GH₵ ${_totalEarnings.toStringAsFixed(2)}',
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                ),
              ],
            ),
          ),

          // ── Filter chips ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['All', 'Rides', 'Deliveries'].map((f) {
                final active = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: active
                            ? AppTheme.primary
                            : AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active
                              ? AppTheme.primary
                              : AppTheme.divider,
                        ),
                      ),
                      child: Text(
                        f,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? Colors.white
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // ── Trip list ──
          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No trips found.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) =>
                        _TripTile(trip: _filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TripTile extends StatelessWidget {
  final TripRecord trip;

  const _TripTile({required this.trip});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d · h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: trip.isDelivery
                      ? AppTheme.infoLight
                      : AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  trip.isDelivery
                      ? Icons.inventory_2_rounded
                      : Icons.person_rounded,
                  color: trip.isDelivery
                      ? AppTheme.info
                      : AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.customerName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      fmt.format(trip.completedAt),
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
                    'GH₵ ${trip.fare.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 12, color: AppTheme.accent),
                      const SizedBox(width: 2),
                      Text(
                        trip.driverRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppTheme.divider),
          const SizedBox(height: 10),
          const SizedBox(height: 8),
          Row(
            children: [
              StatusChip(
                label: trip.isDelivery ? '📦 Delivery' : '🏍️ Ride',
                color:
                    trip.isDelivery ? AppTheme.info : AppTheme.primary,
              ),
              const SizedBox(width: 8),
              StatusChip(
                label: '${trip.distanceKm.toStringAsFixed(1)} km',
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primary, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

// Add this class if StatusChip is not in shared_widgets.dart
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const StatusChip({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
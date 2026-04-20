import 'package:flutter/material.dart';
import '../../driver/models/driver_type.dart';
import '../models/delivery_request.dart';
import '../../../app/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';

enum DeliveryPhase {
  enRouteToPickup,
  parcelPickedUp,
  enRouteToDropoff,
  completed,
}

class ActiveDeliveryScreen extends StatefulWidget {
  final DeliveryRequest request;
  final DriverType driverType;

  const ActiveDeliveryScreen({
    super.key,
    required this.request,
    required this.driverType,
  });

  @override
  State<ActiveDeliveryScreen> createState() =>
      _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen> {
  DeliveryPhase _phase = DeliveryPhase.enRouteToPickup;

  void _advancePhase() {
    setState(() {
      switch (_phase) {
        case DeliveryPhase.enRouteToPickup:
          _phase = DeliveryPhase.parcelPickedUp;
          break;
        case DeliveryPhase.parcelPickedUp:
          _phase = DeliveryPhase.enRouteToDropoff;
          break;
        case DeliveryPhase.enRouteToDropoff:
          _phase = DeliveryPhase.completed;
          break;
        case DeliveryPhase.completed:
          break;
      }
    });
  }

  String get _phaseTitle {
    switch (_phase) {
      case DeliveryPhase.enRouteToPickup:
        return 'En Route to Pickup';
      case DeliveryPhase.parcelPickedUp:
        return 'Parcel Picked Up';
      case DeliveryPhase.enRouteToDropoff:
        return 'En Route to Drop-off';
      case DeliveryPhase.completed:
        return 'Completed';
    }
  }

  String get _ctaLabel {
    switch (_phase) {
      case DeliveryPhase.enRouteToPickup:
        return 'Arrived – Collect Parcel';
      case DeliveryPhase.parcelPickedUp:
        return 'Start Delivery';
      case DeliveryPhase.enRouteToDropoff:
        return 'Mark as Delivered';
      case DeliveryPhase.completed:
        return 'Back to Home';
    }
  }

  int get _stepIndex {
    switch (_phase) {
      case DeliveryPhase.enRouteToPickup:
        return 0;
      case DeliveryPhase.parcelPickedUp:
        return 1;
      case DeliveryPhase.enRouteToDropoff:
        return 2;
      case DeliveryPhase.completed:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == DeliveryPhase.completed) {
      return _CompletedScreen(
        fare: widget.request.fare,
        onDone: () => Navigator.popUntil(context, (r) => r.isFirst),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_phaseTitle),
        backgroundColor: AppTheme.surface,
      ),
      body: Column(
        children: [
          // ── Progress stepper ──
          _DeliveryStepBar(currentStep: _stepIndex),

          // ── Map placeholder ──
          _MapPlaceholder(
            phase: _phase,
            pickupAddress: widget.request.pickupAddress,
            dropoffAddress: widget.request.dropoffAddress,
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Parcel + contact card
                  _ParcelCard(
                    request: widget.request,
                    phase: _phase,
                    driverType: widget.driverType,
                  ),
                  const SizedBox(height: 16),
                  // Route info
                  _RouteCard(request: widget.request),
                  const SizedBox(height: 20),
                  // CTA
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _advancePhase,
                      icon: Icon(_phaseIcon),
                      label: Text(_ctaLabel),
                      style: ElevatedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  if (_phase == DeliveryPhase.enRouteToPickup)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.danger,
                            side: const BorderSide(
                                color: AppTheme.danger),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                          ),
                          child: const Text('Cancel Delivery'),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData get _phaseIcon {
    switch (_phase) {
      case DeliveryPhase.enRouteToPickup:
        return Icons.inventory_2_rounded;
      case DeliveryPhase.parcelPickedUp:
        return Icons.local_shipping_rounded;
      case DeliveryPhase.enRouteToDropoff:
        return Icons.check_circle_rounded;
      default:
        return Icons.home_rounded;
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _DeliveryStepBar extends StatelessWidget {
  final int currentStep;

  const _DeliveryStepBar({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const steps = ['Pickup', 'Collected', 'En Route', 'Delivered'];
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            // Connector line
            final stepIndex = (i - 1) ~/ 2;
            return Expanded(
              child: Container(
                height: 2,
                color: stepIndex < currentStep
                    ? AppTheme.primary
                    : AppTheme.divider,
              ),
            );
          }
          final stepIndex = i ~/ 2;
          final done = stepIndex < currentStep;
          final active = stepIndex == currentStep;
          return Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? AppTheme.primary
                      : active
                          ? AppTheme.primaryLight
                          : AppTheme.divider,
                  border: active
                      ? Border.all(
                          color: AppTheme.primary, width: 2)
                      : null,
                ),
                child: Icon(
                  done
                      ? Icons.check_rounded
                      : Icons.circle,
                  size: done ? 16 : 10,
                  color: done
                      ? Colors.white
                      : active
                          ? AppTheme.primary
                          : AppTheme.textHint,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                steps[stepIndex],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: active || done
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: active || done
                      ? AppTheme.primary
                      : AppTheme.textHint,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  final DeliveryPhase phase;
  final String pickupAddress;
  final String dropoffAddress;

  const _MapPlaceholder({
    required this.phase,
    required this.pickupAddress,
    required this.dropoffAddress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accent.withOpacity(0.1),
            AppTheme.primaryLight,
          ],
        ),
      ),
      child: Stack(
        children: [
          CustomPaint(
            size: const Size(double.infinity, 160),
            painter: _GridPainter(),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_shipping_rounded,
                    size: 36, color: AppTheme.primary),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    phase == DeliveryPhase.enRouteToDropoff
                        ? '→ $dropoffAddress'
                        : '→ $pickupAddress',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
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

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primary.withOpacity(0.06)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _ParcelCard extends StatelessWidget {
  final DeliveryRequest request;
  final DeliveryPhase phase;
  final DriverType driverType;

  const _ParcelCard({
    required this.request,
    required this.phase,
    required this.driverType,
  });

  @override
  Widget build(BuildContext context) {
    final isDropoff = phase == DeliveryPhase.enRouteToDropoff;
    final contact =
        isDropoff ? request.recipientName : request.senderName;
    final phone =
        isDropoff ? request.recipientPhone : request.senderPhone;
    final contactLabel = isDropoff ? 'Recipient' : 'Sender';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          // Parcel info row
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    request.parcelType.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.parcelType.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        WeightTierBadge(label: request.weightTier.label),
                        if (request.isFragile) ...[
                          const SizedBox(width: 6),
                          const StatusChip(
                            label: '⚠ Fragile',
                            color: AppTheme.warning,
                          ),
                        ],
                        if (request.needsHelpers &&
                            (driverType == DriverType.aboboya ||
                                driverType == DriverType.miniTruck)) ...[
                          const SizedBox(width: 6),
                          const StatusChip(
                            label: '👥 Helpers',
                            color: AppTheme.info,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppTheme.divider),
          const SizedBox(height: 14),
          // Contact info
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppTheme.infoLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded,
                    color: AppTheme.info, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$contactLabel: $contact',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      phone,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone_rounded,
                    color: AppTheme.primary, size: 18),
              ),
            ],
          ),
          if (request.specialInstructions != null &&
              request.specialInstructions!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warningLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '📝 ${request.specialInstructions}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.warning,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final DeliveryRequest request;

  const _RouteCard({required this.request});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          RouteAddressColumn(
            pickup: request.pickupAddress,
            dropoff: request.dropoffAddress,
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InfoRow(
                  icon: Icons.attach_money_rounded,
                  label: 'Fare',
                  value: 'GH₵ ${request.fare.toStringAsFixed(2)}',
                  iconColor: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InfoRow(
                  icon: Icons.straighten_rounded,
                  label: 'Distance',
                  value: '${request.distanceKm.toStringAsFixed(1)} km',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompletedScreen extends StatelessWidget {
  final double fare;
  final VoidCallback onDone;

  const _CompletedScreen({required this.fare, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.inventory_rounded,
                      size: 50, color: AppTheme.primary),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Delivery Completed!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Parcel delivered successfully.\nEarnings added to your wallet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppTheme.primary.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text('You earned',
                          style: TextStyle(
                              color: AppTheme.primaryDark,
                              fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(
                        'GH₵ ${fare.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onDone,
                    style: ElevatedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('Back to Home'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
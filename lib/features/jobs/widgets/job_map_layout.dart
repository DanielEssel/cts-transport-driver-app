// lib/features/jobs/widgets/job_map_layout.dart
//
// The map-first layout shared by the Ride, Delivery and Gas tracking
// screens:
//
//   • the map fills the screen and is built once (dragging the sheet never
//     rebuilds or recreates it)
//   • back / call float over the map, clear of the status bar
//   • a draggable sheet snaps between a compact summary (map nearly full
//     screen), a middle position, and the full job details
//   • re-centre rides just above the sheet
//   • the stage's actions stay pinned below the sheet, so dragging can never
//     press them and they are never scrolled out of reach

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../app/app_theme.dart';
import '../domain/job_stage_plan.dart';
import 'job_stage_panel.dart';

class JobMapLayout extends StatefulWidget {
  /// Builds the map. [padding] keeps markers, route framing and the map's
  /// own logo clear of the sheet.
  final Widget Function(BuildContext context, EdgeInsets padding) mapBuilder;

  final JobStagePlan plan;

  /// Where this stage is about, e.g. ('Pickup', '12 Ring Rd'). Shown on one
  /// line in the compact summary.
  final String? destinationLabel;
  final String? destination;

  /// Only pass a value backed by real route data.
  final String? eta;

  /// The job's detail cards, shown below the stage progress.
  final List<Widget> details;

  /// The stage's actions, pinned at the bottom.
  final Widget actions;

  final VoidCallback onBack;
  final VoidCallback? onRecenter;
  final VoidCallback? onCall;
  final String callLabel;

  const JobMapLayout({
    super.key,
    required this.mapBuilder,
    required this.plan,
    required this.details,
    required this.actions,
    required this.onBack,
    this.destinationLabel,
    this.destination,
    this.eta,
    this.onRecenter,
    this.onCall,
    this.callLabel = 'Call',
  });

  /// The summary keeps at most this text scale so the collapsed sheet stays
  /// compact; the details below keep the driver's full text size.
  static const summaryMaxTextScale = 1.3;

  @override
  State<JobMapLayout> createState() => _JobMapLayoutState();
}

class _JobMapLayoutState extends State<JobMapLayout> {
  final _sheet = DraggableScrollableController();

  static const _animation = Duration(milliseconds: 280);

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  double _size(double fallback) => _sheet.isAttached ? _sheet.size : fallback;

  void _animateTo(double size) {
    if (!_sheet.isAttached) return;
    _sheet.animateTo(size, duration: _animation, curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scale = media.textScaler
            .clamp(maxScaleFactor: JobMapLayout.summaryMaxTextScale)
            .scale(100) /
        100;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        bottomNavigationBar: JobActionFooter(child: widget.actions),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            final s = _SheetSizes.of(
              height: h,
              topInset: media.padding.top,
              textScale: scale,
            );
            final details = _buildDetails();

            return Stack(
              children: [
                Positioned.fill(
                  child: widget.mapBuilder(
                    context,
                    EdgeInsets.only(top: media.padding.top, bottom: s.mid * h),
                  ),
                ),

                // ── Floating controls over the map ──
                Positioned(
                  top: media.padding.top + 12,
                  left: 16,
                  child: JobMapButton(
                    key: const ValueKey('job-map-back'),
                    icon: Icons.arrow_back_rounded,
                    label: 'Back',
                    onTap: widget.onBack,
                  ),
                ),
                if (widget.onCall != null)
                  Positioned(
                    top: media.padding.top + 12,
                    right: 16,
                    child: JobMapButton(
                      key: const ValueKey('job-map-call'),
                      icon: Icons.phone_rounded,
                      label: widget.callLabel,
                      color: AppTheme.primaryDark,
                      onTap: widget.onCall!,
                    ),
                  ),
                if (widget.onRecenter != null)
                  // Only this button follows the sheet as it moves.
                  AnimatedBuilder(
                    animation: _sheet,
                    builder: (context, child) {
                      final size = _size(s.initial);
                      final hidden = size > s.mid + 0.02;
                      return Positioned(
                        right: 16,
                        bottom: size * h + 12,
                        child: IgnorePointer(
                          ignoring: hidden,
                          child: AnimatedOpacity(
                            opacity: hidden ? 0 : 1,
                            duration: const Duration(milliseconds: 150),
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: JobMapButton(
                      key: const ValueKey('job-map-recenter'),
                      icon: Icons.my_location_rounded,
                      label: 'Re-centre map',
                      color: AppTheme.primaryDark,
                      onTap: widget.onRecenter!,
                    ),
                  ),

                // ── Draggable job sheet ──
                DraggableScrollableSheet(
                  controller: _sheet,
                  initialChildSize: s.initial,
                  minChildSize: s.min,
                  maxChildSize: s.max,
                  snap: true,
                  snapSizes: [s.mid],
                  builder: (context, scrollController) {
                    return DecoratedBox(
                      key: const ValueKey('job-sheet'),
                      decoration: const BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(24)),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x1F000000),
                            blurRadius: 20,
                            offset: Offset(0, -6),
                          ),
                        ],
                      ),
                      // One scroll view: the sheet drags until fully open,
                      // then the details scroll. No competing gestures.
                      child: ListView(
                        controller: scrollController,
                        padding: EdgeInsets.zero,
                        children: [
                          // The sheet reuses what its builder returns, so
                          // read its live size here, not in the builder.
                          AnimatedBuilder(
                            animation: _sheet,
                            builder: (context, _) {
                              final size = _size(s.initial);
                              final atMax = size >= s.max - 0.02;
                              final atMin = size <= s.min + 0.02;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _SheetHandle(
                                    atMin: atMin,
                                    onTap: () =>
                                        _animateTo(atMin ? s.mid : s.min),
                                  ),
                                  MediaQuery.withClampedTextScaling(
                                    maxScaleFactor:
                                        JobMapLayout.summaryMaxTextScale,
                                    child: JobSheetSummary(
                                      plan: widget.plan,
                                      destinationLabel: widget.destinationLabel,
                                      destination: widget.destination,
                                      eta: widget.eta,
                                      expanded: atMax,
                                      onToggle: () =>
                                          _animateTo(atMax ? s.min : s.max),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          details,
                        ],
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetails() {
    final plan = widget.plan;
    return Padding(
      key: const ValueKey('job-sheet-details'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1, color: AppTheme.divider),
          const SizedBox(height: 16),
          Text(
            plan.hint,
            style: const TextStyle(
                fontSize: 15, height: 1.4, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          JobStepProgress(
            steps: plan.steps,
            current: plan.stepIndex,
            showCaption: false,
          ),
          const SizedBox(height: 20),
          ...widget.details,
        ],
      ),
    );
  }
}

/// Snap positions as fractions of the space above the pinned actions.
class _SheetSizes {
  final double min;
  final double mid;
  final double max;

  const _SheetSizes(this.min, this.mid, this.max);

  double get initial => mid;

  /// Height of the handle plus the compact summary at [textScale].
  static double collapsedHeight(double textScale) => 56 + 72 * textScale;

  factory _SheetSizes.of({
    required double height,
    required double topInset,
    required double textScale,
  }) {
    if (height <= 0) return const _SheetSizes(0.2, 0.45, 0.9);
    final min = (collapsedHeight(textScale) / height).clamp(0.1, 0.45);
    // Fully open, the sheet stops below the floating back button.
    final max = ((height - topInset - 72) / height).clamp(min + 0.2, 0.95);
    final mid = 0.48.clamp(min + 0.08, max - 0.08);
    return _SheetSizes(min, mid, max);
  }
}

class _SheetHandle extends StatelessWidget {
  final bool atMin;
  final VoidCallback onTap;

  const _SheetHandle({required this.atMin, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: atMin ? 'Show job details' : 'Show more of the map',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        key: const ValueKey('job-sheet-handle'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 28,
          child: Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: AppTheme.textHint,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The compact summary visible even when the map is expanded: the stage,
/// its one instruction and where it is about. No contact details.
class JobSheetSummary extends StatelessWidget {
  final JobStagePlan plan;
  final String? destinationLabel;
  final String? destination;
  final String? eta;
  final bool expanded;
  final VoidCallback onToggle;

  const JobSheetSummary({
    super.key,
    required this.plan,
    required this.expanded,
    required this.onToggle,
    this.destinationLabel,
    this.destination,
    this.eta,
  });

  @override
  Widget build(BuildContext context) {
    final where = destination == null || destination!.isEmpty
        ? null
        : destinationLabel == null
            ? destination!
            : '$destinationLabel · $destination';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'STEP ${plan.stepIndex + 1} OF ${plan.steps.length}'
                    ' · ${plan.steps[plan.stepIndex].toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ),
                if (eta != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    key: const ValueKey('job-sheet-eta'),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      eta!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryDeep,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        plan.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          height: 1.3,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    if (where != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.place_rounded,
                              size: 16, color: AppTheme.textSecondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              where,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.3,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                key: const ValueKey('job-sheet-toggle'),
                onPressed: onToggle,
                tooltip: expanded ? 'Show map' : 'Show job details',
                icon: Icon(
                  expanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_up_rounded,
                  size: 28,
                ),
                style: IconButton.styleFrom(
                  foregroundColor: AppTheme.textPrimary,
                  backgroundColor: AppTheme.primaryLight,
                  minimumSize: const Size(48, 48),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Round floating button used over the map.
class JobMapButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const JobMapButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppTheme.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: label,
        child: Material(
          color: AppTheme.surface,
          shape: const CircleBorder(),
          elevation: 3,
          shadowColor: Colors.black38,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(icon, color: color, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

/// Moves [controller]'s camera to show all of [points].
void fitMapTo(GoogleMapController? controller, List<LatLng> points) {
  if (controller == null || points.isEmpty) return;
  final minLat = points.map((p) => p.latitude).reduce(min);
  final maxLat = points.map((p) => p.latitude).reduce(max);
  final minLng = points.map((p) => p.longitude).reduce(min);
  final maxLng = points.map((p) => p.longitude).reduce(max);
  // A single point (or two on top of each other) has no usable bounds.
  if ((maxLat - minLat).abs() < 0.0001 && (maxLng - minLng).abs() < 0.0001) {
    controller.animateCamera(CameraUpdate.newLatLngZoom(points.first, 16));
    return;
  }
  controller.animateCamera(CameraUpdate.newLatLngBounds(
    LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    ),
    60,
  ));
}

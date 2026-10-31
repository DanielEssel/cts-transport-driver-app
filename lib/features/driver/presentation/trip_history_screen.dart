// features/driver/presentation/trip_history_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/driver_home_providers.dart';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../jobs/data/driver_jobs_repository.dart'; // adjust path to where you put it
import '../../../app/app_theme.dart';
import '../../../shared/widgets/finance_ui.dart';

// ─── Models ────────────────────────────────────────────────────────────────────
enum TripStatus { completed, cancelled, ongoing }

class TripSummary {
  final String id;
  final JobType jobType;
  final String passengerName;
  final String passengerAvatar;
  final String pickupAddress;
  final String dropoffAddress;
  final DateTime dateTime;
  final double distanceKm;
  final int durationMinutes;
  final double fareGhs;
  final double rating;
  final TripStatus status;
  final String paymentMethod;

  const TripSummary({
    required this.id,
    required this.jobType,
    required this.passengerName,
    required this.passengerAvatar,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.dateTime,
    required this.distanceKm,
    required this.durationMinutes,
    required this.fareGhs,
    required this.rating,
    required this.status,
    required this.paymentMethod,
  });

  bool get isGas => jobType == JobType.gas;
  bool get isDelivery => jobType == JobType.delivery;
  bool get isRide => jobType == JobType.ride;
}

// ─── Main Screen ───────────────────────────────────────────────────────────────
class TripHistoryScreen extends ConsumerStatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  ConsumerState<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends ConsumerState<TripHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<TripSummary> _allTrips = [];
  bool _loading = true;
  bool _hasError = false;
  String _searchQuery = '';
  bool _showSearch = false;
  bool _isDeliveryDriver = false;

  static const _tabs = ['All', 'Completed', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadTrips();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTrips({bool refresh = false}) async {
    if (refresh) {
      setState(() => _loading = true);
    }

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) {
        setState(() {
          _loading = false;
          _hasError = true;
        });
        return;
      }

      // Use the existing Riverpod driver profile provider so the history
      // screen follows the driver's actual role.
      final profile = await ref.read(driverProfileProvider(uid).future);

      final isDeliveryDriver = profile.isDelivery;

      final jobs = await DriverJobsRepository(
        FirebaseFirestore.instance,
      ).fetchHistory(uid);

      // Hailing drivers see rides only.
      // Delivery drivers see BOTH normal deliveries and gas orders.
      final filteredJobs = isDeliveryDriver
          ? jobs.where(
              (job) => job.type == JobType.delivery || job.type == JobType.gas,
            )
          : jobs.where((job) => job.type == JobType.ride);

      final trips = filteredJobs.map(_jobToTripSummary).toList();

      if (!mounted) return;

      setState(() {
        _isDeliveryDriver = isDeliveryDriver;
        _allTrips = trips;
        _loading = false;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
  }

  TripSummary _jobToTripSummary(JobSummary job) {
    return TripSummary(
      id: job.id,
      jobType: job.type,
      passengerName: job.counterparty,
      passengerAvatar: job.counterpartyInitials,
      pickupAddress: job.pickupAddress,
      dropoffAddress: job.dropoffAddress,
      dateTime: job.dateTime,
      distanceKm: job.distanceKm,
      durationMinutes: job.durationMinutes,
      fareGhs: job.fareGhs,
      rating: job.rating,
      status: job.outcome == JobOutcome.cancelled
          ? TripStatus.cancelled
          : TripStatus.completed,
      paymentMethod: job.paymentMethod,
    );
  }

  List<TripSummary> get _filtered {
    var trips = _allTrips;

    // Tab filter
    if (_tabController.index == 1) {
      trips = trips.where((t) => t.status == TripStatus.completed).toList();
    } else if (_tabController.index == 2) {
      trips = trips.where((t) => t.status == TripStatus.cancelled).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      trips = trips
          .where((t) =>
              t.passengerName.toLowerCase().contains(q) ||
              t.dropoffAddress.toLowerCase().contains(q) ||
              t.pickupAddress.toLowerCase().contains(q) ||
              (t.isGas && 'gas'.contains(q)) ||
              (t.isDelivery && 'delivery'.contains(q)) ||
              (t.isRide && 'ride'.contains(q)))
          .toList();
    }

    return trips;
  }

  // ── Stats ──────────────────────────────────────────────────────────────────
  double get _totalEarnings => _allTrips
      .where((t) => t.status == TripStatus.completed)
      .fold(0, (s, t) => s + t.fareGhs);

  double get _totalDistance => _allTrips
      .where((t) => t.status == TripStatus.completed)
      .fold(0, (s, t) => s + t.distanceKm);

  int get _completedCount =>
      _allTrips.where((t) => t.status == TripStatus.completed).length;

  // ─────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: RefreshIndicator(
          color: AppTheme.primaryDark,
          onRefresh: () => _loadTrips(refresh: true),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _AppBar(
                isDeliveryDriver: _isDeliveryDriver,
                showSearch: _showSearch,
                searchController: _searchController,
                onSearchToggle: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) {
                      _searchController.clear();
                      _searchQuery = '';
                    }
                  });
                },
                onSearchChanged: (v) => setState(() => _searchQuery = v),
              ),
              if (!_loading && !_hasError) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: HistorySummaryCard(
                      totalEarnings: _totalEarnings,
                      totalDistance: _totalDistance,
                      completedCount: _completedCount,
                      totalCount: _allTrips.length,
                      isDeliveryDriver: _isDeliveryDriver,
                    ),
                  ),
                ),
                _TabBar(controller: _tabController, tabs: _tabs),
              ],
              if (_loading)
                const _ShimmerList()
              else if (_hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: FinanceStateView(
                    icon: Icons.wifi_off_rounded,
                    title: _isDeliveryDriver
                        ? 'Could not load orders'
                        : 'Could not load trips',
                    message: 'Check your connection and try again.',
                    isError: true,
                    onRetry: () => _loadTrips(refresh: true),
                  ),
                )
              else if (_filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Builder(builder: (_) {
                    final copy = historyEmptyCopy(
                      query: _searchQuery,
                      isDeliveryDriver: _isDeliveryDriver,
                      tabIndex: _tabController.index,
                      hasAny: _allTrips.isNotEmpty,
                    );
                    return FinanceStateView(
                      icon: _searchQuery.isNotEmpty
                          ? Icons.search_off_rounded
                          : _isDeliveryDriver
                              ? Icons.inventory_2_outlined
                              : Icons.directions_car_outlined,
                      title: copy.title,
                      message: copy.message,
                    );
                  }),
                )
              else
                _TripList(trips: _filtered),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty-state copy. [tabIndex] follows `_tabs` (All, Completed, Cancelled);
/// [hasAny] is whether any job loaded at all, before filtering.
({String title, String message}) historyEmptyCopy({
  required String query,
  required bool isDeliveryDriver,
  required int tabIndex,
  required bool hasAny,
}) {
  final noun = isDeliveryDriver ? 'orders' : 'trips';
  if (query.isNotEmpty) {
    return (title: 'No results found', message: 'Try a different search term');
  }
  if (hasAny && tabIndex == 1) {
    return (
      title: 'No completed $noun',
      message: 'Completed $noun in your recent history will appear here.',
    );
  }
  if (hasAny && tabIndex == 2) {
    return (
      title: 'No cancelled $noun',
      message: 'Cancelled $noun in your recent history will appear here.',
    );
  }
  return (
    title: 'No $noun yet',
    message: isDeliveryDriver
        ? 'Your completed deliveries and gas orders will appear here'
        : 'Your completed trips will appear here',
  );
}

// ─── App Bar ───────────────────────────────────────────────────────────────────
class _AppBar extends StatelessWidget {
  final bool showSearch;
  final TextEditingController searchController;
  final VoidCallback onSearchToggle;
  final ValueChanged<String> onSearchChanged;
  final bool isDeliveryDriver;

  const _AppBar({
    required this.showSearch,
    required this.searchController,
    required this.onSearchToggle,
    required this.onSearchChanged,
    required this.isDeliveryDriver,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: const Border(bottom: BorderSide(color: AppTheme.divider)),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        tooltip: 'Back',
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(isDeliveryDriver ? 'Order History' : 'Trip History'),
      actions: [
        IconButton(
          tooltip: showSearch ? 'Close search' : 'Search',
          icon: Icon(showSearch ? Icons.close_rounded : Icons.search_rounded),
          onPressed: onSearchToggle,
        ),
        const SizedBox(width: 4),
      ],
      bottom: showSearch
          ? PreferredSize(
              preferredSize: const Size.fromHeight(64),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  autofocus: true,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: isDeliveryDriver
                        ? 'Search by customer or location…'
                        : 'Search by passenger or location…',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

// ─── Summary ───────────────────────────────────────────────────────────────────
class HistorySummaryCard extends StatelessWidget {
  final double totalEarnings;
  final double totalDistance;
  final int completedCount;
  final int totalCount;
  final bool isDeliveryDriver;

  const HistorySummaryCard({
    super.key,
    required this.totalEarnings,
    required this.totalDistance,
    required this.completedCount,
    required this.totalCount,
    required this.isDeliveryDriver,
  });

  @override
  Widget build(BuildContext context) => FinanceHeroCard(
        key: const ValueKey('history-summary-card'),
        // The sum of fares on the completed jobs listed, not wallet money.
        label: 'Completed fares',
        amount: formatGhs(totalEarnings),
        caption: 'Total fares on the completed ${isDeliveryDriver ? 'orders' : 'trips'} '
            'listed below.',
        stats: [
          FinanceHeroStat(
              isDeliveryDriver ? 'Total orders' : 'Total trips', '$totalCount'),
          FinanceHeroStat('Completed', '$completedCount'),
          FinanceHeroStat('Distance', '${totalDistance.toStringAsFixed(0)} km'),
        ],
      );
}

// ─── Tab Bar ───────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final TabController controller;
  final List<String> tabs;

  const _TabBar({required this.controller, required this.tabs});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.divider),
          ),
          child: TabBar(
            controller: controller,
            isScrollable: false,
            dividerColor: Colors.transparent,
            indicator: BoxDecoration(
              color: AppTheme.primaryDark,
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: AppTheme.onPrimary,
            unselectedLabelColor: AppTheme.textSecondary,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            tabs: tabs.map((t) => Tab(text: t, height: 40)).toList(),
          ),
        ),
      ),
    );
  }
}

// ─── Trip List ─────────────────────────────────────────────────────────────────
class _TripList extends StatelessWidget {
  final List<TripSummary> trips;

  const _TripList({required this.trips});

  @override
  Widget build(BuildContext context) {
    // Group by date
    final groups = <String, List<TripSummary>>{};
    for (final trip in trips) {
      final key = _dateLabel(trip.dateTime);
      groups.putIfAbsent(key, () => []).add(trip);
    }

    final sections = groups.entries.toList();

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final section = sections[i];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DateHeader(label: section.key),
                ...section.value.map((t) => HistoryJobCard(trip: t)),
              ],
            );
          },
          childCount: sections.length,
        ),
      ),
    );
  }

  static String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('EEEE, d MMMM').format(dt);
  }
}

class _DateHeader extends StatelessWidget {
  final String label;
  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 8),
        child: Semantics(
          header: true,
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
      );
}

// ─── Trip Card ─────────────────────────────────────────────────────────────────
class HistoryJobCard extends StatelessWidget {
  final TripSummary trip;

  const HistoryJobCard({super.key, required this.trip});

  String get _personLabel {
    if (trip.isGas) return 'Gas order';
    if (trip.isDelivery) return 'Customer';
    return 'Passenger';
  }

  ServiceTone get _service {
    if (trip.isGas) return ServiceTone.gas;
    if (trip.isDelivery) return ServiceTone.delivery;
    return ServiceTone.ride;
  }

  ({String label, StatusTone tone, IconData icon}) get _status =>
      switch (trip.status) {
        TripStatus.completed => (
            label: 'Completed',
            tone: StatusTone.success,
            icon: Icons.check_circle_rounded,
          ),
        TripStatus.cancelled => (
            label: 'Cancelled',
            tone: StatusTone.neutral,
            icon: Icons.cancel_rounded,
          ),
        TripStatus.ongoing => (
            label: 'Ongoing',
            tone: StatusTone.pending,
            icon: Icons.timelapse_rounded,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final service = serviceStyle(_service);
    final status = _status;
    final cancelled = trip.status == TripStatus.cancelled;

    // Only fields the record actually has: zero / '—' means not recorded.
    final meta = <Widget>[
      if (trip.distanceKm > 0)
        _MetaChip(
          icon: Icons.route_rounded,
          label: '${trip.distanceKm.toStringAsFixed(1)} km',
        ),
      if (trip.durationMinutes > 0)
        _MetaChip(
          icon: Icons.timer_outlined,
          label: '${trip.durationMinutes} min',
        ),
      if (trip.paymentMethod != '—')
        _MetaChip(
          icon: trip.paymentMethod == 'MoMo'
              ? Icons.phone_android_rounded
              : trip.paymentMethod == 'Card'
                  ? Icons.credit_card_rounded
                  : Icons.payments_outlined,
          label: trip.paymentMethod,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FinanceCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: service.bg,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: trip.isRide
                        ? Text(
                            trip.passengerAvatar,
                            style: TextStyle(
                              color: service.fg,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : Icon(service.icon, color: service.fg, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.passengerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ServiceBadge(service: _service),
                          Text(
                            _personLabel,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('h:mm a · d MMM yyyy').format(trip.dateTime),
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusPill(
                  label: status.label,
                  tone: status.tone,
                  icon: status.icon,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Route ───────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryDark,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 1.5,
                        height: 26,
                        color: AppTheme.divider,
                      ),
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: cancelled
                              ? AppTheme.textSecondary
                              : AppTheme.dangerText,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.pickupAddress,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          trip.dropoffAddress,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Footer ──────────────────────────────────────────────────────
            if (meta.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(spacing: 6, runSpacing: 6, children: meta),
              ),
              const SizedBox(height: 10),
            ],
            FinanceTitleAmountRow(
              amountShare: 0.7,
              title: Align(
                alignment: Alignment.centerLeft,
                child: trip.rating > 0
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _StarRating(rating: trip.rating))
                    : const SizedBox.shrink(),
              ),
              amount: Text(
                formatGhs(trip.fareGhs),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color:
                      cancelled ? AppTheme.textSecondary : AppTheme.primaryDark,
                  decoration: cancelled ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
}

class _StarRating extends StatelessWidget {
  final double rating;
  const _StarRating({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Rated ${rating.toStringAsFixed(1)} of 5',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final filled = i < rating.floor();
          final half = !filled && i < rating;
          return Icon(
            half ? Icons.star_half_rounded : Icons.star_rounded,
            size: 14,
            color: filled || half ? AppTheme.accent : AppTheme.divider,
          );
        }),
      ),
    );
  }
}

// ─── Shimmer Loading ───────────────────────────────────────────────────────────
class _ShimmerList extends StatefulWidget {
  const _ShimmerList();

  @override
  State<_ShimmerList> createState() => _ShimmerListState();
}

class _ShimmerListState extends State<_ShimmerList>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => Semantics(
            label: i == 0 ? 'Loading history' : null,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (_, __) => _ShimmerCard(progress: _animation.value),
            ),
          ),
          childCount: 5,
        ),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  final double progress;
  const _ShimmerCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ShimmerBox(
                  width: 42, height: 42, radius: 21, progress: progress),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBox(width: 130, height: 12, progress: progress),
                    const SizedBox(height: 6),
                    _ShimmerBox(width: 90, height: 10, progress: progress),
                  ],
                ),
              ),
              _ShimmerBox(
                  width: 72, height: 24, radius: 20, progress: progress),
            ],
          ),
          const SizedBox(height: 12),
          _ShimmerBox(
              width: double.infinity,
              height: 64,
              radius: 12,
              progress: progress),
          const SizedBox(height: 12),
          Row(
            children: [
              _ShimmerBox(width: 60, height: 24, radius: 8, progress: progress),
              const SizedBox(width: 6),
              _ShimmerBox(width: 60, height: 24, radius: 8, progress: progress),
              const Spacer(),
              _ShimmerBox(width: 80, height: 20, progress: progress),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final double progress;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.radius = 6,
    required this.progress,
  });

  static const _base = AppTheme.divider;
  static const _highlight = AppTheme.background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment(-1 + progress, 0),
          end: Alignment(1 + progress, 0),
          colors: const [_base, _highlight, _base],
        ),
      ),
    );
  }
}

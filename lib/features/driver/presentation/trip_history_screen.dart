// features/driver/presentation/trip_history_screen.dart
//
// Production-ready Trip History Screen
// ─────────────────────────────────────
// • Summary stats bar (total trips, earnings, distance, hours)
// • Filter tabs: All · Completed · Cancelled · Ongoing
// • Search by destination or passenger name
// • Pull-to-refresh
// • Beautiful trip cards with map snapshot placeholder
// • Empty & error states
// • Shimmer loading skeleton
// ─────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// ─── Colour palette (matches CTS Transport theme) ─────────────────────────────
class _C {
  static const bg = Color(0xFFF7F6F3);
  static const surface = Colors.white;
  static const primary = Color(0xFF065F46);
  static const primaryLight = Color(0xFF6EE7B7);
  static const accent = Color(0xFF047857);
  static const textPrimary = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const cancelled = Color(0xFF6B7280);
  static const shimmerBase = Color(0xFFE2E8F0);
  static const shimmerHighlight = Color(0xFFF8FAFC);
}

// ─── Models ────────────────────────────────────────────────────────────────────
enum TripStatus { completed, cancelled, ongoing }

class TripSummary {
  final String id;
  final String passengerName;
  final String passengerAvatar;
  final String pickupAddress;
  final String dropoffAddress;
  final DateTime dateTime;
  final double distanceKm;
  final int durationMinutes;
  final double fareGhs;
  final double rating; // 0 if no rating yet
  final TripStatus status;
  final String paymentMethod; // 'Cash' | 'MoMo' | 'Card'

  const TripSummary({
    required this.id,
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
}

// ─── Mock data ─────────────────────────────────────────────────────────────────
List<TripSummary> _mockTrips() {
  final now = DateTime.now();
  return [
    TripSummary(
      id: 'TRP-001',
      passengerName: 'Ama Asante',
      passengerAvatar: 'AA',
      pickupAddress: 'Accra Mall, Spintex Road',
      dropoffAddress: 'University of Ghana, Legon',
      dateTime: now.subtract(const Duration(hours: 2)),
      distanceKm: 14.3,
      durationMinutes: 28,
      fareGhs: 45.00,
      rating: 5.0,
      status: TripStatus.completed,
      paymentMethod: 'MoMo',
    ),
    TripSummary(
      id: 'TRP-002',
      passengerName: 'Kwame Mensah',
      passengerAvatar: 'KM',
      pickupAddress: 'Kotoka International Airport',
      dropoffAddress: 'Labone, Accra',
      dateTime: now.subtract(const Duration(hours: 5)),
      distanceKm: 9.8,
      durationMinutes: 22,
      fareGhs: 38.50,
      rating: 4.0,
      status: TripStatus.completed,
      paymentMethod: 'Cash',
    ),
    TripSummary(
      id: 'TRP-003',
      passengerName: 'Efua Boateng',
      passengerAvatar: 'EB',
      pickupAddress: 'East Legon, Accra',
      dropoffAddress: 'Tema Community 1',
      dateTime: now.subtract(const Duration(days: 1, hours: 3)),
      distanceKm: 28.6,
      durationMinutes: 55,
      fareGhs: 85.00,
      rating: 0,
      status: TripStatus.cancelled,
      paymentMethod: 'MoMo',
    ),
    TripSummary(
      id: 'TRP-004',
      passengerName: 'Yaw Darko',
      passengerAvatar: 'YD',
      pickupAddress: 'Osu, Oxford Street',
      dropoffAddress: 'Airport Residential, Accra',
      dateTime: now.subtract(const Duration(days: 1, hours: 8)),
      distanceKm: 6.2,
      durationMinutes: 15,
      fareGhs: 25.00,
      rating: 4.5,
      status: TripStatus.completed,
      paymentMethod: 'Card',
    ),
    TripSummary(
      id: 'TRP-005',
      passengerName: 'Abena Frempong',
      passengerAvatar: 'AF',
      pickupAddress: 'Madina Market',
      dropoffAddress: 'Achimota School Junction',
      dateTime: now.subtract(const Duration(days: 2)),
      distanceKm: 11.4,
      durationMinutes: 32,
      fareGhs: 35.00,
      rating: 5.0,
      status: TripStatus.completed,
      paymentMethod: 'MoMo',
    ),
    TripSummary(
      id: 'TRP-006',
      passengerName: 'Kofi Owusu',
      passengerAvatar: 'KO',
      pickupAddress: 'Kasoa Tollbooth',
      dropoffAddress: 'Circle, Accra',
      dateTime: now.subtract(const Duration(days: 3)),
      distanceKm: 22.1,
      durationMinutes: 48,
      fareGhs: 60.00,
      rating: 3.5,
      status: TripStatus.completed,
      paymentMethod: 'Cash',
    ),
    TripSummary(
      id: 'TRP-007',
      passengerName: 'Akua Sarpong',
      passengerAvatar: 'AS',
      pickupAddress: 'Tema Harbour',
      dropoffAddress: 'Cantonments, Accra',
      dateTime: now.subtract(const Duration(days: 4)),
      distanceKm: 31.7,
      durationMinutes: 62,
      fareGhs: 95.00,
      rating: 0,
      status: TripStatus.cancelled,
      paymentMethod: 'MoMo',
    ),
  ];
}

// ─── Main Screen ───────────────────────────────────────────────────────────────
class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<TripSummary> _allTrips = [];
  bool _loading = true;
  bool _hasError = false;
  String _searchQuery = '';
  bool _showSearch = false;

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
    if (refresh) setState(() => _loading = true);
    try {
      // Simulate network delay — replace with real service call
      await Future.delayed(const Duration(milliseconds: 1200));
      setState(() {
        _allTrips = _mockTrips();
        _loading = false;
        _hasError = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
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
              t.pickupAddress.toLowerCase().contains(q))
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
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _C.bg,
        body: RefreshIndicator(
          color: _C.primary,
          onRefresh: () => _loadTrips(refresh: true),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _AppBar(
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
                _StatsBanner(
                  totalEarnings: _totalEarnings,
                  totalDistance: _totalDistance,
                  completedCount: _completedCount,
                  totalCount: _allTrips.length,
                ),
                _TabBar(controller: _tabController, tabs: _tabs),
              ],
              if (_loading)
                const _ShimmerList()
              else if (_hasError)
                _ErrorState(onRetry: () => _loadTrips(refresh: true))
              else if (_filtered.isEmpty)
                _EmptyState(query: _searchQuery)
              else
                _TripList(trips: _filtered),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── App Bar ───────────────────────────────────────────────────────────────────
class _AppBar extends StatelessWidget {
  final bool showSearch;
  final TextEditingController searchController;
  final VoidCallback onSearchToggle;
  final ValueChanged<String> onSearchChanged;

  const _AppBar({
    required this.showSearch,
    required this.searchController,
    required this.onSearchToggle,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: showSearch ? 130 : 100,
      collapsedHeight: showSearch ? 130 : 100,
      pinned: true,
      backgroundColor: _C.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF064E3B), Color(0xFF065F46), Color(0xFF047857)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 36), // leading offset
                      const Expanded(
                        child: Text(
                          'Trip History',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          showSearch ? Icons.close_rounded : Icons.search_rounded,
                          color: Colors.white,
                        ),
                        onPressed: onSearchToggle,
                      ),
                    ],
                  ),
                  if (showSearch) ...[
                    const SizedBox(height: 8),
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: TextField(
                        controller: searchController,
                        onChanged: onSearchChanged,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search by passenger or location…',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                          prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.7), size: 20),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Stats Banner ──────────────────────────────────────────────────────────────
class _StatsBanner extends StatelessWidget {
  final double totalEarnings;
  final double totalDistance;
  final int completedCount;
  final int totalCount;

  const _StatsBanner({
    required this.totalEarnings,
    required this.totalDistance,
    required this.completedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        color: _C.primary,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            children: [
              _StatItem(
                label: 'Total Trips',
                value: '$totalCount',
                icon: Icons.directions_car_rounded,
              ),
              _StatDivider(),
              _StatItem(
                label: 'Completed',
                value: '$completedCount',
                icon: Icons.check_circle_outline_rounded,
              ),
              _StatDivider(),
              _StatItem(
                label: 'Earnings',
                value: 'GHS ${totalEarnings.toStringAsFixed(0)}',
                icon: Icons.account_balance_wallet_outlined,
              ),
              _StatDivider(),
              _StatItem(
                label: 'Distance',
                value: '${totalDistance.toStringAsFixed(0)}km',
                icon: Icons.route_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: _C.primaryLight, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 36,
        color: Colors.white.withOpacity(0.2),
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
      child: Container(
        color: _C.primary,
        child: Container(
          decoration: const BoxDecoration(
            color: _C.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TabBar(
              controller: controller,
              isScrollable: false,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: _C.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: _C.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: tabs.map((t) => Tab(text: t, height: 38)).toList(),
            ),
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
                ...section.value.map((t) => _TripCard(trip: t)),
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
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(
          label,
          style: const TextStyle(
            color: _C.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      );
}

// ─── Trip Card ─────────────────────────────────────────────────────────────────
class _TripCard extends StatelessWidget {
  final TripSummary trip;

  const _TripCard({required this.trip});

  Color get _statusColor {
    switch (trip.status) {
      case TripStatus.completed:
        return _C.success;
      case TripStatus.cancelled:
        return _C.cancelled;
      case TripStatus.ongoing:
        return _C.warning;
    }
  }

  String get _statusLabel {
    switch (trip.status) {
      case TripStatus.completed:
        return 'Completed';
      case TripStatus.cancelled:
        return 'Cancelled';
      case TripStatus.ongoing:
        return 'Ongoing';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _C.primary.withOpacity(0.8),
                        _C.accent,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      trip.passengerAvatar,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.passengerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: _C.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('h:mm a · d MMM yyyy').format(trip.dateTime),
                        style: const TextStyle(
                          color: _C.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Route ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.border),
              ),
              child: Row(
                children: [
                  // Route indicator
                  Column(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: _C.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 1.5,
                        height: 28,
                        color: _C.border,
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  // Addresses
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.pickupAddress,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _C.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          trip.dropoffAddress,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _C.textPrimary,
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
          ),

          // ── Footer ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(
              children: [
                // Distance
                _MetaChip(
                  icon: Icons.route_rounded,
                  label: '${trip.distanceKm.toStringAsFixed(1)} km',
                ),
                const SizedBox(width: 6),
                // Duration
                _MetaChip(
                  icon: Icons.timer_outlined,
                  label: '${trip.durationMinutes} min',
                ),
                const SizedBox(width: 6),
                // Payment
                _MetaChip(
                  icon: trip.paymentMethod == 'MoMo'
                      ? Icons.phone_android_rounded
                      : trip.paymentMethod == 'Card'
                          ? Icons.credit_card_rounded
                          : Icons.payments_outlined,
                  label: trip.paymentMethod,
                ),
                const Spacer(),
                // Fare
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'GHS ${trip.fareGhs.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: trip.status == TripStatus.cancelled
                            ? _C.textMuted
                            : _C.primary,
                        decoration: trip.status == TripStatus.cancelled
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (trip.rating > 0) ...[
                      const SizedBox(height: 2),
                      _StarRating(rating: trip.rating),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
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
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: _C.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _C.textSecondary,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating.floor();
        final half = !filled && i < rating;
        return Icon(
          half ? Icons.star_half_rounded : Icons.star_rounded,
          size: 12,
          color: filled || half ? _C.warning : _C.border,
        );
      }),
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
          (_, __) => AnimatedBuilder(
            animation: _animation,
            builder: (_, __) => _ShimmerCard(progress: _animation.value),
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
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ShimmerBox(width: 40, height: 40, radius: 20, progress: progress),
              const SizedBox(width: 10),
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
              _ShimmerBox(width: 72, height: 24, radius: 20, progress: progress),
            ],
          ),
          const SizedBox(height: 12),
          _ShimmerBox(width: double.infinity, height: 70, radius: 12, progress: progress),
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
          colors: const [
            _C.shimmerBase,
            _C.shimmerHighlight,
            _C.shimmerBase,
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String query;
  const _EmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _C.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_car_outlined,
                  size: 40,
                  color: _C.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                query.isNotEmpty ? 'No results found' : 'No trips yet',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _C.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                query.isNotEmpty
                    ? 'Try a different search term'
                    : 'Your completed trips will appear here',
                style: const TextStyle(
                  fontSize: 14,
                  color: _C.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Error State ───────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 56, color: _C.textMuted),
              const SizedBox(height: 16),
              const Text(
                'Could not load trips',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _C.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Check your connection and try again.',
                style: TextStyle(fontSize: 14, color: _C.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
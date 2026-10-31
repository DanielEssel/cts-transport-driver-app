// Gas supplier jobs: the driver's own jobs in progress (resumable after a
// restart), open jobs near the driver, then one job from the station to the
// customer. Opened from the home screen (gas_supplier_jobs_entry.dart).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

import '../../trips/widgets/navigation_button.dart' show openExternalNavigation;
import '../data/gas_supplier_job_repository.dart';
import '../domain/gas_supplier_job.dart';

String _ghs(double v) => 'GH₵${v.toStringAsFixed(2)}';

/// Opens directions to a point; external Maps in the app, a fake in tests.
typedef OpenNavigation = Future<void> Function(double latitude, double longitude);

Future<void> openGasJobNavigation(double latitude, double longitude) => openExternalNavigation(LatLng(latitude, longitude));

String _clock(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// Spec §5, verbatim.
const _feeExplanation = "You earn this fee when the customer confirms delivery with their code. After CTSGo's settlement hold, "
    "CTSGo credits it to your CTSGo wallet. You can then request a withdrawal. Money is paid out only when CTSGo confirms "
    'the transfer. Any commission you owe from cash jobs is deducted when you withdraw.';

String _countdown(int ms) {
  final secs = (ms / 1000).ceil();
  return '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
}

String _date(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class GasSupplierJobsScreen extends StatefulWidget {
  final GasSupplierJobRepository? repository;
  /// The device clock in ms since epoch; tests replace it.
  final int Function()? clockMs;
  const GasSupplierJobsScreen({super.key, this.repository, this.clockMs});

  @override
  State<GasSupplierJobsScreen> createState() => _GasSupplierJobsScreenState();
}

class _GasSupplierJobsScreenState extends State<GasSupplierJobsScreen> {
  late final GasSupplierJobRepository repo = widget.repository ?? GasSupplierJobRepository();
  List<GasSupplierJob>? jobs;
  List<GasSupplierJob> mine = const [];
  /// Set when the driver's own jobs could not be loaded: never shown as "none".
  String? mineError;
  List<GasSupplierJob> offers = const [];
  List<GasSupplierEarning> earnings = const [];
  /// Server clock minus device clock, taken when the offers were listed.
  int skewMs = 0;
  Timer? _tick, _poll;
  String? error;
  bool busy = false;

  int _now() => widget.clockMs?.call() ?? DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _load();
    // One-second countdown; offers are re-listed every 30 s while any exist.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted && offers.isNotEmpty) setState(() {}); });
    _poll = Timer.periodic(const Duration(seconds: 30), (_) { if (mounted && offers.isNotEmpty && !busy) _load(quiet: true); });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  int _remainingMs(GasSupplierJob o) => (o.expiresAtMs ?? 0) - (_now() + skewMs);

  /// A [quiet] reload (the 30 s poll, pull to refresh, or after an action)
  /// that fails keeps what is on screen: a passing network blip must not
  /// clear the offer the rider is reading. [report] shows the failure.
  Future<void> _load({bool quiet = false, bool report = false}) async {
    if (!quiet) setState(() { error = null; jobs = null; });
    // The driver's own jobs never depend on the open list loading.
    try {
      final own = await repo.myJobs();
      if (mounted) setState(() { mine = own; mineError = null; });
    } on GasSupplierJobFailure catch (e) {
      // Keep whatever is on screen; say the check failed.
      if (mounted) setState(() => mineError = e.message);
    }
    try {
      final list = await repo.openJobs();
      if (mounted) {
        setState(() {
          jobs = list.jobs;
          offers = list.offers;
          if (list.serverNowMs != null) skewMs = list.serverNowMs! - _now();
        });
      }
    } on GasSupplierJobFailure catch (e) {
      if (!mounted) return;
      if (!quiet || jobs == null) {
        setState(() { jobs = const []; offers = const []; error = e.message; });
      } else if (report) {
        setState(() => error = e.message);
      }
    }
    try {
      final list = await repo.myEarnings();
      if (mounted) setState(() => earnings = list);
    } on GasSupplierJobFailure catch (_) {
      // Earnings are secondary; the jobs still show.
    }
  }

  Future<void> _acceptOffer(GasSupplierJob o) async {
    setState(() { busy = true; error = null; });
    try {
      await repo.accept(o.orderId, offerSeq: o.offerSeq);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GasSupplierActiveJobScreen(job: o, repository: repo)));
      if (mounted) _load();
    } on GasSupplierJobFailure catch (e) {
      if (mounted) setState(() => error = e.message);
      _load(quiet: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _declineOffer(GasSupplierJob o) async {
    // Without its sequence the server cannot tell which offer this is: never guess one.
    final seq = o.offerSeq;
    if (seq == null) {
      setState(() => error = gasSupplierJobMessage('offer_stale', ''));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Decline this offer?'),
        content: const Text('Your supplier will be told, and the job may be offered to other drivers.'),
        actions: [
          TextButton(key: const Key('gsj-decline-cancel'), onPressed: () => Navigator.pop(c, false), child: const Text('Keep offer')),
          FilledButton(key: const Key('gsj-decline-confirm'), onPressed: () => Navigator.pop(c, true), child: const Text('Decline')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() { busy = true; error = null; });
    try {
      await repo.decline(o.orderId, seq);
    } on GasSupplierJobFailure catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (mounted) _load(quiet: true);
  }

  Widget _offerCard(GasSupplierJob o) {
    final left = _remainingMs(o);
    final expired = left <= 0;
    final id = o.orderId;
    return Card(
      key: Key('gsj-offer-$id'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${o.quantity} × ${gasJobLabel(o.cylinderSize)} · ${gasJobLabel(o.orderType)}', style: Theme.of(context).textTheme.titleMedium)),
            Text(expired ? 'Expired' : _countdown(left), key: Key('gsj-offer-countdown-$id'), style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          Text('Collect at ${o.station.name ?? 'the station'}'),
          Text('Deliver to ${o.delivery.address ?? 'the customer'}'),
          if (gasRouteSummary(o) != null) Text(gasRouteSummary(o)!),
          if (o.deliveryFee != null) Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Delivery fee ${_ghs(o.deliveryFee!)} · paid by CTSGo', style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 10),
          Row(children: [
            OutlinedButton(key: Key('gsj-offer-decline-$id'), onPressed: busy || expired ? null : () => _declineOffer(o), child: const Text('Decline')),
            const SizedBox(width: 12),
            Expanded(child: FilledButton(key: Key('gsj-offer-accept-$id'), onPressed: busy || expired ? null : () => _acceptOffer(o), child: const Text('Accept'))),
          ]),
        ]),
      ),
    );
  }

  Widget _earningTile(GasSupplierEarning e) {
    final label = gasEarningLabel(e.status);
    final when = e.status == 'credited_to_wallet' && e.creditedAtMs != null ? ' ${_date(e.creditedAtMs!)}' : '';
    return ListTile(
      key: Key('gsj-earning-${e.orderId}'),
      dense: true,
      title: Text(_ghs(e.amountPesewas / 100)),
      subtitle: Text('$label$when${e.linkedSupplierName != null ? ' · ${e.linkedSupplierName}' : ''}'),
    );
  }

  Future<void> _resume(GasSupplierJob job) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GasSupplierActiveJobScreen(job: job, repository: repo)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (mounted) _load();
  }

  Future<void> _accept(GasSupplierJob job) async {
    setState(() { busy = true; error = null; });
    try {
      await repo.accept(job.orderId);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GasSupplierActiveJobScreen(job: job, repository: repo)));
      if (mounted) _load();
    } on GasSupplierJobFailure catch (e) {
      setState(() => error = e.message);
      _load();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Gas supplier jobs'), actions: [IconButton(onPressed: busy ? null : _load, icon: const Icon(Icons.refresh))]),
      body: jobs == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _load(quiet: true, report: true),
              child: ListView(padding: const EdgeInsets.all(16), physics: const AlwaysScrollableScrollPhysics(), children: [
              if (offers.isNotEmpty) ...[
                Text('Offer from your supplier', style: t.textTheme.titleMedium),
                for (final o in offers) _offerCard(o),
                const Text(_feeExplanation, key: Key('gsj-fee-explainer')),
                const SizedBox(height: 16),
              ],
              // When the open list failed too, its error above already says why.
              if (mineError != null && error == null)
                Card(
                  key: const Key('gsj-mine-error'),
                  child: ListTile(
                    leading: Icon(Icons.error_outline, color: t.colorScheme.error),
                    title: const Text("Couldn't check for a job you're already doing"),
                    subtitle: Text(mineError!),
                    trailing: TextButton(key: const Key('gsj-mine-retry'), onPressed: busy ? null : () => _load(quiet: true, report: true), child: const Text('Retry')),
                  ),
                ),
              if (mine.isNotEmpty) ...[
                Text('In progress', style: t.textTheme.titleMedium),
                for (final j in mine)
                  Card(
                    child: ListTile(
                      title: Text('${j.quantity} × ${gasJobLabel(j.cylinderSize)} · ${gasJobLabel(j.orderType)}'),
                      subtitle: Text('Collect at ${j.station.name ?? 'the station'}\nDeliver to ${j.delivery.address ?? 'the customer'}'),
                      isThreeLine: true,
                      trailing: FilledButton(key: Key('gsj-resume-${j.orderId}'), onPressed: busy ? null : () => _resume(j), child: const Text('Continue')),
                    ),
                  ),
                const SizedBox(height: 16),
                Text('Open jobs', style: t.textTheme.titleMedium),
              ],
              if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error!, key: const Key('gsj-error'), style: TextStyle(color: t.colorScheme.error))),
              if (jobs!.isEmpty && error == null) const Text('No Gas supplier jobs near you right now.', key: Key('gsj-empty')),
              for (final j in jobs!)
                Card(
                  child: ListTile(
                    title: Text('${j.quantity} × ${gasJobLabel(j.cylinderSize)} · ${gasJobLabel(j.orderType)}'),
                    // distanceKm is straight-line from the driver; the road route is the quoted one from the station.
                    subtitle: Text('Collect at ${j.station.name ?? 'the station'}\nDeliver to ${j.delivery.address ?? 'the customer'}'
                        '${j.distanceKm != null ? ' · ${j.distanceKm!.toStringAsFixed(1)} km from you (straight line)' : ''}'
                        '${gasRouteSummary(j) != null ? '\n${gasRouteSummary(j)}' : ''}'),
                    isThreeLine: true,
                    trailing: FilledButton(
                      key: Key('gsj-accept-${j.orderId}'),
                      onPressed: busy ? null : () => _accept(j),
                      child: Text(j.deliveryFee != null ? 'Accept ${_ghs(j.deliveryFee!)}' : 'Accept'),
                    ),
                  ),
                ),
              if (earnings.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Your delivery earnings', style: t.textTheme.titleMedium),
                if (offers.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text(_feeExplanation, key: Key('gsj-fee-explainer'))),
                for (final e in earnings) _earningTile(e),
              ],
            ]),
            ),
    );
  }
}

class GasSupplierActiveJobScreen extends StatefulWidget {
  final GasSupplierJob job;
  final GasSupplierJobRepository repository;
  /// Directions only: it never changes the job's status.
  final OpenNavigation navigate;
  const GasSupplierActiveJobScreen({super.key, required this.job, required this.repository, this.navigate = openGasJobNavigation});

  @override
  State<GasSupplierActiveJobScreen> createState() => _GasSupplierActiveJobScreenState();
}

class _GasSupplierActiveJobScreenState extends State<GasSupplierActiveJobScreen> {
  // A resumed job starts where the server says it is; a new one at the start.
  late GasSupplierJobStep step = gasSupplierJobStep(widget.job.status);
  final code = TextEditingController();
  String? error;
  bool busy = false;
  /// The server no longer lists this job as the driver's: no more actions.
  bool gone = false;

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() f, GasSupplierJobStep next) async {
    if (busy || gone) return;
    setState(() { busy = true; error = null; });
    try {
      await f();
      if (mounted) setState(() => step = next);
    } on GasSupplierJobFailure catch (e) {
      if (mounted) setState(() => error = e.message);
      // The job may have moved on (a lost answer, a cancel, a reassignment):
      // take its step from the server rather than guess.
      if (gasSupplierResyncReasons.contains(e.reason)) await _resync(completing: next == GasSupplierJobStep.delivered);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _resync({required bool completing}) async {
    try {
      final now = await widget.repository.myJob(widget.job.orderId);
      if (!mounted) return;
      if (now == null) {
        setState(() { gone = true; error = gasSupplierJobMessage('job_no_longer_yours', ''); });
      } else {
        final serverStep = gasSupplierJobStep(now.status);
        if (serverStep != step) setState(() { step = serverStep; error = null; });
      }
    } on GasSupplierJobFailure {
      // Keep the first error; the driver can try the step again.
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final j = widget.job;
    final repo = widget.repository;
    return Scaffold(
      appBar: AppBar(title: Text('Job ${j.orderId.length > 8 ? j.orderId.substring(0, 8) : j.orderId}')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('${j.quantity} × ${gasJobLabel(j.cylinderSize)} · ${gasJobLabel(j.orderType)}', style: t.textTheme.titleMedium),
        const SizedBox(height: 12),
        ListTile(leading: const Icon(Icons.store), title: Text(j.station.name ?? 'Station'), subtitle: Text(j.station.address ?? '')),
        ListTile(leading: const Icon(Icons.home), title: const Text('Customer'), subtitle: Text(j.delivery.address ?? '')),
        // The quoted route and estimate as the server sent them; nothing when it sent none.
        if (gasRouteSummary(j) != null) Text(gasRouteSummary(j)!, key: const Key('gsj-route')),
        if (j.estimatedDeliveryAtMs != null && step != GasSupplierJobStep.delivered)
          Text('Customer was told about ${_clock(j.estimatedDeliveryAtMs!)} (estimate)', key: const Key('gsj-eta')),
        if (!gone && step == GasSupplierJobStep.goingToStation && j.station.latitude != null && j.station.longitude != null)
          OutlinedButton.icon(key: const Key('gsj-nav-station'), icon: const Icon(Icons.navigation_rounded),
              onPressed: () => widget.navigate(j.station.latitude!, j.station.longitude!), label: const Text('Navigate to the station')),
        if (!gone && (step == GasSupplierJobStep.atStation || step == GasSupplierJobStep.delivering)
            && j.delivery.latitude != null && j.delivery.longitude != null)
          OutlinedButton.icon(key: const Key('gsj-nav-customer'), icon: const Icon(Icons.navigation_rounded),
              onPressed: () => widget.navigate(j.delivery.latitude!, j.delivery.longitude!), label: const Text('Navigate to the customer')),
        const Divider(),
        if (gone)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton(key: const Key('gsj-back'), onPressed: () => Navigator.of(context).maybePop(), child: const Text('Back to jobs')),
          )
        else if (step == GasSupplierJobStep.goingToStation)
          FilledButton(key: const Key('gsj-arrived'), onPressed: busy ? null : () => _run(() => repo.arrivedAtStation(j.orderId), GasSupplierJobStep.atStation),
              child: const Text("I'm at the station")),
        if (!gone && (step == GasSupplierJobStep.atStation || step == GasSupplierJobStep.delivering)) ...[
          Text(step == GasSupplierJobStep.atStation
              ? 'Collect the cylinder. The supplier confirms the hand-over in their portal. Then deliver it and ask the customer for their code.'
              : 'Ask the customer for their code.'),
          const SizedBox(height: 12),
          TextField(key: const Key('gsj-code'), controller: code, keyboardType: TextInputType.number, maxLength: 8,
              decoration: const InputDecoration(labelText: "Customer's code", border: OutlineInputBorder())),
          FilledButton(key: const Key('gsj-complete'), onPressed: busy ? null : () => _run(() => repo.complete(j.orderId, code.text), GasSupplierJobStep.delivered),
              child: const Text('Complete delivery')),
        ],
        if (step == GasSupplierJobStep.delivered)
          Text('Delivered. Thank you!', key: const Key('gsj-done'), style: t.textTheme.titleMedium),
        // Only an offer's fee is shown (it carries offerSeq); the amount is earned, not yet in the wallet.
        if (step == GasSupplierJobStep.delivered && j.offerSeq != null && j.deliveryFee != null)
          Text('Earned ${_ghs(j.deliveryFee!)} · pending', key: const Key('gsj-earned')),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, key: const Key('gsj-error'), style: TextStyle(color: t.colorScheme.error))),
      ]),
    );
  }
}

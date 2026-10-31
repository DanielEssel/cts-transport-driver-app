// The driver's Gas supplier jobs in progress, for Active Jobs and the home
// banner. Drivers cannot read gas_supplier_orders, so these come only from
// listMyGasSupplierJobs (the server selects by the caller's uid and status);
// nothing here creates or stores a job record of its own.
//
// Feature flag: while gasSupplierOrderingStatus reports off (or cannot be
// reached), no job list is requested and nothing is shown; the flag is
// re-checked every [offRecheckTicks] intervals. Once on, the list is
// re-asked every [supplierJobsPollIntervalProvider] while something watches
// it, and a refusal with gas_supplier_fulfilment_disabled turns it back off.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gas_supplier_job_repository.dart';
import '../domain/gas_supplier_job.dart';
import 'gas_supplier_jobs_screen.dart';

final gasSupplierJobRepositoryProvider = Provider<GasSupplierJobRepository>((ref) => GasSupplierJobRepository());

final supplierJobsPollIntervalProvider = Provider<Duration>((ref) => const Duration(seconds: 60));

/// While supplier jobs are off, the flag is asked once every this many intervals.
const offRecheckTicks = 5;

/// What the server said about the driver's supplier jobs.
class SupplierActiveJobs {
  /// Supplier jobs are switched on.
  final bool enabled;
  final List<GasSupplierJob> jobs;
  /// The last check failed (no connection, timeout, refused): jobs are the
  /// last known list, which may be stale or empty; never read as "none".
  final String? error;
  const SupplierActiveJobs({required this.enabled, this.jobs = const [], this.error});
  static const off = SupplierActiveJobs(enabled: false);
}

final supplierActiveJobsProvider = StreamProvider.autoDispose<SupplierActiveJobs>((ref) {
  final repo = ref.watch(gasSupplierJobRepositoryProvider);
  final every = ref.watch(supplierJobsPollIntervalProvider);
  final out = StreamController<SupplierActiveJobs>();
  var enabled = false;
  var last = const <GasSupplierJob>[];
  var running = false;
  var tick = 0;
  Timer? timer;

  Future<void> check({bool first = false}) async {
    if (running || out.isClosed) return;
    if (!first && !enabled && ++tick % offRecheckTicks != 0) return;
    running = true;
    try {
      if (!enabled) enabled = await repo.available();
      if (!enabled) {
        last = const [];
        if (!out.isClosed) out.add(SupplierActiveJobs.off);
        return;
      }
      try {
        last = await repo.myJobs();
        if (!out.isClosed) out.add(SupplierActiveJobs(enabled: true, jobs: last));
      } on GasSupplierJobFailure catch (e) {
        if (e.reason == 'gas_supplier_fulfilment_disabled') {
          enabled = false;
          last = const [];
          if (!out.isClosed) out.add(SupplierActiveJobs.off);
        } else if (!out.isClosed) {
          out.add(SupplierActiveJobs(enabled: true, jobs: last, error: e.message));
        }
      }
    } finally {
      running = false;
    }
  }

  check(first: true);
  timer = Timer.periodic(every, (_) => check());
  ref.onDispose(() {
    timer?.cancel();
    out.close();
  });
  return out.stream;
});

/// Opens one supplier job; when it closes, the list is asked again so a job
/// that finished, was cancelled or reassigned leaves Active Jobs at once.
class SupplierJobRoute extends StatefulWidget {
  final GasSupplierJob job;
  final GasSupplierJobRepository repository;
  const SupplierJobRoute({super.key, required this.job, required this.repository});

  @override
  State<SupplierJobRoute> createState() => _SupplierJobRouteState();
}

class _SupplierJobRouteState extends State<SupplierJobRoute> {
  ProviderContainer? _container;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container ??= ProviderScope.containerOf(context, listen: false);
  }

  @override
  void dispose() {
    _container?.invalidate(supplierActiveJobsProvider);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GasSupplierActiveJobScreen(job: widget.job, repository: widget.repository);
}

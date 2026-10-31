// The home screen's way into Gas supplier jobs. Shown only while the
// service is switched on (gasSupplierOrderingStatus); any failure hides it.
// A job the driver already accepted is offered first, because supplier
// orders are not in the home banner's active jobs (drivers cannot read
// gas_supplier_orders; only the callables answer for them).
import 'package:flutter/material.dart';

import 'package:cts_transport_driver_app/app/app_theme.dart';

import '../data/gas_supplier_job_repository.dart';
import '../domain/gas_supplier_job.dart';
import 'gas_supplier_jobs_screen.dart';

class GasSupplierJobsEntry extends StatefulWidget {
  final GasSupplierJobRepository? repository;
  const GasSupplierJobsEntry({super.key, this.repository});

  @override
  State<GasSupplierJobsEntry> createState() => _GasSupplierJobsEntryState();
}

class _GasSupplierJobsEntryState extends State<GasSupplierJobsEntry> {
  late final GasSupplierJobRepository repo = widget.repository ?? GasSupplierJobRepository();
  bool available = false;
  List<GasSupplierJob> mine = const [];
  bool hasOffer = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final on = await repo.available();
    var own = const <GasSupplierJob>[];
    var offered = false;
    if (on) {
      try {
        own = await repo.myJobs();
      } catch (_) {
        // The card still opens the jobs screen, which retries.
      }
      try {
        offered = (await repo.openJobs()).offers.isNotEmpty;
      } catch (_) {}
    }
    if (mounted) setState(() { available = on; mine = own; hasOffer = offered; });
  }

  Future<void> _open() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GasSupplierJobsScreen(repository: repo)));
    if (mounted) _check();
  }

  @override
  Widget build(BuildContext context) {
    if (!available) return const SizedBox.shrink();
    final inProgress = mine.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('gsj-entry'),
          onTap: _open,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_fire_department_rounded, color: AppTheme.primaryDark, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasOffer ? 'Delivery offer waiting' : inProgress ? 'Gas supplier job in progress' : 'Gas supplier jobs',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasOffer ? 'Tap to see the offer from your supplier' : inProgress ? 'Tap to continue your job' : "Collect at a supplier's station and deliver",
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

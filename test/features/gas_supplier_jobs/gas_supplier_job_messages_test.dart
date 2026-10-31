// Messages for supplier-job refusals added with admin reassignment
// (functions/gas_supplier_fulfilment.js adminReleaseGasSupplierDriver).

import 'package:cts_transport_driver_app/features/gas_supplier_jobs/domain/gas_supplier_job.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a driver released from a job is told it was reassigned; its other steps say it is gone', () {
    expect(gasSupplierJobMessage('released_from_job', 'x'), 'This job was reassigned to another driver.');
    expect(gasSupplierJobMessage('order_not_found', 'x'), 'This job is no longer available.');
    expect(gasSupplierJobMessage('something_new', 'Server text'), 'Server text');
  });
}

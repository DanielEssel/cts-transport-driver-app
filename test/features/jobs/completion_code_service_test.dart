// The hand-over code is checked by the server; the app never reads it.

import 'package:cts_transport_driver_app/features/jobs/data/completion_code_service.dart';
import 'package:flutter_test/flutter_test.dart';

Future<CodeCheckResult> _check(Map<String, dynamic> reply,
        {List<Map<String, dynamic>>? sent}) =>
    verifyCompletionCode(
      collection: 'deliveries',
      orderId: 'd1',
      code: '4821',
      call: (data) async {
        sent?.add(data);
        return reply;
      },
    );

void main() {
  test('sends only the collection, the order and the entered code', () async {
    final sent = <Map<String, dynamic>>[];
    await _check({'ok': true}, sent: sent);
    expect(sent.single, {'collection': 'deliveries', 'orderId': 'd1', 'code': '4821'});
  });

  test('maps every server reply', () async {
    expect((await _check({'ok': true})).kind, CodeCheck.ok);
    final wrong = await _check({'ok': false, 'reason': 'code_mismatch', 'attemptsLeft': 3});
    expect([wrong.kind, wrong.attemptsLeft], [CodeCheck.wrong, 3]);
    expect((await _check({'ok': false, 'reason': 'too_many_attempts'})).kind, CodeCheck.locked);
    expect((await _check({'ok': false, 'reason': 'no_code_on_order'})).kind, CodeCheck.noCode);
    expect((await _check({'ok': false, 'reason': 'order_not_open'})).kind, CodeCheck.closed);
    expect((await _check({'ok': false, 'reason': 'something_new'})).kind, CodeCheck.failed);
  });

  test('a network or permission error is a failed check, never a pass', () async {
    final r = await verifyCompletionCode(
        collection: 'gas_orders', orderId: 'g1', code: '4821',
        call: (_) async => throw Exception('permission-denied'));
    expect(r.kind, CodeCheck.failed);
  });

  test('messages', () {
    expect(codeCheckMessage(const CodeCheckResult(CodeCheck.wrong, attemptsLeft: 1), who: 'receiver'),
        'Incorrect code. Ask the receiver for the correct code (1 try left).');
    expect(codeCheckMessage(const CodeCheckResult(CodeCheck.locked), who: 'customer'),
        contains('Contact support'));
    expect(codeCheckMessage(const CodeCheckResult(CodeCheck.failed), who: 'customer'),
        contains('try again'));
  });
}

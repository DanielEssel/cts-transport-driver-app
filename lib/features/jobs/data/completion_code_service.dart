// Checks the receiver's completion code with the server
// (verifyCompletionCode in the passenger repo's functions). The code is held
// where this app cannot read it, so a hand-over can no longer be completed
// without the receiver; the server records the verified code on the order
// and settlement pays against it.

import 'package:cloud_functions/cloud_functions.dart';

enum CodeCheck { ok, wrong, locked, noCode, closed, failed }

class CodeCheckResult {
  const CodeCheckResult(this.kind, {this.attemptsLeft});
  final CodeCheck kind;
  final int? attemptsLeft;
}

typedef VerifyCodeCall = Future<Map<String, dynamic>> Function(
    Map<String, dynamic> data);

Future<Map<String, dynamic>> _firebaseVerify(Map<String, dynamic> data) async {
  final r = await FirebaseFunctions.instanceFor(region: 'europe-west2')
      .httpsCallable('verifyCompletionCode')
      .call(data);
  return Map<String, dynamic>.from(r.data as Map);
}

/// Asks the server whether [code] is [orderId]'s code. [collection] is
/// 'deliveries' or 'gas_orders'.
Future<CodeCheckResult> verifyCompletionCode({
  required String collection,
  required String orderId,
  required String code,
  VerifyCodeCall call = _firebaseVerify,
}) async {
  Map<String, dynamic> r;
  try {
    r = await call({'collection': collection, 'orderId': orderId, 'code': code});
  } catch (_) {
    return const CodeCheckResult(CodeCheck.failed);
  }
  if (r['ok'] == true) return const CodeCheckResult(CodeCheck.ok);
  final left = (r['attemptsLeft'] as num?)?.toInt();
  return switch (r['reason']) {
    'code_mismatch' || 'code_malformed' =>
      CodeCheckResult(CodeCheck.wrong, attemptsLeft: left),
    'too_many_attempts' => const CodeCheckResult(CodeCheck.locked),
    'no_code_on_order' => const CodeCheckResult(CodeCheck.noCode),
    'order_not_open' || 'order_not_found' => const CodeCheckResult(CodeCheck.closed),
    _ => const CodeCheckResult(CodeCheck.failed),
  };
}

/// What to tell the driver when the check did not pass; [who] is the person
/// holding the code ('receiver' / 'customer').
String codeCheckMessage(CodeCheckResult r, {required String who}) =>
    switch (r.kind) {
      CodeCheck.wrong => r.attemptsLeft == null
          ? 'Incorrect code. Ask the $who for the correct code.'
          : 'Incorrect code. Ask the $who for the correct code '
              '(${r.attemptsLeft} ${r.attemptsLeft == 1 ? 'try' : 'tries'} left).',
      CodeCheck.locked =>
        'Too many wrong codes for this order. Contact support to complete it.',
      CodeCheck.closed => 'This order can no longer be completed here.',
      CodeCheck.failed =>
        'Could not check the code. Check your connection and try again.',
      CodeCheck.ok || CodeCheck.noCode => '',
    };

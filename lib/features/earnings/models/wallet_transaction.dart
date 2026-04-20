// features/earnings/models/wallet_transaction.dart

class WalletTransaction {
  final String id;
  final String description;
  final double amount;
  final bool isCredit;
  final DateTime timestamp;
  final String status; // 'completed', 'pending', 'failed'

  WalletTransaction({
    required this.id,
    required this.description,
    required this.amount,
    required this.isCredit,
    required this.timestamp,
    required this.status,
  });

  // Factory method to create from JSON
  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'],
      description: json['description'],
      amount: json['amount'].toDouble(),
      isCredit: json['isCredit'],
      timestamp: DateTime.parse(json['timestamp']),
      status: json['status'],
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'isCredit': isCredit,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
    };
  }
}
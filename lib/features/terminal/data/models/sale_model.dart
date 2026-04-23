enum PaymentMethod { cash, credit, card }

class SaleModel {
  final String id;
  final List<Map<String, dynamic>> items;
  final double total;
  final PaymentMethod paymentMethod;
  final bool isCredit;
  final String? customerId;
  final String? customerName;
  final DateTime createdAt;
  final String date; // YYYY-MM-DD

  SaleModel({
    required this.id,
    required this.items,
    required this.total,
    required this.paymentMethod,
    this.isCredit = false,
    this.customerId,
    this.customerName,
    DateTime? createdAt,
    String? date,
  })  : createdAt = createdAt ?? DateTime.now(),
        date = date ?? _dateKey(createdAt ?? DateTime.now());

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int get itemCount =>
      items.fold(0, (s, i) => s + ((i['quantity'] as num?)?.toInt() ?? 1));
}

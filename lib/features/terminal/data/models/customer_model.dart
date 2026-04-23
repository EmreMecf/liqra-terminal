class CustomerModel {
  final String id;
  final String name;
  final String? phone;
  final double totalDebt;

  const CustomerModel({
    required this.id,
    required this.name,
    this.phone,
    this.totalDebt = 0,
  });

  factory CustomerModel.fromMap(String id, Map<String, dynamic> d) {
    return CustomerModel(
      id:        id,
      name:      d['name']      as String? ?? '',
      phone:     d['phone']     as String?,
      totalDebt: (d['totalDebt'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'name':      name,
    if (phone != null) 'phone': phone,
    'totalDebt': totalDebt,
  };

  bool get hasDebt => totalDebt > 0;

  CustomerModel copyWith({double? totalDebt}) => CustomerModel(
    id:        id,
    name:      name,
    phone:     phone,
    totalDebt: totalDebt ?? this.totalDebt,
  );
}

class CreditEntry {
  final String id;
  final String customerId;
  final String customerName;
  final double amount;
  final bool isPaid;
  final String? saleId;
  final DateTime createdAt;

  CreditEntry({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.amount,
    this.isPaid = false,
    this.saleId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

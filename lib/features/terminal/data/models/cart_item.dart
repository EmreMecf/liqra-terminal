import 'product_model.dart';

class CartItem {
  final ProductModel product;
  int quantity;
  double discount; // 0.0 – 1.0

  CartItem({
    required this.product,
    this.quantity = 1,
    this.discount = 0.0,
  });

  double get unitPrice => product.price * (1 - discount);
  double get lineTotal => unitPrice * quantity;
  double get subtotal  => lineTotal; // alias

  CartItem copyWith({int? quantity, double? discount}) => CartItem(
    product:  product,
    quantity: quantity ?? this.quantity,
    discount: discount ?? this.discount,
  );

  Map<String, dynamic> toMap() => {
    'productId': product.id,
    'name':      product.name,
    'barcode':   product.barcode,
    'price':     product.price,
    'discount':  discount,
    'unitPrice': unitPrice,
    'quantity':  quantity,
    'lineTotal': lineTotal,
  };
}

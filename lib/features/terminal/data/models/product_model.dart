class ProductModel {
  final String id;
  final String name;
  final String barcode;
  final String category;
  final double price;
  final int stock;
  final String? unit;
  final String? imageUrl;
  final int totalSold;
  final bool isActive;

  const ProductModel({
    required this.id,
    required this.name,
    required this.barcode,
    required this.category,
    required this.price,
    required this.stock,
    this.unit,
    this.imageUrl,
    this.totalSold = 0,
    this.isActive = true,
  });

  factory ProductModel.fromMap(String id, Map<String, dynamic> d) {
    return ProductModel(
      id:        id,
      name:      d['name']      as String? ?? '',
      barcode:   d['barcode']   as String? ?? '',
      category:  d['category']  as String? ?? 'Genel',
      price:     (d['price']    as num?)?.toDouble() ?? 0,
      stock:     (d['stock']    as num?)?.toInt()    ?? 0,
      unit:      d['unit']      as String?,
      imageUrl:  d['imageUrl']  as String?,
      totalSold: (d['totalSold'] as num?)?.toInt() ?? 0,
      isActive:  d['isActive']  as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'id':        id,
    'name':      name,
    'barcode':   barcode,
    'category':  category,
    'price':     price,
    'stock':     stock,
    'isActive':  isActive,
    if (unit     != null) 'unit':     unit,
    if (imageUrl != null) 'imageUrl': imageUrl,
    'totalSold':  totalSold,
  };

  bool get isLowStock   => stock > 0 && stock <= 5;
  bool get isOutOfStock => stock <= 0;

  ProductModel copyWith({int? stock, int? totalSold}) => ProductModel(
    id:        id,
    name:      name,
    barcode:   barcode,
    category:  category,
    price:     price,
    stock:     stock     ?? this.stock,
    unit:      unit,
    imageUrl:  imageUrl,
    totalSold: totalSold ?? this.totalSold,
    isActive:  isActive,
  );
}

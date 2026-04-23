import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../data/models/cart_item.dart';
import '../data/models/customer_model.dart';
import '../data/models/product_model.dart';
import '../data/models/sale_model.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────
enum BarcodeState { idle, scanning, found, notFound }
enum TerminalMode  { sale, report }

// ── TerminalViewModel ─────────────────────────────────────────────────────────

class TerminalViewModel extends ChangeNotifier {
  final _uuid = const Uuid();

  // ─── Barkod buffer (USB Keyboard Wedge) ───────────────────────────────────
  final StringBuffer _barcodeBuffer = StringBuffer();
  Timer? _barcodeTimer;
  static const _barcodeTimeout = Duration(milliseconds: 100);

  BarcodeState _barcodeState = BarcodeState.idle;
  String _statusMessage      = '🟢 Barkod okuyucu hazır';
  bool   _statusIsError      = false;

  BarcodeState get barcodeState  => _barcodeState;
  String       get statusMessage => _statusMessage;
  bool         get statusIsError => _statusIsError;

  // ─── Ürünler ───────────────────────────────────────────────────────────────
  List<ProductModel> _allProducts = [];
  List<ProductModel> _products    = [];
  String?  _selectedCategory;
  String   _searchQuery = '';
  bool     _loading     = false;

  List<ProductModel> get products         => _products;
  List<ProductModel> get filteredProducts => _products;
  bool               get loading          => _loading;

  List<String> get categories => _allProducts
      .map((p) => p.category)
      .where((c) => c.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  String? get selectedCategory => _selectedCategory;

  // ─── Sepet ─────────────────────────────────────────────────────────────────
  final List<CartItem> _cart = [];
  int? _selectedIndex;

  List<CartItem> get cart          => List.unmodifiable(_cart);
  int?           get selectedIndex => _selectedIndex;
  double         get cartTotal     => _cart.fold(0.0, (s, i) => s + i.subtotal);
  bool           get cartEmpty     => _cart.isEmpty;

  // ─── Müşteri ───────────────────────────────────────────────────────────────
  List<CustomerModel> _customers = [];
  CustomerModel?      _selectedCustomer;

  List<CustomerModel> get customers        => _customers;
  CustomerModel?      get selectedCustomer => _selectedCustomer;

  // (Kamera - Windows'ta desteklenmiyor; F4 = Manuel barkod dialog)

  // ─── Günlük rapor ──────────────────────────────────────────────────────────
  final List<SaleModel> _allSales = [];
  List<SaleModel> get dailySales => _todaySales();

  double get dailyTotal => _todaySales()
      .where((s) => !s.isCredit)
      .fold(0.0, (s, sale) => s + sale.total);

  double get dailyCredit => _todaySales()
      .where((s) => s.isCredit)
      .fold(0.0, (s, sale) => s + sale.total);

  int get dailySaleCount => _todaySales().length;

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
  }

  List<SaleModel> _todaySales() =>
      _allSales.where((s) => s.date == _todayKey()).toList();

  // ─── Veresiye kayıtları (in-memory) ───────────────────────────────────────
  final List<CreditEntry> _creditEntries = [];
  List<CreditEntry> get creditEntries => List.unmodifiable(_creditEntries);

  // ─── Başlatma ──────────────────────────────────────────────────────────────

  void init() => _loadMockData();

  Future<void> refreshDailyReport() async {
    _loading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    _loading = false;
    notifyListeners();
  }

  void _loadMockData() {
    _allProducts = [
      ProductModel(id: 'p1',  name: 'Coca Cola 1L',        barcode: '8690526085578', category: 'İçecek',       price: 35,  stock: 48),
      ProductModel(id: 'p2',  name: 'Fanta Portakal 1L',   barcode: '8690526085579', category: 'İçecek',       price: 33,  stock: 32),
      ProductModel(id: 'p3',  name: 'Su 0.5L',             barcode: '8690526012312', category: 'İçecek',       price: 8,   stock: 120),
      ProductModel(id: 'p4',  name: 'Ayran 200ml',         barcode: '8690001111111', category: 'İçecek',       price: 12,  stock: 24),
      ProductModel(id: 'p5',  name: 'Ülker Çikolata 80g',  barcode: '8690504012345', category: 'Atıştırmalık', price: 22,  stock: 3,  totalSold: 150),
      ProductModel(id: 'p6',  name: 'Lay\'s Klasik 100g',  barcode: '8690526099001', category: 'Atıştırmalık', price: 30,  stock: 18),
      ProductModel(id: 'p7',  name: 'Ritz Kraker',         barcode: '8690502090909', category: 'Atıştırmalık', price: 28,  stock: 0),
      ProductModel(id: 'p8',  name: 'Ekmek 400g',          barcode: '1234567890123', category: 'Fırın',        price: 12,  stock: 15),
      ProductModel(id: 'p9',  name: 'Simit',               barcode: '1234567890124', category: 'Fırın',        price: 6,   stock: 20),
      ProductModel(id: 'p10', name: 'Süt 1L',              barcode: '8690001234567', category: 'Süt Ürünleri', price: 45,  stock: 20),
      ProductModel(id: 'p11', name: 'Peynir 200g',         barcode: '8690002345678', category: 'Süt Ürünleri', price: 85,  stock: 5),
      ProductModel(id: 'p12', name: 'Yoğurt 1kg',          barcode: '8690003456789', category: 'Süt Ürünleri', price: 55,  stock: 12),
      ProductModel(id: 'p13', name: 'Zeytinyağı 1L',       barcode: '8690551122334', category: 'Bakliyat',     price: 280, stock: 8),
      ProductModel(id: 'p14', name: 'Makarna 500g',        barcode: '8690551122335', category: 'Bakliyat',     price: 18,  stock: 40),
      ProductModel(id: 'p15', name: 'Pirinç 1kg',          barcode: '8690551122336', category: 'Bakliyat',     price: 65,  stock: 25),
      ProductModel(id: 'p16', name: 'Deterjan 1kg',        barcode: '8690701122001', category: 'Temizlik',     price: 95,  stock: 10),
      ProductModel(id: 'p17', name: 'Şampuan 400ml',       barcode: '8690701122002', category: 'Temizlik',     price: 75,  stock: 7),
      ProductModel(id: 'p18', name: 'Sigara Marlboro',     barcode: '8690701133001', category: 'Tütün',        price: 105, stock: 30),
    ];

    _customers = [
      CustomerModel(id: 'c1', name: 'Ahmet Yılmaz',   phone: '0555 111 2233', totalDebt: 150.50),
      CustomerModel(id: 'c2', name: 'Fatma Demir',    phone: '0532 444 5566', totalDebt: 0),
      CustomerModel(id: 'c3', name: 'Mehmet Kaya',    phone: '0541 888 9900', totalDebt: 340.00),
      CustomerModel(id: 'c4', name: 'Ayşe Çelik',     phone: '0533 222 3344', totalDebt: 0),
      CustomerModel(id: 'c5', name: 'Hasan Arslan',   phone: '0544 777 6655', totalDebt: 85.75),
    ];

    // Örnek bugünkü satışlar (demo ciro)
    final today = _todayKey();
    _allSales.addAll([
      SaleModel(id: _uuid.v4(), items: [], total: 145.50, paymentMethod: PaymentMethod.cash,   date: today, createdAt: DateTime.now().subtract(const Duration(hours: 3))),
      SaleModel(id: _uuid.v4(), items: [], total: 89.00,  paymentMethod: PaymentMethod.card,   date: today, createdAt: DateTime.now().subtract(const Duration(hours: 2))),
      SaleModel(id: _uuid.v4(), items: [], total: 230.00, paymentMethod: PaymentMethod.credit, isCredit: true, customerName: 'Ahmet Yılmaz', date: today, createdAt: DateTime.now().subtract(const Duration(hours: 1))),
    ]);

    _applyProductFilter();
  }

  // ─── Ürün filtresi ─────────────────────────────────────────────────────────

  void _applyProductFilter() {
    var list = _allProducts;
    if (_selectedCategory != null) {
      list = list.where((p) => p.category == _selectedCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) =>
          p.name.toLowerCase().contains(q) ||
          p.barcode.contains(q) ||
          p.category.toLowerCase().contains(q)).toList();
    }
    _products = list;
    notifyListeners();
  }

  void setCategory(String? category) {
    _selectedCategory = category;
    _applyProductFilter();
  }

  void setSearch(String query) {
    _searchQuery = query;
    _applyProductFilter();
  }

  // ─── Barkod (USB Keyboard Wedge) ──────────────────────────────────────────

  void handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.f1)    { _completeSaleAction(PaymentMethod.cash);   return; }
    if (key == LogicalKeyboardKey.f2)    { _completeSaleAction(PaymentMethod.credit); return; }
    if (key == LogicalKeyboardKey.f3)    { _completeSaleAction(PaymentMethod.card);   return; }
    // F4 → manuel barkod dialog — UI katmanında yönetiliyor (terminal_main_screen.dart)
    if (key == LogicalKeyboardKey.f5)    { refreshDailyReport(); return; }
    if (key == LogicalKeyboardKey.f6)    { clearCart(); return; }
    if (key == LogicalKeyboardKey.escape){ clearCart(); return; }
    if (key == LogicalKeyboardKey.delete){ _removeSelectedItem(); return; }
    if (key == LogicalKeyboardKey.add    || key == LogicalKeyboardKey.numpadAdd)      { adjustSelectedQty(1);  return; }
    if (key == LogicalKeyboardKey.minus  || key == LogicalKeyboardKey.numpadSubtract) { adjustSelectedQty(-1); return; }
    if (key == LogicalKeyboardKey.arrowUp)   { _moveSelection(-1); return; }
    if (key == LogicalKeyboardKey.arrowDown) { _moveSelection(1);  return; }
    if (key == LogicalKeyboardKey.enter  || key == LogicalKeyboardKey.numpadEnter) {
      _flushBarcodeBuffer(); return;
    }

    final char = event.character;
    if (char != null && char.isNotEmpty) {
      _barcodeBuffer.write(char);
      _barcodeTimer?.cancel();
      _barcodeTimer = Timer(_barcodeTimeout, _flushBarcodeBuffer);
    }
  }

  void _flushBarcodeBuffer() {
    final barcode = _barcodeBuffer.toString().trim();
    _barcodeBuffer.clear();
    _barcodeTimer?.cancel();
    if (barcode.isEmpty) return;
    lookupBarcode(barcode);
  }

  void lookupBarcode(String barcode) {
    _barcodeState = BarcodeState.scanning;
    _setStatus('🔍 Aranıyor: $barcode');
    notifyListeners();

    final match = _allProducts.where((p) => p.barcode == barcode).firstOrNull;
    if (match != null) {
      addToCart(match);
      _barcodeState = BarcodeState.found;
      _setStatus('✓ ${match.name} — ₺${match.price.toStringAsFixed(2)}');
      Timer(const Duration(seconds: 2), () {
        _barcodeState = BarcodeState.idle;
        _setStatus('🟢 Barkod okuyucu hazır');
      });
    } else {
      _barcodeState = BarcodeState.notFound;
      _setStatus('❌ Barkod bulunamadı: $barcode', error: true);
      Timer(const Duration(seconds: 2), () {
        _barcodeState = BarcodeState.idle;
        _setStatus('🟢 Barkod okuyucu hazır');
      });
    }
  }

  // ─── Sepet ─────────────────────────────────────────────────────────────────

  void addToCart(ProductModel product, {int quantity = 1}) {
    final idx = _cart.indexWhere((i) => i.product.id == product.id);
    if (idx >= 0) {
      _cart[idx] = _cart[idx].copyWith(quantity: _cart[idx].quantity + quantity);
      _selectedIndex = idx;
    } else {
      _cart.add(CartItem(product: product, quantity: quantity));
      _selectedIndex = _cart.length - 1;
    }
    notifyListeners();
  }

  void removeFromCart(dynamic productIdOrIndex) {
    if (productIdOrIndex is int) {
      if (productIdOrIndex < 0 || productIdOrIndex >= _cart.length) return;
      _cart.removeAt(productIdOrIndex);
    } else {
      _cart.removeWhere((i) => i.product.id == productIdOrIndex as String);
    }
    _selectedIndex = _cart.isEmpty ? null : (_selectedIndex ?? 0).clamp(0, _cart.length - 1);
    notifyListeners();
  }

  void _removeSelectedItem() {
    if (_selectedIndex == null || _cart.isEmpty) return;
    removeFromCart(_selectedIndex!);
  }

  void updateCartItemQuantity(dynamic productIdOrIndex, int quantity) {
    int idx;
    if (productIdOrIndex is int) {
      idx = productIdOrIndex;
    } else {
      idx = _cart.indexWhere((i) => i.product.id == productIdOrIndex as String);
    }
    if (idx < 0 || idx >= _cart.length) return;
    if (quantity <= 0) { removeFromCart(idx); return; }
    _cart[idx] = _cart[idx].copyWith(quantity: quantity);
    notifyListeners();
  }

  void adjustSelectedQty(int delta) {
    if (_selectedIndex == null) return;
    final item = _cart[_selectedIndex!];
    updateCartItemQuantity(_selectedIndex!, item.quantity + delta);
  }

  void selectCartItem(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  void _moveSelection(int delta) {
    if (_cart.isEmpty) return;
    final next = ((_selectedIndex ?? -1) + delta).clamp(0, _cart.length - 1);
    selectCartItem(next);
  }

  void clearCart() {
    _cart.clear();
    _selectedIndex    = null;
    _selectedCustomer = null;
    _setStatus('🗑 Sepet temizlendi');
  }

  // ─── Satış Tamamlama ───────────────────────────────────────────────────────

  void _completeSaleAction(PaymentMethod method) {
    if (_cart.isEmpty) return;
    completeSale(paymentMethodEnum: method);
  }

  /// Başarıda saleId döner, hata durumunda null döner.
  Future<String?> completeSale({
    PaymentMethod? paymentMethodEnum,
    CustomerModel? customer,
    bool isCredit = false,
  }) async {
    final method = paymentMethodEnum ?? PaymentMethod.cash;
    final isVer  = method == PaymentMethod.credit || isCredit;

    if (_cart.isEmpty) {
      _setStatus('⚠ Sepet boş!', error: true);
      return null;
    }
    if (isVer && customer == null && _selectedCustomer == null) {
      _setStatus('⚠ Veresiye için müşteri seçin', error: true);
      return null;
    }

    final cust = customer ?? _selectedCustomer;
    if (customer != null) _selectedCustomer = customer;

    _loading = true;
    notifyListeners();

    // Simüle async (gerçekte Firestore batch olur)
    await Future.delayed(const Duration(milliseconds: 250));

    final saleId   = _uuid.v4();
    final total    = cartTotal;
    final itemsList = _cart.map((i) => i.toMap()).toList();

    // Stokları düş
    for (final item in _cart) {
      final idx = _allProducts.indexWhere((p) => p.id == item.product.id);
      if (idx >= 0) {
        _allProducts[idx] = _allProducts[idx].copyWith(
          stock:     _allProducts[idx].stock     - item.quantity,
          totalSold: _allProducts[idx].totalSold + item.quantity,
        );
      }
    }

    // Satışı kaydet
    _allSales.add(SaleModel(
      id:            saleId,
      items:         itemsList,
      total:         total,
      paymentMethod: method,
      isCredit:      isVer,
      customerId:    cust?.id,
      customerName:  cust?.name,
    ));

    // Veresiye: müşteri borcunu güncelle
    if (isVer && cust != null) {
      final idx = _customers.indexWhere((c) => c.id == cust.id);
      if (idx >= 0) {
        _customers[idx] = _customers[idx].copyWith(
          totalDebt: _customers[idx].totalDebt + total,
        );
      }
      _creditEntries.add(CreditEntry(
        id:           _uuid.v4(),
        customerId:   cust.id,
        customerName: cust.name,
        amount:       total,
        saleId:       saleId,
      ));
    }

    final msg = isVer
        ? '✓ Veresiye: ₺${total.toStringAsFixed(2)} — ${cust?.name}'
        : '✓ Satış tamamlandı: ₺${total.toStringAsFixed(2)}';

    clearCart();
    _applyProductFilter(); // stok güncellemesini yansıt
    _loading = false;
    _setStatus(msg);

    return saleId;
  }

  // ─── Müşteri ───────────────────────────────────────────────────────────────

  void selectCustomer(CustomerModel c) {
    _selectedCustomer = c;
    notifyListeners();
  }

  Future<void> markCreditPaid(String entryId) async {
    final idx = _creditEntries.indexWhere((e) => e.id == entryId);
    if (idx < 0) return;
    final entry = _creditEntries[idx];
    _creditEntries[idx] = CreditEntry(
      id:           entry.id,
      customerId:   entry.customerId,
      customerName: entry.customerName,
      amount:       entry.amount,
      isPaid:       true,
      saleId:       entry.saleId,
      createdAt:    entry.createdAt,
    );
    final custIdx = _customers.indexWhere((c) => c.id == entry.customerId);
    if (custIdx >= 0) {
      _customers[custIdx] = _customers[custIdx].copyWith(
        totalDebt: (_customers[custIdx].totalDebt - entry.amount).clamp(0, double.infinity),
      );
    }
    notifyListeners();
  }

  // ─── Yardımcılar ───────────────────────────────────────────────────────────

  void _setStatus(String msg, {bool error = false}) {
    _statusMessage = msg;
    _statusIsError = error;
    notifyListeners();
  }
}

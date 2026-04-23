import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../core/database/database_service.dart';
import '../data/models/cart_item.dart';
import '../data/models/cari_model.dart';
import '../data/models/product_model.dart';
import '../data/models/sale_model.dart';

export '../data/models/sale_model.dart' show OdemeTip;
export '../data/models/cari_model.dart' show CariModel, CariTip;

// ── Enums ──────────────────────────────────────────────────────────────────────
enum BarcodeState { idle, scanning, found, notFound }

// ── TerminalViewModel ──────────────────────────────────────────────────────────

class TerminalViewModel extends ChangeNotifier {
  final _db = DatabaseService.instance;

  // ─── Barkod buffer (USB Keyboard Wedge) ───────────────────────────────────
  final StringBuffer _barcodeBuffer = StringBuffer();
  Timer?             _barcodeTimer;
  static const _barcodeTimeout = Duration(milliseconds: 100);

  BarcodeState _barcodeState = BarcodeState.idle;
  String       _statusMessage = '🟢 Barkod okuyucu hazır';
  bool         _statusIsError = false;

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
      .map((p) => p.kategori)
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

  // ─── Cari (Müşteri) ────────────────────────────────────────────────────────
  List<CariModel> _cariler      = [];
  CariModel?      _selectedCari;

  List<CariModel> get cariler      => _cariler;
  CariModel?      get selectedCari => _selectedCari;

  // ── Günlük rapor (DB'den) ─────────────────────────────────────────────────
  List<SaleModel> _dailySales = [];
  List<SaleModel> get dailySales => _dailySales;

  double get dailyTotal =>
      _dailySales.where((s) => !s.veresiyeMi).fold(0.0, (s, e) => s + e.toplam);
  double get dailyCredit =>
      _dailySales.where((s) => s.veresiyeMi).fold(0.0, (s, e) => s + e.toplam);
  int get dailySaleCount => _dailySales.length;

  // ══════════════════════════════════════════════════════════════════════════
  // BAŞLATMA
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    _loading = true;
    notifyListeners();
    await _seedIfEmpty();
    await Future.wait([_loadProducts(), _loadCariler(), refreshDailyReport()]);
    _loading = false;
    notifyListeners();
  }

  /// İlk çalışmada DB boşsa demo verisi ekle
  Future<void> _seedIfEmpty() async {
    final mevcut = await _db.tumUrunler();
    if (mevcut.isNotEmpty) return;

    final urunler = [
      ProductModel(id: 'p1',  ad: 'Coca Cola 1L',        barkod: '8690526085578', kategori: 'İçecek',       satisFiyati: 35,  alisFiyati: 22,  stok: 48),
      ProductModel(id: 'p2',  ad: 'Fanta Portakal 1L',   barkod: '8690526085579', kategori: 'İçecek',       satisFiyati: 33,  alisFiyati: 21,  stok: 32),
      ProductModel(id: 'p3',  ad: 'Su 0.5L',             barkod: '8690526012312', kategori: 'İçecek',       satisFiyati: 8,   alisFiyati: 3,   stok: 120),
      ProductModel(id: 'p4',  ad: 'Ayran 200ml',         barkod: '8690001111111', kategori: 'İçecek',       satisFiyati: 12,  alisFiyati: 6,   stok: 24),
      ProductModel(id: 'p5',  ad: 'Ülker Çikolata 80g',  barkod: '8690504012345', kategori: 'Atıştırmalık', satisFiyati: 22,  alisFiyati: 12,  stok: 3,  kritikStok: 5),
      ProductModel(id: 'p6',  ad: 'Lay\'s Klasik 100g',  barkod: '8690526099001', kategori: 'Atıştırmalık', satisFiyati: 30,  alisFiyati: 16,  stok: 18),
      ProductModel(id: 'p7',  ad: 'Ritz Kraker',         barkod: '8690502090909', kategori: 'Atıştırmalık', satisFiyati: 28,  alisFiyati: 15,  stok: 0),
      ProductModel(id: 'p8',  ad: 'Ekmek 400g',          barkod: '1234567890123', kategori: 'Fırın',        satisFiyati: 12,  alisFiyati: 7,   stok: 15),
      ProductModel(id: 'p9',  ad: 'Simit',               barkod: '1234567890124', kategori: 'Fırın',        satisFiyati: 6,   alisFiyati: 3,   stok: 20),
      ProductModel(id: 'p10', ad: 'Süt 1L',              barkod: '8690001234567', kategori: 'Süt Ürünleri', satisFiyati: 45,  alisFiyati: 30,  stok: 20),
      ProductModel(id: 'p11', ad: 'Peynir 200g',         barkod: '8690002345678', kategori: 'Süt Ürünleri', satisFiyati: 85,  alisFiyati: 55,  stok: 5, kritikStok: 5),
      ProductModel(id: 'p12', ad: 'Yoğurt 1kg',          barkod: '8690003456789', kategori: 'Süt Ürünleri', satisFiyati: 55,  alisFiyati: 35,  stok: 12),
      ProductModel(id: 'p13', ad: 'Zeytinyağı 1L',       barkod: '8690551122334', kategori: 'Bakliyat',     satisFiyati: 280, alisFiyati: 200, stok: 8),
      ProductModel(id: 'p14', ad: 'Makarna 500g',        barkod: '8690551122335', kategori: 'Bakliyat',     satisFiyati: 18,  alisFiyati: 10,  stok: 40),
      ProductModel(id: 'p15', ad: 'Pirinç 1kg',          barkod: '8690551122336', kategori: 'Bakliyat',     satisFiyati: 65,  alisFiyati: 42,  stok: 25),
      ProductModel(id: 'p16', ad: 'Deterjan 1kg',        barkod: '8690701122001', kategori: 'Temizlik',     satisFiyati: 95,  alisFiyati: 60,  stok: 10),
      ProductModel(id: 'p17', ad: 'Şampuan 400ml',       barkod: '8690701122002', kategori: 'Temizlik',     satisFiyati: 75,  alisFiyati: 48,  stok: 7),
      ProductModel(id: 'p18', ad: 'Sigara Marlboro',     barkod: '8690701133001', kategori: 'Tütün',        satisFiyati: 105, alisFiyati: 85,  stok: 30),
    ];

    for (final u in urunler) {
      await _db.urunEkle(u);
    }

    // Demo cariler
    final cariler = [
      CariModel(id: 'c1', ad: 'Ahmet Yılmaz',   tip: CariTip.musteri,  telefon: '0555 111 2233', bakiye: 150.50, olusturmaTarihi: DateTime.now()),
      CariModel(id: 'c2', ad: 'Fatma Demir',    tip: CariTip.musteri,  telefon: '0532 444 5566', olusturmaTarihi: DateTime.now()),
      CariModel(id: 'c3', ad: 'Mehmet Kaya',    tip: CariTip.musteri,  telefon: '0541 888 9900', bakiye: 340.00, olusturmaTarihi: DateTime.now()),
      CariModel(id: 'c4', ad: 'Ayşe Çelik',     tip: CariTip.musteri,  telefon: '0533 222 3344', olusturmaTarihi: DateTime.now()),
      CariModel(id: 'c5', ad: 'Hasan Arslan',   tip: CariTip.musteri,  telefon: '0544 777 6655', bakiye: 85.75,  olusturmaTarihi: DateTime.now()),
      CariModel(id: 't1', ad: 'Coca Cola Dağıtım', tip: CariTip.tedarikci, telefon: '0212 500 0001', bakiye: -2400.0, olusturmaTarihi: DateTime.now()),
      CariModel(id: 't2', ad: 'Ülker Gıda',     tip: CariTip.tedarikci, telefon: '0212 500 0002', bakiye: -1800.0, olusturmaTarihi: DateTime.now()),
    ];
    for (final c in cariler) {
      await _db.cariEkle(c);
    }
  }

  Future<void> _loadProducts() async {
    _allProducts = await _db.tumUrunler();
    _applyProductFilter();
  }

  Future<void> _loadCariler() async {
    _cariler = await _db.tumCariler(tip: CariTip.musteri);
    notifyListeners();
  }

  Future<void> refreshDailyReport() async {
    final key = _todayKey();
    _dailySales = await _db.gunlukSatislar(key);
    notifyListeners();
  }

  // ── Ürün filtresi ─────────────────────────────────────────────────────────

  void _applyProductFilter() {
    var list = _allProducts;
    if (_selectedCategory != null) {
      list = list.where((p) => p.kategori == _selectedCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) =>
          p.ad.toLowerCase().contains(q) ||
          p.barkod.contains(q) ||
          p.kategori.toLowerCase().contains(q)).toList();
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

  // ── Barkod (USB Keyboard Wedge) ───────────────────────────────────────────

  void handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.f1)    { _completeSaleAction(OdemeTip.nakit);      return; }
    if (key == LogicalKeyboardKey.f2)    { _completeSaleAction(OdemeTip.veresiye);   return; }
    if (key == LogicalKeyboardKey.f3)    { _completeSaleAction(OdemeTip.krediKarti); return; }
    // F4 → manuel barkod dialog — UI katmanında yönetiliyor
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

    final match = _allProducts.where((p) => p.barkod == barcode).firstOrNull;
    if (match != null) {
      addToCart(match);
      _barcodeState = BarcodeState.found;
      _setStatus('✓ ${match.ad} — ₺${match.satisFiyati.toStringAsFixed(2)}');
      Timer(const Duration(seconds: 2), () {
        _barcodeState = BarcodeState.idle;
        _setStatus('🟢 Barkod okuyucu hazır');
        notifyListeners();
      });
    } else {
      _barcodeState = BarcodeState.notFound;
      _setStatus('❌ Barkod bulunamadı: $barcode', error: true);
      Timer(const Duration(seconds: 2), () {
        _barcodeState = BarcodeState.idle;
        _setStatus('🟢 Barkod okuyucu hazır');
        notifyListeners();
      });
    }
  }

  // ── Sepet ─────────────────────────────────────────────────────────────────

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
    _selectedIndex = null;
    _selectedCari  = null;
    _setStatus('🗑 Sepet temizlendi');
  }

  // ── Satış Tamamlama ───────────────────────────────────────────────────────

  void _completeSaleAction(OdemeTip odemeTip) {
    if (_cart.isEmpty) return;
    if (odemeTip == OdemeTip.veresiye && _selectedCari == null) {
      _setStatus('⚠ Veresiye için müşteri seçin', error: true);
      return;
    }
    completeSale(odemeTip: odemeTip);
  }

  /// Başarıda saleId döner, hata durumunda null döner.
  Future<String?> completeSale({
    OdemeTip?   odemeTip,
    CariModel?  cari,
  }) async {
    final tip  = odemeTip ?? OdemeTip.nakit;
    final cust = cari ?? _selectedCari;

    if (_cart.isEmpty) {
      _setStatus('⚠ Sepet boş!', error: true);
      return null;
    }
    if (tip == OdemeTip.veresiye && cust == null) {
      _setStatus('⚠ Veresiye için müşteri seçin', error: true);
      return null;
    }

    if (cari != null) _selectedCari = cari;

    _loading = true;
    notifyListeners();

    // CartItem → SatisKalemi dönüşümü
    final kalemler = _cart.map((item) => SatisKalemi(
      urunId:      item.product.id,
      urunAdi:     item.product.ad,
      barkod:      item.product.barkod,
      satisFiyati: item.product.satisFiyati,
      alisFiyati:  item.product.alisFiyati,
      indirim:     item.discount,
      miktar:      item.quantity,
    )).toList();

    String? saleId;
    try {
      saleId = await _db.satisKaydet(
        kalemler: kalemler,
        odemeTip: tip,
        cari:     tip == OdemeTip.veresiye ? cust : null,
        kasaId:   tip == OdemeTip.krediKarti ? 'pos' : 'nakit',
      );

      final msg = tip == OdemeTip.veresiye
          ? '✓ Veresiye: ₺${cartTotal.toStringAsFixed(2)} — ${cust?.ad}'
          : '✓ Satış tamamlandı: ₺${cartTotal.toStringAsFixed(2)}';

      clearCart();
      // Stok ve satışları yenile
      await Future.wait([_loadProducts(), refreshDailyReport()]);
      _setStatus(msg);
    } catch (e) {
      _setStatus('❌ Hata: $e', error: true);
    }

    _loading = false;
    notifyListeners();
    return saleId;
  }

  // ── Cari ─────────────────────────────────────────────────────────────────

  void selectCari(CariModel c) {
    _selectedCari = c;
    notifyListeners();
  }

  // Eski UI uyumluluğu için alias
  void selectCustomer(dynamic c) {
    if (c is CariModel) selectCari(c);
  }

  // ── Yardımcılar ───────────────────────────────────────────────────────────

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
  }

  void _setStatus(String msg, {bool error = false}) {
    _statusMessage = msg;
    _statusIsError = error;
    notifyListeners();
  }
}

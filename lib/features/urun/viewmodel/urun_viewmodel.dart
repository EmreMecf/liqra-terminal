import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database_service.dart';
import '../../terminal/data/models/product_model.dart';

export '../../terminal/data/models/product_model.dart' show ProductModel;

// ══════════════════════════════════════════════════════════════════════════════
// ImportSonuc — topluUrunImport sonucu
// ══════════════════════════════════════════════════════════════════════════════

class ImportSonuc {
  final int     eklenen;
  final int     guncellenen;
  final int     atlanan;
  final String? hata;

  const ImportSonuc({
    required this.eklenen,
    required this.guncellenen,
    required this.atlanan,
    this.hata,
  });

  bool get basarili => hata == null;
  int  get toplam   => eklenen + guncellenen;
}

// ══════════════════════════════════════════════════════════════════════════════
// UrunViewModel
// ══════════════════════════════════════════════════════════════════════════════

class UrunViewModel extends ChangeNotifier {
  final _db   = DatabaseService.instance;
  final _uuid = const Uuid();

  // ── Liste & Filtreleme ─────────────────────────────────────────────────────
  List<ProductModel> _urunler  = [];
  List<ProductModel> _filtered = [];
  String  _aramaMetni       = '';
  String? _secilenKategori;
  bool    _sadecAktif       = true;
  bool    _loading          = false;

  List<ProductModel> get filtered          => _filtered;
  List<ProductModel> get tumUrunler        => _urunler;
  bool               get loading           => _loading;
  String             get aramaMetni        => _aramaMetni;
  String?            get secilenKategori   => _secilenKategori;

  List<String> get kategoriler =>
      _urunler.map((p) => p.kategori).where((k) => k.isNotEmpty).toSet().toList()..sort();

  // ── Seçili Ürün ────────────────────────────────────────────────────────────
  ProductModel? _secilenUrun;
  ProductModel? get secilenUrun => _secilenUrun;

  // ── Import Sonucu ──────────────────────────────────────────────────────────
  ImportSonuc? _sonImport;
  ImportSonuc? get sonImport => _sonImport;

  // ── Özet istatistikler ─────────────────────────────────────────────────────
  int    get toplamUrun        => _urunler.length;
  int    get kritikStokSayisi  => _urunler.where((p) => p.stokKritik).length;
  int    get stokSifirSayisi   => _urunler.where((p) => p.stokTukendi).length;
  double get ortalamaSatisFiyati =>
      _urunler.isEmpty ? 0 : _urunler.fold(0.0, (s, p) => s + p.satisFiyati) / _urunler.length;

  // ══════════════════════════════════════════════════════════════════════════
  // Public API
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> init() => _yukle();

  /// Arama metnini değiştir
  void ara(String metin) {
    _aramaMetni = metin;
    _filtrele();
  }

  /// Kategori filtresi — null = hepsi
  void kategoriSec(String? kat) {
    _secilenKategori = kat;
    _filtrele();
  }

  /// Aktif/pasif görünüm
  void sadecAktifToggle() {
    _sadecAktif = !_sadecAktif;
    _yukle();
  }

  void urunSec(ProductModel? p) {
    _secilenUrun = p;
    notifyListeners();
  }

  /// Yeni ürün oluştur (form için boş şablon)
  ProductModel yeniUrunSablonu() => ProductModel(
    id:          _uuid.v4(),
    ad:          '',
    barkod:      otomatikBarkod(),
    kategori:    _secilenKategori ?? 'Genel',
    satisFiyati: 0,
    alisFiyati:  0,
    stok:        0,
    kritikStok:  5,
  );

  /// Kaydet (yeni veya güncelleme)
  Future<bool> kaydet(ProductModel p) async {
    try {
      final varMi = _urunler.any((u) => u.id == p.id);
      if (varMi) {
        await _db.urunGuncelle(p);
      } else {
        await _db.urunEkle(p);
      }
      await _yukle();
      _secilenUrun = _urunler.firstWhere((u) => u.id == p.id, orElse: () => p);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('UrunViewModel.kaydet hata: $e');
      return false;
    }
  }

  /// Ürünü deaktive et (satış geçmişini bozmaz)
  Future<bool> sil(String id) async {
    try {
      await _db.urunDeaktive(id);
      if (_secilenUrun?.id == id) _secilenUrun = null;
      await _yukle();
      return true;
    } catch (e) {
      debugPrint('UrunViewModel.sil hata: $e');
      return false;
    }
  }

  /// CSV'den dönüştürülen ürün listesini toplu kaydet
  Future<ImportSonuc> csvImport(
    List<ProductModel> urunler, {
    bool guncelle = true,
  }) async {
    try {
      final sonuc = await _db.topluUrunImport(urunler, guncelle: guncelle);
      await _yukle();
      _sonImport = ImportSonuc(
        eklenen:    sonuc['eklenen']!,
        guncellenen: sonuc['guncellenen']!,
        atlanan:    sonuc['atlanan']!,
      );
      notifyListeners();
      return _sonImport!;
    } catch (e) {
      final hata = ImportSonuc(eklenen: 0, guncellenen: 0, atlanan: 0, hata: e.toString());
      _sonImport = hata;
      notifyListeners();
      return hata;
    }
  }

  /// Benzersiz dahili barkod üretir — "LQR" + 8 rastgele rakam
  static String otomatikBarkod() {
    final rand = Random();
    final seq  = List.generate(8, (_) => rand.nextInt(10)).join();
    return 'LQR$seq';
  }

  /// Barkodun başka bir üründe kullanılıp kullanılmadığını kontrol eder
  bool barkodKullanimda(String barkod, {String? haricId}) =>
      _urunler.any((u) => u.barkod == barkod && u.id != haricId);

  // ══════════════════════════════════════════════════════════════════════════
  // İç
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _yukle() async {
    _loading = true;
    notifyListeners();
    _urunler = await _db.tumUrunler(sadecAktif: _sadecAktif);
    _filtrele();
    _loading = false;
    notifyListeners();
  }

  void _filtrele() {
    var liste = _urunler;
    if (_secilenKategori != null) {
      liste = liste.where((p) => p.kategori == _secilenKategori).toList();
    }
    if (_aramaMetni.isNotEmpty) {
      final q = _aramaMetni.toLowerCase();
      liste = liste
          .where((p) =>
              p.ad.toLowerCase().contains(q) ||
              p.barkod.toLowerCase().contains(q) ||
              p.kategori.toLowerCase().contains(q))
          .toList();
    }
    _filtered = liste;
    notifyListeners();
  }
}

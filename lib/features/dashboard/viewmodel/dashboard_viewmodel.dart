import 'package:flutter/foundation.dart';

import '../../../core/database/database_service.dart';
import '../../terminal/data/models/product_model.dart';
import '../../terminal/data/models/kasa_model.dart';
import '../../terminal/data/models/sale_model.dart';

enum DashboardDonem { bugun, buHafta, buAy, gecenAy }

class DashboardViewModel extends ChangeNotifier {
  final _db = DatabaseService.instance;

  // ─── State ─────────────────────────────────────────────────────────────────
  bool             _loading      = false;
  DashboardDonem   _donem        = DashboardDonem.bugun;

  // ─── Özet veriler ──────────────────────────────────────────────────────────
  double _ciro           = 0;
  double _kar            = 0;
  double _gider          = 0;
  double _toplamAlacak   = 0;
  double _toplamBorc     = 0;

  // ─── Listeler ──────────────────────────────────────────────────────────────
  List<SaleModel>    _satislar       = [];
  List<ProductModel> _kritikStoklar  = [];
  List<KasaModel>    _kasalar        = [];

  // ─── Günlük grafik verisi ─────────────────────────────────────────────────
  // [gün_etiketi → ciro] — son 7 gün
  List<MapEntry<String, double>> _gunlukCiro = [];

  // ─── Getters ──────────────────────────────────────────────────────────────
  bool             get loading        => _loading;
  DashboardDonem   get donem          => _donem;
  double           get ciro           => _ciro;
  double           get kar            => _kar;
  double           get gider          => _gider;
  double           get netKar         => _kar - _gider;
  double           get toplamAlacak   => _toplamAlacak;
  double           get toplamBorc     => _toplamBorc;
  List<SaleModel>  get satislar       => _satislar;
  List<ProductModel> get kritikStoklar => _kritikStoklar;
  List<KasaModel>  get kasalar        => _kasalar;
  List<MapEntry<String, double>> get gunlukCiro => _gunlukCiro;

  int get satisAdedi => _satislar.length;
  double get kasaToplami =>
      _kasalar.fold(0.0, (s, k) => s + k.bakiye);

  // ══════════════════════════════════════════════════════════════════════════
  // YÜKLEME
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> init() => yenile();

  Future<void> yenile() async {
    _loading = true;
    notifyListeners();

    final (bas, bit) = _donemAraligi(_donem);
    final basKey     = _dateKey(bas);
    final bitKey     = _dateKey(bit);

    await Future.wait([
      _yukleOzet(basKey, bitKey),
      _yukleSatislar(bitKey),         // günün satışları
      _yukleKritikStok(),
      _yukleKasalar(),
      _yukleGunlukCiro(),
    ]);

    _loading = false;
    notifyListeners();
  }

  Future<void> setDonem(DashboardDonem d) async {
    _donem = d;
    await yenile();
  }

  // ─── Özel yükleme metotları ────────────────────────────────────────────────

  Future<void> _yukleOzet(String bas, String bit) async {
    try {
      final ozet = await _db.donemOzeti(baslangicKey: bas, bitisKey: bit);
      _ciro         = ozet['ciro']          ?? 0;
      _kar          = ozet['kar']           ?? 0;
      _gider        = ozet['gider']         ?? 0;
      _toplamAlacak = ozet['toplam_alacak'] ?? 0;
      _toplamBorc   = ozet['toplam_borc']   ?? 0;
    } catch (_) {}
  }

  Future<void> _yukleSatislar(String tarihKey) async {
    try {
      _satislar = await _db.gunlukSatislar(tarihKey);
    } catch (_) {
      _satislar = [];
    }
  }

  Future<void> _yukleKritikStok() async {
    try {
      _kritikStoklar = await _db.kritikStokUrunler();
    } catch (_) {
      _kritikStoklar = [];
    }
  }

  Future<void> _yukleKasalar() async {
    try {
      _kasalar = await _db.tumKasalar();
    } catch (_) {
      _kasalar = [];
    }
  }

  Future<void> _yukleGunlukCiro() async {
    // Son 7 gün için günlük satış toplamları
    final map = <String, double>{};
    for (var i = 6; i >= 0; i--) {
      final gun = DateTime.now().subtract(Duration(days: i));
      final key = _dateKey(gun);
      final etiket = '${gun.day}/${gun.month}';
      try {
        final satislar = await _db.gunlukSatislar(key);
        final toplam   = satislar.fold(0.0, (s, e) => s + e.toplam);
        map[etiket] = toplam;
      } catch (_) {
        map[etiket] = 0;
      }
    }
    _gunlukCiro = map.entries.toList();
  }

  // ─── Yardımcılar ──────────────────────────────────────────────────────────

  static (DateTime, DateTime) _donemAraligi(DashboardDonem d) {
    final now = DateTime.now();
    return switch (d) {
      DashboardDonem.bugun     => (DateTime(now.year, now.month, now.day), now),
      DashboardDonem.buHafta   => (now.subtract(Duration(days: now.weekday - 1)), now),
      DashboardDonem.buAy      => (DateTime(now.year, now.month, 1), now),
      DashboardDonem.gecenAy   => (
          DateTime(now.year, now.month - 1, 1),
          DateTime(now.year, now.month, 0),
        ),
    };
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

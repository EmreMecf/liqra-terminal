import 'package:flutter/foundation.dart';

import '../../../core/database/database_service.dart';
import '../../terminal/data/models/sale_model.dart';
import '../data/models/rapor_models.dart';

export '../data/models/rapor_models.dart';
export '../../terminal/data/models/sale_model.dart' show SaleModel, OdemeTip;

// ══════════════════════════════════════════════════════════════════════════════
// RaporViewModel
// ══════════════════════════════════════════════════════════════════════════════

class RaporViewModel extends ChangeNotifier {
  final _db = DatabaseService.instance;

  // ── Dönem ──────────────────────────────────────────────────────────────────
  RaporDonem _donem        = RaporDonem.bugun;
  DateTime?  _ozelBaslangic;
  DateTime?  _ozelBitis;

  RaporDonem get donem         => _donem;
  DateTime?  get ozelBaslangic => _ozelBaslangic;
  DateTime?  get ozelBitis     => _ozelBitis;

  /// Aktif dönemin başlangıç-bitiş DateTime çifti
  (DateTime, DateTime) get aralik {
    final now = DateTime.now();
    final bugun = DateTime(now.year, now.month, now.day);

    return switch (_donem) {
      RaporDonem.bugun   => (bugun, DateTime(now.year, now.month, now.day, 23, 59, 59)),
      RaporDonem.dun     => (
          bugun.subtract(const Duration(days: 1)),
          DateTime(now.year, now.month, now.day, 0, 0, 0)
              .subtract(const Duration(seconds: 1)),
        ),
      RaporDonem.buHafta => (
          bugun.subtract(Duration(days: now.weekday - 1)),
          DateTime(now.year, now.month, now.day, 23, 59, 59),
        ),
      RaporDonem.buAy    => (
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month, now.day, 23, 59, 59),
        ),
      RaporDonem.gecenAy => () {
          final gecen = DateTime(now.year, now.month - 1);
          return (
            DateTime(gecen.year, gecen.month, 1),
            DateTime(now.year, now.month, 1).subtract(const Duration(seconds: 1)),
          );
        }(),
      RaporDonem.ozel    => (
          _ozelBaslangic ?? DateTime(now.year, now.month, 1),
          _ozelBitis     != null
              ? DateTime(_ozelBitis!.year, _ozelBitis!.month, _ozelBitis!.day, 23, 59, 59)
              : DateTime(now.year, now.month, now.day, 23, 59, 59),
        ),
    };
  }

  // ── Yükleme durumu ─────────────────────────────────────────────────────────
  bool _loading = false;
  bool get loading => _loading;

  // ── Satış listesi ──────────────────────────────────────────────────────────
  List<SaleModel> _satislar = [];
  SaleModel?      _secilenSatis;

  List<SaleModel> get satislar      => _satislar;
  SaleModel?      get secilenSatis  => _secilenSatis;

  // ── KPI getters ────────────────────────────────────────────────────────────
  double get toplamCiro     => _satislar.fold(0.0, (s, e) => s + e.toplam);
  double get toplamKar      => _satislar.fold(0.0, (s, e) => s + e.karToplami);
  int    get satisSayisi    => _satislar.length;
  double get ortalamaSepet  => satisSayisi > 0 ? toplamCiro / satisSayisi : 0;

  int get nakitSayisi    => _satislar.where((s) => s.odemeTip == OdemeTip.nakit).length;
  int get kartSayisi     => _satislar.where((s) => s.odemeTip == OdemeTip.krediKarti).length;
  int get veresiyeSayisi => _satislar.where((s) => s.odemeTip == OdemeTip.veresiye).length;

  double get nakitCiro    => _satislar
      .where((s) => s.odemeTip == OdemeTip.nakit)
      .fold(0.0, (s, e) => s + e.toplam);
  double get kartCiro     => _satislar
      .where((s) => s.odemeTip == OdemeTip.krediKarti)
      .fold(0.0, (s, e) => s + e.toplam);
  double get veresiyeCiro => _satislar
      .where((s) => s.odemeTip == OdemeTip.veresiye)
      .fold(0.0, (s, e) => s + e.toplam);

  // ── Grafik verileri ────────────────────────────────────────────────────────
  List<SaatlikOzet> _saatlikVeri = [];
  List<GunlukOzet>  _gunlukVeri  = [];
  List<AylikOzet>   _aylikVeri   = [];

  List<SaatlikOzet> get saatlikVeri => _saatlikVeri;
  List<GunlukOzet>  get gunlukVeri  => _gunlukVeri;
  List<AylikOzet>   get aylikVeri   => _aylikVeri;

  // hangi grafik türü gösterilmeli
  bool get gosterSaatlik => _donem == RaporDonem.bugun || _donem == RaporDonem.dun;
  bool get gosterGunluk  => _donem == RaporDonem.buHafta || _donem == RaporDonem.buAy
                           || _donem == RaporDonem.gecenAy;
  bool get gosterAylik   => _donem == RaporDonem.ozel; // özel → aylık göster

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> init() => _yukle();

  Future<void> donemDegistir(RaporDonem yeniDonem) async {
    if (_donem == yeniDonem) return;
    _donem        = yeniDonem;
    _secilenSatis = null;
    await _yukle();
  }

  Future<void> ozelAralikAyarla(DateTime bas, DateTime bit) async {
    _donem        = RaporDonem.ozel;
    _ozelBaslangic = bas;
    _ozelBitis     = bit;
    _secilenSatis  = null;
    await _yukle();
  }

  void satisSec(SaleModel? satis) {
    _secilenSatis = satis;
    notifyListeners();
  }

  Future<void> yenile() => _yukle();

  // ── İç yükleme ─────────────────────────────────────────────────────────────

  Future<void> _yukle() async {
    _loading = true;
    notifyListeners();

    try {
      final (bas, bit) = aralik;
      final now        = DateTime.now();

      _satislar = await _db.satisByAralik(baslangic: bas, bitis: bit);

      // Grafik verileri
      if (gosterSaatlik) {
        final gun = _donem == RaporDonem.bugun
            ? now
            : now.subtract(const Duration(days: 1));
        _saatlikVeri = await _db.saatlikDagilim(gun);
        _gunlukVeri  = [];
        _aylikVeri   = [];
      } else if (gosterGunluk) {
        final hedefAy = _donem == RaporDonem.gecenAy
            ? DateTime(now.year, now.month - 1)
            : now;
        _gunlukVeri  = await _db.gunlukCiroListesi(hedefAy.year, hedefAy.month);
        _saatlikVeri = [];
        _aylikVeri   = [];
      } else {
        // Özel aralık → aylık özet
        _aylikVeri   = await _db.aylikPerformans(now.year);
        _saatlikVeri = [];
        _gunlukVeri  = [];
      }
    } catch (e) {
      debugPrint('RaporViewModel._yukle hata: $e');
    }

    _loading = false;
    notifyListeners();
  }
}

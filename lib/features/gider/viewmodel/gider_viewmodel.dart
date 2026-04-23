import 'package:flutter/foundation.dart';

import '../../../core/database/database_service.dart';
import '../../terminal/data/models/gider_model.dart';
import '../../terminal/data/models/kasa_model.dart';

class GiderViewModel extends ChangeNotifier {
  final _db = DatabaseService.instance;

  // ─── State ─────────────────────────────────────────────────────────────────
  List<GiderModel> _giderler    = [];
  List<KasaModel>  _kasalar     = [];
  bool             _loading     = false;
  String           _error       = '';

  // ─── Dönem seçimi ──────────────────────────────────────────────────────────
  DateTime _baslangic = DateTime.now().copyWith(day: 1);
  DateTime _bitis     = DateTime.now();

  List<GiderModel> get giderler   => _giderler;
  List<KasaModel>  get kasalar    => _kasalar;
  bool             get loading    => _loading;
  String           get error      => _error;
  DateTime         get baslangic  => _baslangic;
  DateTime         get bitis      => _bitis;

  // ─── Özet ──────────────────────────────────────────────────────────────────
  double get toplamGider =>
      _giderler.fold(0.0, (s, g) => s + g.tutar);

  Map<GiderKategori, double> get kategoriOzeti {
    final map = <GiderKategori, double>{};
    for (final g in _giderler) {
      map[g.kategori] = (map[g.kategori] ?? 0) + g.tutar;
    }
    return map;
  }

  // ── Chart data: son 7 günün günlük toplamları ─────────────────────────────
  List<MapEntry<String, double>> get gunlukGrafikVerisi {
    final map = <String, double>{};
    for (var i = 6; i >= 0; i--) {
      final gun = DateTime.now().subtract(Duration(days: i));
      final key = '${gun.day}/${gun.month}';
      map[key] = 0;
    }
    for (final g in _giderler) {
      final key = '${g.tarih.day}/${g.tarih.month}';
      if (map.containsKey(key)) map[key] = (map[key] ?? 0) + g.tutar;
    }
    return map.entries.toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // YÜKLEME
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    await Future.wait([yukleGiderler(), yukleKasalar()]);
  }

  Future<void> yukleGiderler() async {
    _loading = true;
    notifyListeners();
    try {
      _giderler = await _db.donemGiderleri(
        _dateKey(_baslangic),
        _dateKey(_bitis),
      );
      _error = '';
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> yukleKasalar() async {
    _kasalar = await _db.tumKasalar();
    notifyListeners();
  }

  void setDonem(DateTime baslangic, DateTime bitis) {
    _baslangic = baslangic;
    _bitis     = bitis;
    yukleGiderler();
  }

  void setAylikGorunum(int yil, int ay) {
    _baslangic = DateTime(yil, ay, 1);
    final sonGun = DateTime(yil, ay + 1, 0).day;
    _bitis = DateTime(yil, ay, sonGun);
    yukleGiderler();
  }

  // ── Gider Kayıt ───────────────────────────────────────────────────────────

  Future<bool> giderEkle({
    required GiderKategori kategori,
    required double        tutar,
    required String        kasaId,
    String?                aciklama,
    DateTime?              tarih,
  }) async {
    try {
      await _db.giderKaydet(
        kategori: kategori,
        tutar:    tutar,
        kasaId:   kasaId,
        aciklama: aciklama,
        tarih:    tarih,
      );
      await yukleGiderler();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── Yardımcı ──────────────────────────────────────────────────────────────
  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database_service.dart';
import '../../terminal/data/models/cari_hareket_model.dart';
import '../../terminal/data/models/cari_model.dart';
import '../../terminal/data/models/kasa_model.dart';

// ── State ─────────────────────────────────────────────────────────────────────

enum CariViewState { idle, loading, loaded, error }

class CariViewModel extends ChangeNotifier {
  final _db   = DatabaseService.instance;
  final _uuid = const Uuid();

  // ─── Cari listesi ──────────────────────────────────────────────────────────
  List<CariModel> _cariler     = [];
  List<CariModel> _filtered    = [];
  CariViewState   _state       = CariViewState.idle;
  String          _error       = '';
  String          _searchQuery = '';
  CariTip?        _tipFilter;

  List<CariModel> get cariler     => _filtered;
  CariViewState   get state       => _state;
  String          get error       => _error;
  CariTip?        get tipFilter   => _tipFilter;

  // ─── Ekstre ────────────────────────────────────────────────────────────────
  List<CariHareket> _ekstre    = [];
  CariModel?        _secilenCari;
  bool              _ekstreLoading = false;

  List<CariHareket> get ekstre        => _ekstre;
  CariModel?        get secilenCari   => _secilenCari;
  bool              get ekstreLoading => _ekstreLoading;

  // ─── Kasalar ───────────────────────────────────────────────────────────────
  List<KasaModel> _kasalar = [];
  List<KasaModel> get kasalar => _kasalar;

  // ─── Özet ──────────────────────────────────────────────────────────────────
  double get toplamAlacak =>
      _cariler.where((c) => c.bakiye > 0).fold(0.0, (s, c) => s + c.bakiye);
  double get toplamBorc =>
      _cariler.where((c) => c.bakiye < 0).fold(0.0, (s, c) => s + c.bakiye.abs());

  // ══════════════════════════════════════════════════════════════════════════
  // YÜKLEME
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    await Future.wait([yukleCari(), yukleKasalar()]);
  }

  Future<void> yukleCari() async {
    _state = CariViewState.loading;
    notifyListeners();
    try {
      _cariler = await _db.tumCariler();
      _applyFilter();
      _state = CariViewState.loaded;
    } catch (e) {
      _error = e.toString();
      _state = CariViewState.error;
    }
    notifyListeners();
  }

  Future<void> yukleKasalar() async {
    _kasalar = await _db.tumKasalar();
    notifyListeners();
  }

  // ── Filtre ────────────────────────────────────────────────────────────────

  void setSearch(String q) {
    _searchQuery = q;
    _applyFilter();
  }

  void setTipFilter(CariTip? tip) {
    _tipFilter = tip;
    _applyFilter();
  }

  void _applyFilter() {
    var list = _cariler;
    if (_tipFilter != null) {
      list = list.where((c) => c.tip == _tipFilter || c.tip == CariTip.ikisi).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((c) =>
          c.ad.toLowerCase().contains(q) ||
          (c.telefon ?? '').contains(q) ||
          (c.vergiNo ?? '').contains(q)).toList();
    }
    _filtered = list;
    notifyListeners();
  }

  // ── Seç & Ekstre ──────────────────────────────────────────────────────────

  Future<void> cariSec(CariModel cari) async {
    _secilenCari   = cari;
    _ekstreLoading = true;
    notifyListeners();
    try {
      _ekstre = await _db.cariEkstre(cari.id);
    } catch (_) {
      _ekstre = [];
    }
    _ekstreLoading = false;
    notifyListeners();
  }

  void ekstreSifirla() {
    _secilenCari = null;
    _ekstre      = [];
    notifyListeners();
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<void> cariEkle({
    required String  ad,
    required CariTip tip,
    String?          telefon,
    String?          eposta,
    String?          adres,
    String?          vergiDairesi,
    String?          vergiNo,
  }) async {
    final cari = CariModel(
      id:               _uuid.v4(),
      ad:               ad,
      tip:              tip,
      telefon:          telefon,
      eposta:           eposta,
      adres:            adres,
      vergiDairesi:     vergiDairesi,
      vergiNo:          vergiNo,
      olusturmaTarihi:  DateTime.now(),
    );
    await _db.cariEkle(cari);
    await yukleCari();
  }

  Future<void> cariGuncelle(CariModel cari) async {
    await _db.cariGuncelle(cari);
    await yukleCari();
    if (_secilenCari?.id == cari.id) _secilenCari = cari;
    notifyListeners();
  }

  Future<void> cariSil(String cariId) async {
    // Soft-delete: aktif = false
    final rows = _cariler.where((c) => c.id == cariId).toList();
    if (rows.isEmpty) return;
    await _db.cariGuncelle(rows.first.copyWith(aktif: false));
    await yukleCari();
  }

  // ── Tahsilat / Ödeme ──────────────────────────────────────────────────────

  /// Müşteriden tahsilat (müşteri borcunu öder → kasa girer)
  Future<void> tahsilatKaydet({
    required String cariId,
    required double tutar,
    required String kasaId,
    String?         aciklama,
  }) async {
    await _db.tahsilatKaydet(
      cariId:   cariId,
      tutar:    tutar,
      kasaId:   kasaId,
      aciklama: aciklama,
    );
    await yukleCari();
    if (_secilenCari?.id == cariId) {
      await cariSec(_secilenCari!);
    }
  }

  /// Tedarikçiye ödeme (bizim borcumuzu öderiz → kasa çıkar)
  Future<void> tedarikciOdemesiKaydet({
    required String cariId,
    required double tutar,
    required String kasaId,
    String?         aciklama,
  }) async {
    // Tedarikçi ödemesi = tahsilat mantığının tersi;
    // DatabaseService'e özel bir method ekleyene kadar
    // mevcut tahsilatKaydet'i ters yönde kullanıyoruz.
    await _db.tahsilatKaydet(
      cariId:   cariId,
      tutar:    tutar,
      kasaId:   kasaId,
      aciklama: aciklama ?? 'Tedarikçi ödemesi',
    );
    await yukleCari();
    if (_secilenCari?.id == cariId) {
      await cariSec(_secilenCari!);
    }
  }
}

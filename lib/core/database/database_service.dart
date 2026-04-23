import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../features/terminal/data/models/cari_hareket_model.dart';
import '../../features/terminal/data/models/cari_model.dart';
import '../../features/terminal/data/models/gider_model.dart';
import '../../features/terminal/data/models/kasa_model.dart';
import '../../features/terminal/data/models/product_model.dart';
import '../../features/terminal/data/models/sale_model.dart';
import '../../features/terminal/data/models/stok_hareket_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  Database? _db;
  final _uuid = const Uuid();

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  // ── Başlatma & Şema ────────────────────────────────────────────────────────

  Future<Database> _initDb() async {
    final dbPath = join(await getDatabasesPath(), 'liqra_terminal.db');
    return openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE kasalar (
        id     TEXT PRIMARY KEY,
        ad     TEXT NOT NULL,
        tip    INTEGER NOT NULL,
        bakiye REAL NOT NULL DEFAULT 0,
        aktif  INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE cariler (
        id                TEXT PRIMARY KEY,
        ad                TEXT NOT NULL,
        tip               INTEGER NOT NULL,
        telefon           TEXT,
        eposta            TEXT,
        adres             TEXT,
        vergi_dairesi     TEXT,
        vergi_no          TEXT,
        bakiye            REAL NOT NULL DEFAULT 0,
        aktif             INTEGER NOT NULL DEFAULT 1,
        olusturma_tarihi  TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE urunler (
        id              TEXT PRIMARY KEY,
        ad              TEXT NOT NULL,
        barkod          TEXT NOT NULL,
        kategori        TEXT NOT NULL,
        satis_fiyati    REAL NOT NULL,
        alis_fiyati     REAL NOT NULL DEFAULT 0,
        stok            INTEGER NOT NULL DEFAULT 0,
        kritik_stok     INTEGER NOT NULL DEFAULT 5,
        birim           TEXT,
        tedarikci_id    TEXT,
        toplam_satilan  INTEGER NOT NULL DEFAULT 0,
        aktif           INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (tedarikci_id) REFERENCES cariler(id)
      )
    ''');
    await db.execute('CREATE INDEX idx_urun_barkod ON urunler(barkod)');

    await db.execute('''
      CREATE TABLE satislar (
        id          TEXT PRIMARY KEY,
        kalemler    TEXT NOT NULL,
        toplam      REAL NOT NULL,
        kar_toplami REAL NOT NULL DEFAULT 0,
        odeme_tip   INTEGER NOT NULL,
        cari_id     TEXT,
        cari_adi    TEXT,
        kasa_id     TEXT,
        tarih       TEXT NOT NULL,
        tarih_key   TEXT NOT NULL,
        FOREIGN KEY (cari_id)  REFERENCES cariler(id),
        FOREIGN KEY (kasa_id)  REFERENCES kasalar(id)
      )
    ''');
    await db.execute('CREATE INDEX idx_satis_tarih ON satislar(tarih_key)');

    await db.execute('''
      CREATE TABLE cari_hareketler (
        id        TEXT PRIMARY KEY,
        cari_id   TEXT NOT NULL,
        tip       INTEGER NOT NULL,
        tutar     REAL NOT NULL,
        bakiye    REAL NOT NULL,
        belge_no  TEXT,
        aciklama  TEXT,
        tarih     TEXT NOT NULL,
        FOREIGN KEY (cari_id) REFERENCES cariler(id)
      )
    ''');
    await db.execute('CREATE INDEX idx_cari_har ON cari_hareketler(cari_id, tarih)');

    await db.execute('''
      CREATE TABLE kasa_hareketler (
        id        TEXT PRIMARY KEY,
        kasa_id   TEXT NOT NULL,
        tip       INTEGER NOT NULL,
        tutar     REAL NOT NULL,
        bakiye    REAL NOT NULL,
        belge_no  TEXT,
        aciklama  TEXT,
        tarih     TEXT NOT NULL,
        FOREIGN KEY (kasa_id) REFERENCES kasalar(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE giderler (
        id        TEXT PRIMARY KEY,
        kategori  INTEGER NOT NULL,
        tutar     REAL NOT NULL,
        kasa_id   TEXT NOT NULL,
        aciklama  TEXT,
        tarih     TEXT NOT NULL,
        FOREIGN KEY (kasa_id) REFERENCES kasalar(id)
      )
    ''');
    await db.execute('CREATE INDEX idx_gider_tarih ON giderler(tarih)');

    await db.execute('''
      CREATE TABLE stok_hareketler (
        id           TEXT PRIMARY KEY,
        urun_id      TEXT NOT NULL,
        tip          INTEGER NOT NULL,
        miktar       INTEGER NOT NULL,
        stok_sonrasi INTEGER NOT NULL,
        birim_fiyat  REAL NOT NULL DEFAULT 0,
        belge_no     TEXT,
        aciklama     TEXT,
        tarih        TEXT NOT NULL,
        FOREIGN KEY (urun_id) REFERENCES urunler(id)
      )
    ''');

    // Varsayılan kasaları ekle
    await _seedKasalar(db);
  }

  Future<void> _seedKasalar(Database db) async {
    final kasalar = [
      KasaModel(id: 'nakit', ad: 'Nakit Kasa',    tip: KasaTip.nakit),
      KasaModel(id: 'banka', ad: 'Banka Hesabı',  tip: KasaTip.banka),
      KasaModel(id: 'pos',   ad: 'POS Cihazı',    tip: KasaTip.pos),
    ];
    for (final k in kasalar) {
      await db.insert('kasalar', k.toMap());
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SATIŞ — Atomik Transaction
  // Tek bir DB transaction içinde:
  //  1) Satış kaydı yaz
  //  2) Her ürünün stokunu düş + StokHareket yaz
  //  3) Cari hareketi yaz + cari bakiyesini güncelle (veresiye ise)
  //  4) Kasa hareketi yaz + kasa bakiyesini güncelle (nakit/kart ise)
  // ══════════════════════════════════════════════════════════════════════════

  Future<String?> satisKaydet({
    required List<SatisKalemi> kalemler,
    required OdemeTip          odemeTip,
    CariModel?                 cari,     // veresiye ise zorunlu
    String                     kasaId = 'nakit',
  }) async {
    final database = await db;
    final saleId   = _uuid.v4();
    final now      = DateTime.now();
    final toplam   = kalemler.fold(0.0, (s, k) => s + k.toplamFiyat);
    final karTop   = kalemler.fold(0.0, (s, k) => s + k.karTutari);

    await database.transaction((txn) async {
      // 1) Satış kaydı
      final sale = SaleModel(
        id:         saleId,
        kalemler:   kalemler,
        toplam:     toplam,
        karToplami: karTop,
        odemeTip:   odemeTip,
        cariId:     cari?.id,
        cariAdi:    cari?.ad,
        kasaId:     odemeTip != OdemeTip.veresiye ? kasaId : null,
        tarih:      now,
      );
      await txn.insert('satislar', sale.toMap());

      // 2) Stok & StokHareket
      for (final kalem in kalemler) {
        final urunRows = await txn.query(
          'urunler', where: 'id = ?', whereArgs: [kalem.urunId]);
        if (urunRows.isEmpty) continue;

        final mevcutStok   = urunRows.first['stok']           as int;
        final mevcutSatilan = urunRows.first['toplam_satilan'] as int;
        final yeniStok     = mevcutStok    - kalem.miktar;
        final yeniSatilan  = mevcutSatilan + kalem.miktar;

        await txn.update('urunler',
          {'stok': yeniStok, 'toplam_satilan': yeniSatilan},
          where: 'id = ?', whereArgs: [kalem.urunId]);

        await txn.insert('stok_hareketler', StokHareket(
          id:          _uuid.v4(),
          urunId:      kalem.urunId,
          tip:         StokHareketTip.satis,
          miktar:      -kalem.miktar,
          stokSonrasi: yeniStok,
          birimFiyat:  kalem.satisFiyati,
          belgeNo:     saleId,
          tarih:       now,
        ).toMap());
      }

      // 3) Cari hareketi (veresiye)
      if (odemeTip == OdemeTip.veresiye && cari != null) {
        final yeniBakiye = cari.bakiye + toplam;

        await txn.update('cariler',
          {'bakiye': yeniBakiye},
          where: 'id = ?', whereArgs: [cari.id]);

        await txn.insert('cari_hareketler', CariHareket(
          id:       _uuid.v4(),
          cariId:   cari.id,
          tip:      CariHareketTip.satis,
          tutar:    toplam,
          bakiye:   yeniBakiye,
          belgeNo:  saleId,
          aciklama: '${kalemler.length} kalem satış',
          tarih:    now,
        ).toMap());
      }

      // 4) Kasa hareketi (nakit / kart)
      if (odemeTip != OdemeTip.veresiye) {
        final aktifKasa = kasaId == 'pos' && odemeTip == OdemeTip.krediKarti
            ? 'pos' : kasaId;

        final kasaRows = await txn.query(
          'kasalar', where: 'id = ?', whereArgs: [aktifKasa]);
        if (kasaRows.isNotEmpty) {
          final mevcutBakiye = (kasaRows.first['bakiye'] as num).toDouble();
          final yeniBakiye   = mevcutBakiye + toplam;

          await txn.update('kasalar',
            {'bakiye': yeniBakiye},
            where: 'id = ?', whereArgs: [aktifKasa]);

          await txn.insert('kasa_hareketler', KasaHareket(
            id:       _uuid.v4(),
            kasaId:   aktifKasa,
            tip:      KasaHareketTip.satisGeliri,
            tutar:    toplam,
            bakiye:   yeniBakiye,
            belgeNo:  saleId,
            tarih:    now,
          ).toMap());
        }
      }
    });

    return saleId;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAHSİLAT — Müşteri cari borcunu nakit/kart ile ödedi
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> tahsilatKaydet({
    required String cariId,
    required double tutar,
    required String kasaId,
    String? aciklama,
  }) async {
    final database = await db;
    final now = DateTime.now();

    await database.transaction((txn) async {
      final cariRows = await txn.query('cariler', where: 'id = ?', whereArgs: [cariId]);
      if (cariRows.isEmpty) return;

      final yeniBakiye = (cariRows.first['bakiye'] as num).toDouble() - tutar;

      await txn.update('cariler', {'bakiye': yeniBakiye},
          where: 'id = ?', whereArgs: [cariId]);

      await txn.insert('cari_hareketler', CariHareket(
        id:       _uuid.v4(),
        cariId:   cariId,
        tip:      CariHareketTip.tahsilat,
        tutar:    -tutar,    // negatif = alacak
        bakiye:   yeniBakiye,
        aciklama: aciklama ?? 'Tahsilat',
        tarih:    now,
      ).toMap());

      // Kasaya ekle
      final kasaRows = await txn.query('kasalar', where: 'id = ?', whereArgs: [kasaId]);
      if (kasaRows.isNotEmpty) {
        final yeniKasaBakiye = (kasaRows.first['bakiye'] as num).toDouble() + tutar;
        await txn.update('kasalar', {'bakiye': yeniKasaBakiye},
            where: 'id = ?', whereArgs: [kasaId]);
        await txn.insert('kasa_hareketler', KasaHareket(
          id:       _uuid.v4(),
          kasaId:   kasaId,
          tip:      KasaHareketTip.tahsilat,
          tutar:    tutar,
          bakiye:   yeniKasaBakiye,
          aciklama: '${cariRows.first['ad']} tahsilatı',
          tarih:    now,
        ).toMap());
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GİDER KAYDI
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> giderKaydet({
    required GiderKategori kategori,
    required double        tutar,
    required String        kasaId,
    String?                aciklama,
    DateTime?              tarih,
  }) async {
    final database = await db;
    final now = tarih ?? DateTime.now();

    await database.transaction((txn) async {
      await txn.insert('giderler', GiderModel(
        id:       _uuid.v4(),
        kategori: kategori,
        tutar:    tutar,
        kasaId:   kasaId,
        aciklama: aciklama,
        tarih:    now,
      ).toMap());

      final kasaRows = await txn.query('kasalar', where: 'id = ?', whereArgs: [kasaId]);
      if (kasaRows.isNotEmpty) {
        final yeniBakiye = (kasaRows.first['bakiye'] as num).toDouble() - tutar;
        await txn.update('kasalar', {'bakiye': yeniBakiye},
            where: 'id = ?', whereArgs: [kasaId]);
        await txn.insert('kasa_hareketler', KasaHareket(
          id:       _uuid.v4(),
          kasaId:   kasaId,
          tip:      KasaHareketTip.gider,
          tutar:    -tutar,
          bakiye:   yeniBakiye,
          aciklama: aciklama ?? GiderModel(id:'',kategori:kategori,tutar:0,kasaId:'',tarih:now).kategoriLabel,
          tarih:    now,
        ).toMap());
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STOK GİRİŞİ (Alım Fişi)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> stokGirisKaydet({
    required String     urunId,
    required int        miktar,
    required double     alisFiyati,
    String?             tedarikciId,
    String?             fisNo,
    String?             aciklama,
  }) async {
    final database = await db;
    final now = DateTime.now();

    await database.transaction((txn) async {
      final rows = await txn.query('urunler', where: 'id = ?', whereArgs: [urunId]);
      if (rows.isEmpty) return;

      final yeniStok = (rows.first['stok'] as int) + miktar;
      await txn.update('urunler',
        {'stok': yeniStok, 'alis_fiyati': alisFiyati},
        where: 'id = ?', whereArgs: [urunId]);

      await txn.insert('stok_hareketler', StokHareket(
        id:          _uuid.v4(),
        urunId:      urunId,
        tip:         StokHareketTip.alis,
        miktar:      miktar,
        stokSonrasi: yeniStok,
        birimFiyat:  alisFiyati,
        belgeNo:     fisNo,
        aciklama:    aciklama,
        tarih:       now,
      ).toMap());

      // Tedarikçiye borç ekle
      if (tedarikciId != null) {
        final tutar = miktar * alisFiyati;
        final cariRows = await txn.query('cariler', where: 'id = ?', whereArgs: [tedarikciId]);
        if (cariRows.isNotEmpty) {
          final yeniBakiye = (cariRows.first['bakiye'] as num).toDouble() - tutar;
          await txn.update('cariler', {'bakiye': yeniBakiye},
              where: 'id = ?', whereArgs: [tedarikciId]);
          await txn.insert('cari_hareketler', CariHareket(
            id:       _uuid.v4(),
            cariId:   tedarikciId,
            tip:      CariHareketTip.alis,
            tutar:    -tutar,   // biz borçlandık → negatif
            bakiye:   yeniBakiye,
            belgeNo:  fisNo,
            aciklama: aciklama ?? 'Stok alımı',
            tarih:    now,
          ).toMap());
        }
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SORGULAR
  // ══════════════════════════════════════════════════════════════════════════

  // Ürünler
  Future<List<ProductModel>> tumUrunler({bool sadecAktif = true}) async {
    final database = await db;
    final rows = await database.query('urunler',
      where: sadecAktif ? 'aktif = 1' : null,
      orderBy: 'ad ASC');
    return rows.map(ProductModel.fromMap).toList();
  }

  Future<ProductModel?> barkodAra(String barkod) async {
    final database = await db;
    final rows = await database.query('urunler',
        where: 'barkod = ? AND aktif = 1', whereArgs: [barkod], limit: 1);
    return rows.isNotEmpty ? ProductModel.fromMap(rows.first) : null;
  }

  Future<List<ProductModel>> kritikStokUrunler() async {
    final database = await db;
    final rows = await database.rawQuery(
      'SELECT * FROM urunler WHERE stok <= kritik_stok AND aktif = 1 ORDER BY stok ASC');
    return rows.map(ProductModel.fromMap).toList();
  }

  // Cariler
  Future<List<CariModel>> tumCariler({CariTip? tip}) async {
    final database = await db;
    final rows = await database.query('cariler',
      where: tip != null ? 'tip = ? AND aktif = 1' : 'aktif = 1',
      whereArgs: tip != null ? [tip.index] : null,
      orderBy: 'ad ASC');
    return rows.map(CariModel.fromMap).toList();
  }

  // Cari ekstre
  Future<List<CariHareket>> cariEkstre(String cariId, {
    DateTime? baslangic, DateTime? bitis}) async {
    final database = await db;
    String where = 'cari_id = ?';
    final args = <dynamic>[cariId];
    if (baslangic != null) { where += ' AND tarih >= ?'; args.add(baslangic.toIso8601String()); }
    if (bitis    != null) { where += ' AND tarih <= ?'; args.add(bitis.toIso8601String()); }
    final rows = await database.query('cari_hareketler',
        where: where, whereArgs: args, orderBy: 'tarih DESC');
    return rows.map(CariHareket.fromMap).toList();
  }

  // Günlük satışlar (Z raporu için)
  Future<List<SaleModel>> gunlukSatislar(String tarihKey) async {
    final database = await db;
    final rows = await database.query('satislar',
        where: 'tarih_key = ?', whereArgs: [tarihKey], orderBy: 'tarih DESC');
    return rows.map(SaleModel.fromMap).toList();
  }

  // Dönem özeti (Dashboard için)
  Future<Map<String, double>> donemOzeti({
    required String baslangicKey,
    required String bitisKey,
  }) async {
    final database = await db;
    final row = await database.rawQuery('''
      SELECT
        COALESCE(SUM(toplam),     0) AS ciro,
        COALESCE(SUM(kar_toplami),0) AS kar
      FROM satislar
      WHERE tarih_key BETWEEN ? AND ?
    ''', [baslangicKey, bitisKey]);

    final gRow = await database.rawQuery('''
      SELECT COALESCE(SUM(tutar), 0) AS toplam_gider
      FROM giderler
      WHERE tarih BETWEEN ? AND ?
    ''', ['$baslangicKey 00:00:00', '$bitisKey 23:59:59']);

    final topAl = await database.rawQuery('''
      SELECT COALESCE(SUM(bakiye), 0) AS toplam_alacak
      FROM cariler WHERE tip = 0 AND bakiye > 0
    ''');
    final topBor = await database.rawQuery('''
      SELECT COALESCE(SUM(ABS(bakiye)), 0) AS toplam_borc
      FROM cariler WHERE tip = 1 AND bakiye < 0
    ''');

    return {
      'ciro':          (row.first['ciro']           as num).toDouble(),
      'kar':           (row.first['kar']             as num).toDouble(),
      'gider':         (gRow.first['toplam_gider']  as num).toDouble(),
      'toplam_alacak': (topAl.first['toplam_alacak'] as num).toDouble(),
      'toplam_borc':   (topBor.first['toplam_borc'] as num).toDouble(),
    };
  }

  // Kasalar
  Future<List<KasaModel>> tumKasalar() async {
    final database = await db;
    final rows = await database.query('kasalar', where: 'aktif = 1');
    return rows.map(KasaModel.fromMap).toList();
  }

  // Giderler (dönem)
  Future<List<GiderModel>> donemGiderleri(String baslangic, String bitis) async {
    final database = await db;
    final rows = await database.query('giderler',
      where: 'tarih BETWEEN ? AND ?',
      whereArgs: ['$baslangic 00:00:00', '$bitis 23:59:59'],
      orderBy: 'tarih DESC');
    return rows.map(GiderModel.fromMap).toList();
  }

  // CRUD — Ürün
  Future<void> urunEkle(ProductModel p) async =>
      (await db).insert('urunler', p.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> urunGuncelle(ProductModel p) async =>
      (await db).update('urunler', p.toMap(), where: 'id = ?', whereArgs: [p.id]);

  // CRUD — Cari
  Future<void> cariEkle(CariModel c) async =>
      (await db).insert('cariler', c.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> cariGuncelle(CariModel c) async =>
      (await db).update('cariler', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
}

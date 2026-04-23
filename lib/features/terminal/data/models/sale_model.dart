import 'dart:convert';

enum OdemeTip { nakit, krediKarti, veresiye }

class SatisKalemi {
  final String urunId;
  final String urunAdi;
  final String barkod;
  final double satisFiyati;
  final double alisFiyati;
  final double indirim; // 0.0–1.0
  final int    miktar;

  const SatisKalemi({
    required this.urunId,
    required this.urunAdi,
    required this.barkod,
    required this.satisFiyati,
    this.alisFiyati = 0,
    this.indirim    = 0,
    required this.miktar,
  });

  double get birimFiyat  => satisFiyati * (1 - indirim);
  double get toplamFiyat => birimFiyat * miktar;
  double get karTutari   => (birimFiyat - alisFiyati) * miktar;

  factory SatisKalemi.fromMap(Map<String, dynamic> m) => SatisKalemi(
    urunId:      m['urun_id']       as String,
    urunAdi:     m['urun_adi']      as String,
    barkod:      m['barkod']        as String,
    satisFiyati: (m['satis_fiyati'] as num).toDouble(),
    alisFiyati:  (m['alis_fiyati']  as num? ?? 0).toDouble(),
    indirim:     (m['indirim']      as num).toDouble(),
    miktar:      m['miktar']        as int,
  );

  Map<String, dynamic> toMap() => {
    'urun_id':      urunId,
    'urun_adi':     urunAdi,
    'barkod':       barkod,
    'satis_fiyati': satisFiyati,
    'alis_fiyati':  alisFiyati,
    'indirim':      indirim,
    'miktar':       miktar,
  };
}

class SaleModel {
  final String          id;
  final List<SatisKalemi> kalemler;
  final double          toplam;
  final double          karToplami;
  final OdemeTip        odemeTip;
  final String?         cariId;
  final String?         cariAdi;
  final String?         kasaId;
  final DateTime        tarih;
  final String          tarihKey; // YYYY-MM-DD

  SaleModel({
    required this.id,
    required this.kalemler,
    required this.toplam,
    required this.karToplami,
    required this.odemeTip,
    this.cariId,
    this.cariAdi,
    this.kasaId,
    DateTime? tarih,
    String?   tarihKey,
  })  : tarih    = tarih    ?? DateTime.now(),
        tarihKey = tarihKey ?? _fmt(tarih ?? DateTime.now());

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  bool get veresiyeMi  => odemeTip == OdemeTip.veresiye;
  int  get kalemSayisi => kalemler.fold(0, (s, k) => s + k.miktar);

  factory SaleModel.fromMap(Map<String, dynamic> m) {
    final raw = jsonDecode(m['kalemler'] as String) as List;
    return SaleModel(
      id:         m['id']           as String,
      kalemler:   raw.map((k) => SatisKalemi.fromMap(k as Map<String,dynamic>)).toList(),
      toplam:     (m['toplam']      as num).toDouble(),
      karToplami: (m['kar_toplami'] as num).toDouble(),
      odemeTip:   OdemeTip.values[m['odeme_tip'] as int],
      cariId:     m['cari_id']      as String?,
      cariAdi:    m['cari_adi']     as String?,
      kasaId:     m['kasa_id']      as String?,
      tarih:      DateTime.parse(m['tarih']     as String),
      tarihKey:   m['tarih_key']    as String,
    );
  }

  Map<String, dynamic> toMap() => {
    'id':          id,
    'kalemler':    jsonEncode(kalemler.map((k) => k.toMap()).toList()),
    'toplam':      toplam,
    'kar_toplami': karToplami,
    'odeme_tip':   odemeTip.index,
    'cari_id':     cariId,
    'cari_adi':    cariAdi,
    'kasa_id':     kasaId,
    'tarih':       tarih.toIso8601String(),
    'tarih_key':   tarihKey,
  };
}

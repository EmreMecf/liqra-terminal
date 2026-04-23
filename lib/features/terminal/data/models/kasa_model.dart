/// Kasa/Banka hesapları
enum KasaTip { nakit, banka, pos }

class KasaModel {
  final String  id;
  final String  ad;      // 'Nakit Kasa', 'Ziraat Bankası', 'POS Cihazı'
  final KasaTip tip;
  final double  bakiye;
  final bool    aktif;

  const KasaModel({
    required this.id,
    required this.ad,
    required this.tip,
    this.bakiye = 0,
    this.aktif  = true,
  });

  factory KasaModel.fromMap(Map<String, dynamic> m) => KasaModel(
    id:     m['id']     as String,
    ad:     m['ad']     as String,
    tip:    KasaTip.values[m['tip'] as int],
    bakiye: (m['bakiye'] as num).toDouble(),
    aktif:  (m['aktif']  as int) == 1,
  );

  Map<String, dynamic> toMap() => {
    'id':     id,
    'ad':     ad,
    'tip':    tip.index,
    'bakiye': bakiye,
    'aktif':  aktif ? 1 : 0,
  };

  KasaModel copyWith({double? bakiye}) =>
      KasaModel(id: id, ad: ad, tip: tip, bakiye: bakiye ?? this.bakiye, aktif: aktif);
}

/// Kasa hareketi
enum KasaHareketTip { satisGeliri, tahsilat, gider, tedarikciOdeme, virman, acilis }

class KasaHareket {
  final String          id;
  final String          kasaId;
  final KasaHareketTip  tip;
  final double          tutar;    // + giriş / - çıkış
  final double          bakiye;   // hareket sonrası kasa bakiyesi
  final String?         belgeNo;
  final String?         aciklama;
  final DateTime        tarih;

  const KasaHareket({
    required this.id,
    required this.kasaId,
    required this.tip,
    required this.tutar,
    required this.bakiye,
    this.belgeNo,
    this.aciklama,
    required this.tarih,
  });

  factory KasaHareket.fromMap(Map<String, dynamic> m) => KasaHareket(
    id:        m['id']       as String,
    kasaId:    m['kasa_id']  as String,
    tip:       KasaHareketTip.values[m['tip'] as int],
    tutar:     (m['tutar']   as num).toDouble(),
    bakiye:    (m['bakiye']  as num).toDouble(),
    belgeNo:   m['belge_no'] as String?,
    aciklama:  m['aciklama'] as String?,
    tarih:     DateTime.parse(m['tarih'] as String),
  );

  Map<String, dynamic> toMap() => {
    'id':       id,
    'kasa_id':  kasaId,
    'tip':      tip.index,
    'tutar':    tutar,
    'bakiye':   bakiye,
    'belge_no': belgeNo,
    'aciklama': aciklama,
    'tarih':    tarih.toIso8601String(),
  };
}

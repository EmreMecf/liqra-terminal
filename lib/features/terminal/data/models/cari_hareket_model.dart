/// Cari (müşteri/tedarikçi) hesap hareketleri — çift taraflı defter.
/// tutar > 0 → borç işlendi (cari bize borçlandı veya biz tedarikçiye borçlandık)
/// tutar < 0 → alacak işlendi (tahsilat veya ödeme)
enum CariHareketTip {
  satis,        // Satış — müşteri borçlandı
  tahsilat,     // Nakit/kart tahsilat — müşteri borcu azaldı
  alis,         // Alış — tedarikçiye borçlandık
  tedarikciOdeme, // Tedarikçiye ödeme — borcumuz azaldı
  iade,         // İade
  duzeltme,     // Manuel düzeltme
}

class CariHareket {
  final String           id;
  final String           cariId;
  final CariHareketTip   tip;
  final double           tutar;    // +borç / -alacak
  final double           bakiye;   // hareket sonrası cari bakiyesi
  final String?          belgeNo;  // satış ID, fatura no vs.
  final String?          aciklama;
  final DateTime         tarih;

  const CariHareket({
    required this.id,
    required this.cariId,
    required this.tip,
    required this.tutar,
    required this.bakiye,
    this.belgeNo,
    this.aciklama,
    required this.tarih,
  });

  factory CariHareket.fromMap(Map<String, dynamic> m) => CariHareket(
    id:         m['id']         as String,
    cariId:     m['cari_id']    as String,
    tip:        CariHareketTip.values[m['tip'] as int],
    tutar:      (m['tutar']     as num).toDouble(),
    bakiye:     (m['bakiye']    as num).toDouble(),
    belgeNo:    m['belge_no']   as String?,
    aciklama:   m['aciklama']   as String?,
    tarih:      DateTime.parse(m['tarih'] as String),
  );

  Map<String, dynamic> toMap() => {
    'id':       id,
    'cari_id':  cariId,
    'tip':      tip.index,
    'tutar':    tutar,
    'bakiye':   bakiye,
    'belge_no': belgeNo,
    'aciklama': aciklama,
    'tarih':    tarih.toIso8601String(),
  };

  String get tipLabel {
    switch (tip) {
      case CariHareketTip.satis:           return 'Satış';
      case CariHareketTip.tahsilat:        return 'Tahsilat';
      case CariHareketTip.alis:            return 'Alış';
      case CariHareketTip.tedarikciOdeme: return 'Tedarikçi Ödemesi';
      case CariHareketTip.iade:            return 'İade';
      case CariHareketTip.duzeltme:        return 'Düzeltme';
    }
  }
}

enum StokHareketTip { satis, alis, iade, sayimFazlasi, sayimEksigi, fire }

class StokHareket {
  final String          id;
  final String          urunId;
  final StokHareketTip  tip;
  final int             miktar;      // + giriş / - çıkış
  final int             stokSonrasi; // hareket sonrası stok
  final double          birimFiyat;  // alış veya satış fiyatı
  final String?         belgeNo;     // satış ID veya alım fişi no
  final String?         aciklama;
  final DateTime        tarih;

  const StokHareket({
    required this.id,
    required this.urunId,
    required this.tip,
    required this.miktar,
    required this.stokSonrasi,
    required this.birimFiyat,
    this.belgeNo,
    this.aciklama,
    required this.tarih,
  });

  factory StokHareket.fromMap(Map<String, dynamic> m) => StokHareket(
    id:           m['id']            as String,
    urunId:       m['urun_id']       as String,
    tip:          StokHareketTip.values[m['tip'] as int],
    miktar:       m['miktar']        as int,
    stokSonrasi:  m['stok_sonrasi']  as int,
    birimFiyat:   (m['birim_fiyat']  as num).toDouble(),
    belgeNo:      m['belge_no']      as String?,
    aciklama:     m['aciklama']      as String?,
    tarih:        DateTime.parse(m['tarih'] as String),
  );

  Map<String, dynamic> toMap() => {
    'id':           id,
    'urun_id':      urunId,
    'tip':          tip.index,
    'miktar':       miktar,
    'stok_sonrasi': stokSonrasi,
    'birim_fiyat':  birimFiyat,
    'belge_no':     belgeNo,
    'aciklama':     aciklama,
    'tarih':        tarih.toIso8601String(),
  };
}

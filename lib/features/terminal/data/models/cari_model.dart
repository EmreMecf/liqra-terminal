/// Hem müşteri hem tedarikçi tek "Cari" modeli.
/// balance > 0 → bize borçlu (alacaklıyız)
/// balance < 0 → biz borçluyuz (ödemeliyiz)
enum CariTip { musteri, tedarikci, ikisi }

class CariModel {
  final String  id;
  final String  ad;
  final CariTip tip;
  final String? telefon;
  final String? eposta;
  final String? adres;
  final String? vergiDairesi;
  final String? vergiNo;
  final double  bakiye;   // (+) alacak / (-) borç
  final bool    aktif;
  final DateTime olusturmaTarihi;

  const CariModel({
    required this.id,
    required this.ad,
    required this.tip,
    this.telefon,
    this.eposta,
    this.adres,
    this.vergiDairesi,
    this.vergiNo,
    this.bakiye = 0,
    this.aktif  = true,
    required this.olusturmaTarihi,
  });

  // ── DB serileştirme ────────────────────────────────────────────────────────

  factory CariModel.fromMap(Map<String, dynamic> m) => CariModel(
    id:               m['id']             as String,
    ad:               m['ad']             as String,
    tip:              CariTip.values[(m['tip'] as int)],
    telefon:          m['telefon']        as String?,
    eposta:           m['eposta']         as String?,
    adres:            m['adres']          as String?,
    vergiDairesi:     m['vergi_dairesi']  as String?,
    vergiNo:          m['vergi_no']       as String?,
    bakiye:           (m['bakiye']        as num).toDouble(),
    aktif:            (m['aktif']         as int) == 1,
    olusturmaTarihi:  DateTime.parse(m['olusturma_tarihi'] as String),
  );

  Map<String, dynamic> toMap() => {
    'id':               id,
    'ad':               ad,
    'tip':              tip.index,
    'telefon':          telefon,
    'eposta':           eposta,
    'adres':            adres,
    'vergi_dairesi':    vergiDairesi,
    'vergi_no':         vergiNo,
    'bakiye':           bakiye,
    'aktif':            aktif ? 1 : 0,
    'olusturma_tarihi': olusturmaTarihi.toIso8601String(),
  };

  CariModel copyWith({double? bakiye, bool? aktif}) => CariModel(
    id: id, ad: ad, tip: tip,
    telefon: telefon, eposta: eposta, adres: adres,
    vergiDairesi: vergiDairesi, vergiNo: vergiNo,
    bakiye: bakiye ?? this.bakiye,
    aktif:  aktif  ?? this.aktif,
    olusturmaTarihi: olusturmaTarihi,
  );

  bool get alacaklimi => bakiye > 0; // bize borçlu
  bool get borcluMu   => bakiye < 0; // biz borçluyuz
}

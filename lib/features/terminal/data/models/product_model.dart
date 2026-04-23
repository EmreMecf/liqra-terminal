class ProductModel {
  final String  id;
  final String  ad;
  final String  barkod;
  final String  kategori;
  final double  satisFiyati;
  final double  alisFiyati;    // kar-zarar hesabı için
  final int     stok;
  final int     kritikStok;   // bu seviyenin altı uyarı verir
  final String? birim;        // adet, kg, lt, paket...
  final String? tedarikciId;  // CariModel.id (tip: tedarikci)
  final int     toplamSatilan;
  final bool    aktif;

  const ProductModel({
    required this.id,
    required this.ad,
    required this.barkod,
    required this.kategori,
    required this.satisFiyati,
    this.alisFiyati   = 0,
    required this.stok,
    this.kritikStok   = 5,
    this.birim,
    this.tedarikciId,
    this.toplamSatilan = 0,
    this.aktif         = true,
  });

  // ── DB serileştirme ────────────────────────────────────────────────────────

  factory ProductModel.fromMap(Map<String, dynamic> m) => ProductModel(
    id:            m['id']              as String,
    ad:            m['ad']              as String,
    barkod:        m['barkod']          as String,
    kategori:      m['kategori']        as String,
    satisFiyati:   (m['satis_fiyati']   as num).toDouble(),
    alisFiyati:    (m['alis_fiyati']    as num).toDouble(),
    stok:          m['stok']            as int,
    kritikStok:    m['kritik_stok']     as int,
    birim:         m['birim']           as String?,
    tedarikciId:   m['tedarikci_id']    as String?,
    toplamSatilan: m['toplam_satilan']  as int,
    aktif:         (m['aktif']          as int) == 1,
  );

  Map<String, dynamic> toMap() => {
    'id':             id,
    'ad':             ad,
    'barkod':         barkod,
    'kategori':       kategori,
    'satis_fiyati':   satisFiyati,
    'alis_fiyati':    alisFiyati,
    'stok':           stok,
    'kritik_stok':    kritikStok,
    'birim':          birim,
    'tedarikci_id':   tedarikciId,
    'toplam_satilan': toplamSatilan,
    'aktif':          aktif ? 1 : 0,
  };

  // ── Hesaplamalar ───────────────────────────────────────────────────────────

  double get karMarji => satisFiyati - alisFiyati;
  double get karOrani => alisFiyati > 0
      ? ((satisFiyati - alisFiyati) / alisFiyati) * 100
      : 0;
  bool   get stokKritik    => stok > 0 && stok <= kritikStok;
  bool   get stokTukendi   => stok <= 0;

  ProductModel copyWith({int? stok, int? toplamSatilan, double? satisFiyati, double? alisFiyati}) =>
    ProductModel(
      id: id, ad: ad, barkod: barkod, kategori: kategori,
      satisFiyati:   satisFiyati   ?? this.satisFiyati,
      alisFiyati:    alisFiyati    ?? this.alisFiyati,
      stok:          stok          ?? this.stok,
      kritikStok:    kritikStok,
      birim:         birim,
      tedarikciId:   tedarikciId,
      toplamSatilan: toplamSatilan ?? this.toplamSatilan,
      aktif:         aktif,
    );

  // Eski alan adlarıyla uyumluluk
  double get price      => satisFiyati;
  String get name       => ad;
  String get barcode    => barkod;
  String get category   => kategori;
  bool   get isLowStock  => stokKritik;
  bool   get isOutOfStock=> stokTukendi;
}

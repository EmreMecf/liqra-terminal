enum GiderKategori { kira, fatura, personel, malzeme, bakim, diger }

class GiderModel {
  final String        id;
  final GiderKategori kategori;
  final double        tutar;
  final String        kasaId;  // hangi kasadan çıktı
  final String?       aciklama;
  final DateTime      tarih;

  const GiderModel({
    required this.id,
    required this.kategori,
    required this.tutar,
    required this.kasaId,
    this.aciklama,
    required this.tarih,
  });

  factory GiderModel.fromMap(Map<String, dynamic> m) => GiderModel(
    id:        m['id']        as String,
    kategori:  GiderKategori.values[m['kategori'] as int],
    tutar:     (m['tutar']    as num).toDouble(),
    kasaId:    m['kasa_id']   as String,
    aciklama:  m['aciklama']  as String?,
    tarih:     DateTime.parse(m['tarih'] as String),
  );

  Map<String, dynamic> toMap() => {
    'id':        id,
    'kategori':  kategori.index,
    'tutar':     tutar,
    'kasa_id':   kasaId,
    'aciklama':  aciklama,
    'tarih':     tarih.toIso8601String(),
  };

  String get kategoriLabel {
    switch (kategori) {
      case GiderKategori.kira:      return 'Kira';
      case GiderKategori.fatura:    return 'Fatura';
      case GiderKategori.personel:  return 'Personel';
      case GiderKategori.malzeme:   return 'Malzeme';
      case GiderKategori.bakim:     return 'Bakım/Tamir';
      case GiderKategori.diger:     return 'Diğer';
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Rapor aggregate modelleri — DB sorgularından dönen özet satırları
// ══════════════════════════════════════════════════════════════════════════════

/// Bir günün tek bir saatine ait özet (0–23)
class SaatlikOzet {
  final int    saat;
  final int    satisSayisi;
  final double ciro;

  const SaatlikOzet({
    required this.saat,
    required this.satisSayisi,
    required this.ciro,
  });
}

/// Bir aydaki tek bir güne ait özet ("YYYY-MM-DD")
class GunlukOzet {
  final String gun;        // tarih_key formatı
  final int    satisSayisi;
  final double ciro;
  final double kar;

  const GunlukOzet({
    required this.gun,
    required this.satisSayisi,
    required this.ciro,
    required this.kar,
  });

  DateTime get tarih => DateTime.parse(gun);
  int      get gunNo => tarih.day;
}

/// Bir yıldaki tek bir aya ait özet (1–12)
class AylikOzet {
  final int    ay;
  final int    satisSayisi;
  final double ciro;
  final double kar;

  const AylikOzet({
    required this.ay,
    required this.satisSayisi,
    required this.ciro,
    required this.kar,
  });

  static const ayAdlari = [
    '', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];

  String get ayKisa => ayAdlari[ay];
}

// ── Dönem enum ────────────────────────────────────────────────────────────────

enum RaporDonem {
  bugun('Bugün'),
  dun('Dün'),
  buHafta('Bu Hafta'),
  buAy('Bu Ay'),
  gecenAy('Geçen Ay'),
  ozel('Özel Aralık');

  const RaporDonem(this.label);
  final String label;
}

/// Keyboard shortcut documentation for Terminal Pro
///
/// F1  — Satışı tamamla (Nakit)
/// F2  — Satışı tamamla (Veresiye)
/// F3  — Satışı tamamla (Kart)
/// F4  — Kamera barkod tarayıcısını aç/kapat
/// F5  — Günlük raporu yenile
/// F6  — Sepeti temizle
/// ESC — Seçimi iptal et / kamerayı kapat
/// Del — Seçili sepet ürününü kaldır
/// +   — Seçili sepet ürününün adedini artır
/// -   — Seçili sepet ürününün adedini azalt
/// ↑↓  — Sepette yukarı/aşağı gezin
/// Enter (barkod okuyucu) — Barkod araması tetikle

abstract class AppShortcuts {
  static const Map<String, String> shortcuts = {
    'F1': 'Nakit Satış',
    'F2': 'Veresiye Satış',
    'F3': 'Kart ile Ödeme',
    'F4': 'Kamera Barkod',
    'F5': 'Raporu Yenile',
    'F6': 'Sepeti Temizle',
    'ESC': 'İptal',
    'Del': 'Ürünü Kaldır',
    '+': 'Adet Artır',
    '-': 'Adet Azalt',
    '↑↓': 'Sepette Gezin',
  };
}

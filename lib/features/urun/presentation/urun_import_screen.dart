import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_color_scheme.dart';
import '../../terminal/data/models/product_model.dart';
import '../viewmodel/urun_viewmodel.dart';

// ══════════════════════════════════════════════════════════════════════════════
// CSV IMPORT SİHİRBAZI — 3 Adım
//   1) Dosya yükle & önizle
//   2) Sütunları eşleştir
//   3) Önizle & kaydet
// ══════════════════════════════════════════════════════════════════════════════

final _fmtMoney = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);

class UrunImportScreen extends StatefulWidget {
  const UrunImportScreen({super.key});

  @override
  State<UrunImportScreen> createState() => _UrunImportScreenState();
}

class _UrunImportScreenState extends State<UrunImportScreen> {
  // ── Adım ──────────────────────────────────────────────────────────────────
  int _adim = 0;

  // ── Adım 1 — dosya ────────────────────────────────────────────────────────
  String?               _dosyaYolu;
  List<List<dynamic>>   _satirlar    = [];   // ham CSV satırları
  List<String>          _basliklar   = [];   // ilk satır (header)
  bool                  _baslikVarMi = true; // ilk satır başlık mı?
  String                _ayirici     = ',';  // virgül / noktalı virgül / tab

  // ── Adım 2 — eşleştirme ───────────────────────────────────────────────────
  // Değer: sütun index (string) veya 'AUTO' / 'SKIP'
  String _colAd          = 'AUTO';
  String _colBarkod      = 'AUTO';
  String _colSatisFiyati = 'AUTO';
  String _colAlisFiyati  = 'SKIP';
  String _colStok        = 'SKIP';
  String _colKategori    = 'SKIP';
  String _colKritikStok  = 'SKIP';
  String _varsayilanKat  = 'Genel';
  bool   _guncelleVarolan = true;

  // ── Adım 3 — önizleme ─────────────────────────────────────────────────────
  List<ProductModel> _onizleme = [];
  List<String>       _hatalar  = [];

  // ── İşlem ─────────────────────────────────────────────────────────────────
  bool       _islem  = false;
  ImportSonuc? _sonuc;

  // ══════════════════════════════════════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.bgPrimary,
      body: Column(
        children: [
          _buildBaslik(c),
          _buildStepper(c),
          Divider(height: 1, color: c.border),
          Expanded(child: _buildAdim(c)),
          _buildAlttaki(c),
        ],
      ),
    );
  }

  // ── Başlık ─────────────────────────────────────────────────────────────────

  Widget _buildBaslik(AppColorScheme c) {
    return Container(
      color: c.bgSecondary,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_rounded, color: c.textSecondary, size: 20),
          ),
          const SizedBox(width: 8),
          Icon(Icons.upload_file_rounded, color: AppColors.teal, size: 20),
          const SizedBox(width: 10),
          Text('CSV / Excel İçe Aktarma',
            style: GoogleFonts.outfit(
              color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
          const Spacer(),
          Text('Eski POS → Liqra Terminal',
            style: GoogleFonts.outfit(fontSize: 12, color: c.textSecondary)),
        ],
      ),
    );
  }

  // ── Stepper göstergesi ─────────────────────────────────────────────────────

  Widget _buildStepper(AppColorScheme c) {
    const adimlar = ['Dosya Yükle', 'Sütun Eşleştir', 'Önizle & Kaydet'];
    return Container(
      color: c.bgSecondary,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
      child: Row(
        children: adimlar.asMap().entries.map((e) {
          final idx     = e.key;
          final label   = e.value;
          final done    = idx < _adim;
          final current = idx == _adim;

          return Expanded(
            child: Row(
              children: [
                // Çizgi (ilk hariç)
                if (idx > 0) Expanded(
                  child: Container(height: 1,
                    color: done ? AppColors.teal : c.border),
                ),
                // Daire
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? AppColors.teal
                        : current
                            ? AppColors.teal.withAlpha(30)
                            : c.bgCard,
                    border: Border.all(
                      color: done || current ? AppColors.teal : c.border,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: done
                        ? const Icon(Icons.check_rounded, size: 14, color: Colors.black)
                        : Text('${idx + 1}',
                            style: GoogleFonts.dmMono(
                              fontSize: 11,
                              color: current ? AppColors.teal : c.textMuted,
                              fontWeight: FontWeight.w700,
                            )),
                  ),
                ),
                const SizedBox(width: 6),
                Text(label,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: done || current ? c.textPrimary : c.textMuted,
                    fontWeight: current ? FontWeight.w700 : FontWeight.w400,
                  )),
                if (idx < adimlar.length - 1) Expanded(
                  child: Container(height: 1,
                    color: done ? AppColors.teal : c.border),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Adım içerikleri ────────────────────────────────────────────────────────

  Widget _buildAdim(AppColorScheme c) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: KeyedSubtree(
        key: ValueKey(_adim),
        child: switch (_adim) {
          0 => _Adim1Dosya(
              dosyaYolu:    _dosyaYolu,
              basliklar:    _basliklar,
              satirlar:     _satirlar,
              baslikVarMi:  _baslikVarMi,
              ayirici:      _ayirici,
              onDosyaSec:   _dosyaSec,
              onBaslikToggle: (v) => setState(() {
                _baslikVarMi = v;
                _basliklarGuncelle();
              }),
              onAyiriciDegis: (v) => setState(() {
                _ayirici = v;
                if (_dosyaYolu != null) _dosyaYeniden();
              }),
            ),
          1 => _Adim2Eslesme(
              basliklar:        _basliklar,
              colAd:            _colAd,
              colBarkod:        _colBarkod,
              colSatisFiyati:   _colSatisFiyati,
              colAlisFiyati:    _colAlisFiyati,
              colStok:          _colStok,
              colKategori:      _colKategori,
              colKritikStok:    _colKritikStok,
              varsayilanKat:    _varsayilanKat,
              guncelleVarolan:  _guncelleVarolan,
              onChanged:        _eslesmeDegis,
              onVarsayilanKat:  (v) => setState(() => _varsayilanKat = v),
              onGuncelleToggle: (v) => setState(() => _guncelleVarolan = v),
            ),
          2 => _Adim3Onizleme(
              onizleme: _onizleme,
              hatalar:  _hatalar,
              islem:    _islem,
              sonuc:    _sonuc,
            ),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }

  // ── Alt butonlar ───────────────────────────────────────────────────────────

  Widget _buildAlttaki(AppColorScheme c) {
    final ileri  = _ileriAktif();
    final sonAdim = _adim == 2;

    return Container(
      color: c.bgSecondary,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          if (_adim > 0 && _sonuc == null)
            OutlinedButton.icon(
              onPressed: () => setState(() => _adim--),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Geri'),
              style: OutlinedButton.styleFrom(foregroundColor: c.textSecondary),
            ),
          const Spacer(),
          // Kaydet sonrası kapat
          if (_sonuc != null)
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check_circle_rounded, size: 16),
              label: const Text('Tamamlandı, Kapat'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.accentGreen),
            )
          else
            FilledButton.icon(
              onPressed: ileri ? (sonAdim ? _kaydet : _ileriGit) : null,
              icon: Icon(sonAdim
                ? Icons.save_rounded
                : Icons.arrow_forward_rounded, size: 16),
              label: Text(sonAdim ? 'Ürünleri Kaydet' : 'İleri'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.black,
                disabledBackgroundColor: c.border,
              ),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // İş mantığı
  // ══════════════════════════════════════════════════════════════════════════

  bool _ileriAktif() {
    if (_adim == 0) return _satirlar.isNotEmpty;
    if (_adim == 1) return _colAd != 'AUTO' || _basliklar.isNotEmpty;
    if (_adim == 2) return _onizleme.isNotEmpty && _sonuc == null;
    return false;
  }

  Future<void> _dosyaSec() async {
    final sonuc = await FilePicker.platform.pickFiles(
      type:           FileType.custom,
      allowedExtensions: ['csv', 'txt'],
      dialogTitle:    'CSV Dosyasını Seçin',
    );
    if (sonuc == null || sonuc.files.isEmpty) return;

    setState(() => _dosyaYolu = sonuc.files.first.path);
    await _dosyaYeniden();
  }

  Future<void> _dosyaYeniden() async {
    if (_dosyaYolu == null) return;
    try {
      final icerik = await File(_dosyaYolu!).readAsString();
      // Otomatik ayırıcı tespiti
      if (_ayirici == ',') {
        final noktaliVirg = icerik.split('\n').first.split(';').length;
        final virgul      = icerik.split('\n').first.split(',').length;
        final tab         = icerik.split('\n').first.split('\t').length;
        if (noktaliVirg > virgul && noktaliVirg > tab) {
          _ayirici = ';';
        } else if (tab > virgul) {
          _ayirici = '\t';
        }
      }

      final satirlar = const CsvToListConverter(
        eol: '\n',
        fieldDelimiter: ',',
        shouldParseNumbers: false,
      ).convert(icerik.replaceAll(';', ',').replaceAll('\t', ','));

      setState(() {
        _satirlar = satirlar.where((s) => s.any((c) => c.toString().trim().isNotEmpty)).toList();
        _basliklarGuncelle();
        _otomatikEsles();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dosya okunamadı: $e'), backgroundColor: AppColors.accentRed));
      }
    }
  }

  void _basliklarGuncelle() {
    if (_satirlar.isEmpty) return;
    if (_baslikVarMi) {
      _basliklar = _satirlar.first.map((e) => e.toString().trim()).toList();
    } else {
      _basliklar = List.generate(
        _satirlar.first.length, (i) => 'Sütun ${i + 1}');
    }
  }

  /// Başlık adlarına bakarak otomatik eşleştir
  void _otomatikEsles() {
    for (var i = 0; i < _basliklar.length; i++) {
      final bas = _basliklar[i].toLowerCase();
      final idx = i.toString();

      if (_colAd == 'AUTO' && (bas.contains('ad') || bas.contains('name') || bas.contains('ürün') || bas.contains('urun'))) {
        _colAd = idx;
      }
      if (_colBarkod == 'AUTO' && (bas.contains('barkod') || bas.contains('barcode') || bas.contains('kod') || bas.contains('ean'))) {
        _colBarkod = idx;
      }
      if (_colSatisFiyati == 'AUTO' && (bas.contains('fiyat') || bas.contains('price') || bas.contains('satis') || bas.contains('satış'))) {
        _colSatisFiyati = idx;
      }
      if (_colAlisFiyati == 'SKIP' && (bas.contains('alis') || bas.contains('alış') || bas.contains('maliyet') || bas.contains('cost'))) {
        _colAlisFiyati = idx;
      }
      if (_colStok == 'SKIP' && (bas.contains('stok') || bas.contains('stock') || bas.contains('miktar') || bas.contains('adet'))) {
        _colStok = idx;
      }
      if (_colKategori == 'SKIP' && (bas.contains('kategori') || bas.contains('category') || bas.contains('grup') || bas.contains('group'))) {
        _colKategori = idx;
      }
    }
  }

  void _eslesmeDegis(String alan, String deger) => setState(() {
    switch (alan) {
      case 'ad':          _colAd          = deger;
      case 'barkod':      _colBarkod      = deger;
      case 'satisFiyati': _colSatisFiyati = deger;
      case 'alisFiyati':  _colAlisFiyati  = deger;
      case 'stok':        _colStok        = deger;
      case 'kategori':    _colKategori    = deger;
      case 'kritikStok':  _colKritikStok  = deger;
    }
  });

  void _ileriGit() {
    if (_adim == 1) {
      // Adım 2 → 3: veriyi dönüştür
      _donustur();
    }
    setState(() => _adim++);
  }

  void _donustur() {
    final uuid  = const Uuid();
    final listesi = _baslikVarMi ? _satirlar.skip(1).toList() : _satirlar;

    _onizleme = [];
    _hatalar  = [];

    for (var i = 0; i < listesi.length; i++) {
      final satir = listesi[i];
      final satirNo = i + (_baslikVarMi ? 2 : 1);

      // ── Ürün Adı (zorunlu) ──────────────────────────────────────────
      final ad = _colAd != 'AUTO'
          ? _col(satir, int.parse(_colAd))
          : '';
      if (ad.isEmpty) {
        _hatalar.add('Satır $satirNo: Ürün adı boş, atlandı.');
        continue;
      }

      // ── Satış Fiyatı (zorunlu) ──────────────────────────────────────
      double satisFiyati = 0;
      if (_colSatisFiyati != 'AUTO') {
        final raw = _col(satir, int.parse(_colSatisFiyati))
            .replaceAll('.', '')
            .replaceAll(',', '.')
            .replaceAll('₺', '')
            .replaceAll(' ', '')
            .trim();
        satisFiyati = double.tryParse(raw) ?? 0;
        if (satisFiyati <= 0) {
          _hatalar.add('Satır $satirNo: Geçersiz fiyat "$raw", 0 kabul edildi.');
        }
      }

      // ── Alış Fiyatı ─────────────────────────────────────────────────
      double alisFiyati = 0;
      if (_colAlisFiyati != 'SKIP') {
        final raw = _col(satir, int.parse(_colAlisFiyati))
            .replaceAll('.', '').replaceAll(',', '.').replaceAll('₺', '').trim();
        alisFiyati = double.tryParse(raw) ?? 0;
      }

      // ── Stok ────────────────────────────────────────────────────────
      int stok = 0;
      if (_colStok != 'SKIP') {
        stok = int.tryParse(_col(satir, int.parse(_colStok)).trim()) ?? 0;
      }

      // ── Kritik Stok ─────────────────────────────────────────────────
      int kritikStok = 5;
      if (_colKritikStok != 'SKIP') {
        kritikStok = int.tryParse(_col(satir, int.parse(_colKritikStok)).trim()) ?? 5;
      }

      // ── Kategori ────────────────────────────────────────────────────
      String kategori = _varsayilanKat;
      if (_colKategori != 'SKIP') {
        final kat = _col(satir, int.parse(_colKategori)).trim();
        if (kat.isNotEmpty) kategori = kat;
      }

      // ── Barkod ──────────────────────────────────────────────────────
      String barkod = UrunViewModel.otomatikBarkod();
      if (_colBarkod != 'AUTO') {
        final raw = _col(satir, int.parse(_colBarkod)).trim();
        if (raw.isNotEmpty) barkod = raw;
      }

      _onizleme.add(ProductModel(
        id:          uuid.v4(),
        ad:          ad,
        barkod:      barkod,
        kategori:    kategori,
        satisFiyati: satisFiyati,
        alisFiyati:  alisFiyati,
        stok:        stok,
        kritikStok:  kritikStok,
      ));
    }
  }

  String _col(List<dynamic> satir, int idx) =>
      idx < satir.length ? satir[idx].toString().trim() : '';

  Future<void> _kaydet() async {
    setState(() => _islem = true);
    final vm  = context.read<UrunViewModel>();
    final sn  = await vm.csvImport(_onizleme, guncelle: _guncelleVarolan);
    setState(() {
      _islem = false;
      _sonuc = sn;
    });
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ADIM 1 — Dosya Yükle
// ══════════════════════════════════════════════════════════════════════════════

class _Adim1Dosya extends StatelessWidget {
  final String?              dosyaYolu;
  final List<String>         basliklar;
  final List<List<dynamic>>  satirlar;
  final bool                 baslikVarMi;
  final String               ayirici;
  final VoidCallback         onDosyaSec;
  final ValueChanged<bool>   onBaslikToggle;
  final ValueChanged<String> onAyiriciDegis;

  const _Adim1Dosya({
    required this.dosyaYolu,
    required this.basliklar,
    required this.satirlar,
    required this.baslikVarMi,
    required this.ayirici,
    required this.onDosyaSec,
    required this.onBaslikToggle,
    required this.onAyiriciDegis,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bilgi kutusu
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.teal.withAlpha(12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.teal.withAlpha(40)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.teal, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Eski POS programınızdan "Ürün Listesi"ni .CSV veya .TXT olarak dışa aktarın. '
                    'Mikro, Logo, Adisyon, İşletme+ gibi çoğu program bu formatı destekler.',
                    style: GoogleFonts.outfit(fontSize: 12, color: c.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Dosya seçici
          GestureDetector(
            onTap: onDosyaSec,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: c.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: dosyaYolu != null ? AppColors.teal : c.border,
                  width: dosyaYolu != null ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    dosyaYolu != null
                        ? Icons.check_circle_rounded
                        : Icons.upload_file_rounded,
                    size: 40,
                    color: dosyaYolu != null ? AppColors.accentGreen : c.textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    dosyaYolu != null
                        ? dosyaYolu!.split(Platform.pathSeparator).last
                        : 'CSV / TXT dosyası seçin',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: dosyaYolu != null ? c.textPrimary : c.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (dosyaYolu == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('Tıklayın veya sürükleyin',
                        style: GoogleFonts.outfit(fontSize: 11, color: c.textMuted)),
                    ),
                  if (satirlar.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('${satirlar.length} satır okundu',
                        style: GoogleFonts.outfit(fontSize: 11, color: AppColors.teal)),
                    ),
                ],
              ),
            ),
          ),

          if (dosyaYolu != null) ...[
            const SizedBox(height: 16),

            // Ayarlar
            Row(
              children: [
                // Başlık satırı var mı
                Switch(
                  value: baslikVarMi,
                  onChanged: onBaslikToggle,
                  activeColor: AppColors.teal,
                ),
                const SizedBox(width: 8),
                Text('İlk satır başlık (sütun adları)',
                  style: GoogleFonts.outfit(fontSize: 13, color: c.textPrimary)),
                const SizedBox(width: 24),

                // Ayırıcı seçimi
                Text('Ayırıcı:', style: GoogleFonts.outfit(fontSize: 13, color: c.textSecondary)),
                const SizedBox(width: 8),
                ...{',': 'Virgül', ';': 'Noktalı Virgül', '\t': 'Tab'}.entries.map((e) {
                  final sel = ayirici == e.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(e.value),
                      selected: sel,
                      onSelected: (_) => onAyiriciDegis(e.key),
                      selectedColor: AppColors.teal.withAlpha(30),
                      side: BorderSide(color: sel ? AppColors.teal : c.border),
                      labelStyle: GoogleFonts.outfit(
                        fontSize: 11,
                        color: sel ? AppColors.teal : c.textSecondary,
                      ),
                      showCheckmark: false,
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),

            // Önizleme tablosu
            if (satirlar.isNotEmpty) _OnizlemeTablosu(
              basliklar: basliklar,
              satirlar:  satirlar.take(6).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ADIM 2 — Sütun Eşleştir
// ══════════════════════════════════════════════════════════════════════════════

class _Adim2Eslesme extends StatelessWidget {
  final List<String>                   basliklar;
  final String colAd, colBarkod, colSatisFiyati, colAlisFiyati,
               colStok, colKategori, colKritikStok;
  final String   varsayilanKat;
  final bool     guncelleVarolan;
  final void Function(String alan, String deger) onChanged;
  final ValueChanged<String> onVarsayilanKat;
  final ValueChanged<bool>   onGuncelleToggle;

  const _Adim2Eslesme({
    required this.basliklar,
    required this.colAd,
    required this.colBarkod,
    required this.colSatisFiyati,
    required this.colAlisFiyati,
    required this.colStok,
    required this.colKategori,
    required this.colKritikStok,
    required this.varsayilanKat,
    required this.guncelleVarolan,
    required this.onChanged,
    required this.onVarsayilanKat,
    required this.onGuncelleToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Dropdown seçenekleri
    final secenekler = [
      for (var i = 0; i < basliklar.length; i++)
        DropdownMenuItem(value: i.toString(), child: Text('[$i] ${basliklar[i]}')),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Her alanın CSV\'deki hangi sütundan geleceğini seçin.',
            style: GoogleFonts.outfit(fontSize: 13, color: c.textSecondary)),
          const SizedBox(height: 20),

          // 2 sütunlu grid
          Wrap(spacing: 16, runSpacing: 16, children: [
            _EslemeKarti(
              label:    'Ürün Adı *',
              subtitle: 'Zorunlu',
              icon:     Icons.label_rounded,
              color:    AppColors.teal,
              deger:    colAd,
              secenekler: secenekler,
              zorunlu:  true,
              onChanged: (v) => onChanged('ad', v),
            ),
            _EslemeKarti(
              label:    'Satış Fiyatı *',
              subtitle: 'Zorunlu — virgül veya nokta kabul edilir',
              icon:     Icons.payments_rounded,
              color:    AppColors.accentGreen,
              deger:    colSatisFiyati,
              secenekler: secenekler,
              zorunlu:  true,
              onChanged: (v) => onChanged('satisFiyati', v),
            ),
            _EslemeKarti(
              label:    'Barkod',
              subtitle: 'Boş bırakılırsa otomatik LQR kodu üretilir',
              icon:     Icons.qr_code_rounded,
              color:    AppColors.gold,
              deger:    colBarkod,
              secenekler: secenekler,
              skipLabel: 'Otomatik üret',
              onChanged: (v) => onChanged('barkod', v),
            ),
            _EslemeKarti(
              label:    'Alış Fiyatı',
              subtitle: 'Kâr hesabı için opsiyonel',
              icon:     Icons.shopping_bag_rounded,
              color:    AppColors.tealDark,
              deger:    colAlisFiyati,
              secenekler: secenekler,
              onChanged: (v) => onChanged('alisFiyati', v),
            ),
            _EslemeKarti(
              label:    'Stok Miktarı',
              subtitle: 'Boş bırakılırsa 0 kabul edilir',
              icon:     Icons.inventory_2_rounded,
              color:    AppColors.tealDark,
              deger:    colStok,
              secenekler: secenekler,
              onChanged: (v) => onChanged('stok', v),
            ),
            _EslemeKarti(
              label:    'Kategori',
              subtitle: 'Boş bırakılırsa varsayılan kategori kullanılır',
              icon:     Icons.folder_rounded,
              color:    AppColors.gold,
              deger:    colKategori,
              secenekler: secenekler,
              onChanged: (v) => onChanged('kategori', v),
            ),
          ]),

          const SizedBox(height: 20),

          // Varsayılan kategori
          Row(
            children: [
              Text('Varsayılan Kategori:',
                style: GoogleFonts.outfit(fontSize: 13, color: c.textSecondary)),
              const SizedBox(width: 12),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: TextEditingController(text: varsayilanKat),
                  onChanged: onVarsayilanKat,
                  style: GoogleFonts.outfit(fontSize: 13, color: c.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: c.border)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Güncelleme seçeneği
          Row(
            children: [
              Switch(
                value: guncelleVarolan,
                onChanged: onGuncelleToggle,
                activeColor: AppColors.teal,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Aynı barkoda sahip ürünleri güncelle',
                      style: GoogleFonts.outfit(fontSize: 13, color: c.textPrimary)),
                    Text('Kapalıysa aynı barkodlu ürünler atlanır',
                      style: GoogleFonts.outfit(fontSize: 11, color: c.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EslemeKarti extends StatelessWidget {
  final String  label;
  final String  subtitle;
  final IconData icon;
  final Color   color;
  final String  deger;
  final List<DropdownMenuItem<String>> secenekler;
  final bool    zorunlu;
  final String  skipLabel;
  final ValueChanged<String> onChanged;

  const _EslemeKarti({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.deger,
    required this.secenekler,
    this.zorunlu   = false,
    this.skipLabel = 'Atla',
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 320,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(label,
                style: GoogleFonts.outfit(
                  fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
            ],
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: GoogleFonts.outfit(fontSize: 10, color: c.textMuted)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: deger == 'AUTO' || deger == 'SKIP' ? null : deger,
            hint: Text(
              zorunlu ? '— Sütun seçin —' : skipLabel,
              style: GoogleFonts.outfit(fontSize: 12, color: c.textMuted)),
            items: [
              if (!zorunlu)
                DropdownMenuItem(
                  value: null,
                  child: Text(skipLabel,
                    style: GoogleFonts.outfit(fontSize: 12, color: c.textMuted))),
              ...secenekler,
            ],
            onChanged: (v) => onChanged(v ?? (zorunlu ? 'AUTO' : 'SKIP')),
            style: GoogleFonts.outfit(fontSize: 12, color: c.textPrimary),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: c.border)),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ADIM 3 — Önizleme & Kaydet
// ══════════════════════════════════════════════════════════════════════════════

class _Adim3Onizleme extends StatelessWidget {
  final List<ProductModel> onizleme;
  final List<String>       hatalar;
  final bool               islem;
  final ImportSonuc?       sonuc;

  const _Adim3Onizleme({
    required this.onizleme,
    required this.hatalar,
    required this.islem,
    required this.sonuc,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (islem) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.teal, strokeWidth: 2),
            const SizedBox(height: 16),
            Text('${onizleme.length} ürün kaydediliyor...',
              style: GoogleFonts.outfit(color: c.textSecondary)),
          ],
        ),
      );
    }

    if (sonuc != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                sonuc!.basarili ? Icons.check_circle_rounded : Icons.error_rounded,
                size: 56,
                color: sonuc!.basarili ? AppColors.accentGreen : AppColors.accentRed,
              ),
              const SizedBox(height: 16),
              Text(
                sonuc!.basarili ? 'Aktarım Tamamlandı!' : 'Hata Oluştu',
                style: GoogleFonts.outfit(
                  fontSize: 20, fontWeight: FontWeight.w700,
                  color: c.textPrimary),
              ),
              const SizedBox(height: 16),
              if (sonuc!.basarili) ...[
                _SonucSatir('Yeni eklenen',    '${sonuc!.eklenen}',    AppColors.accentGreen),
                _SonucSatir('Güncellenen',    '${sonuc!.guncellenen}', AppColors.teal),
                _SonucSatir('Atlanan',        '${sonuc!.atlanan}',    AppColors.gold),
              ] else
                Text(sonuc!.hata ?? 'Bilinmeyen hata',
                  style: GoogleFonts.outfit(color: AppColors.accentRed, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Özet bar
        Container(
          color: c.bgSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.accentGreen, size: 16),
              const SizedBox(width: 8),
              Text('${onizleme.length} ürün aktarılacak',
                style: GoogleFonts.outfit(
                  fontSize: 13, color: c.textPrimary, fontWeight: FontWeight.w600)),
              if (hatalar.isNotEmpty) ...[
                const SizedBox(width: 16),
                Icon(Icons.warning_amber_rounded, color: AppColors.gold, size: 16),
                const SizedBox(width: 6),
                Text('${hatalar.length} satır atlandı',
                  style: GoogleFonts.outfit(fontSize: 13, color: AppColors.gold)),
              ],
            ],
          ),
        ),
        Divider(height: 1, color: c.border),

        // Ürün önizleme tablosu
        Expanded(
          child: ListView.builder(
            itemCount: onizleme.length,
            itemBuilder: (context, i) {
              final p = onizleme[i];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: c.border, width: 0.5))),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text('${i + 1}',
                        style: GoogleFonts.dmMono(fontSize: 11, color: c.textMuted))),
                    Expanded(
                      flex: 3,
                      child: Text(p.ad,
                        style: GoogleFonts.outfit(
                          fontSize: 13, color: c.textPrimary, fontWeight: FontWeight.w500))),
                    Expanded(
                      flex: 2,
                      child: Text(p.barkod,
                        style: GoogleFonts.dmMono(fontSize: 11, color: c.textSecondary))),
                    SizedBox(
                      width: 80,
                      child: Text(p.kategori,
                        style: GoogleFonts.outfit(fontSize: 11, color: c.textMuted))),
                    SizedBox(
                      width: 60,
                      child: Text('${p.stok}',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.dmMono(fontSize: 11, color: c.textSecondary))),
                    SizedBox(
                      width: 96,
                      child: Text(_fmtMoney.format(p.satisFiyati),
                        textAlign: TextAlign.right,
                        style: GoogleFonts.dmMono(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: c.textPrimary))),
                  ],
                ),
              );
            },
          ),
        ),

        // Hata mesajları
        if (hatalar.isNotEmpty) ...[
          Divider(height: 1, color: c.border),
          Container(
            height: 80, color: AppColors.accentRed.withAlpha(10),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: hatalar.length,
              itemBuilder: (context, i) => Text(
                hatalar[i],
                style: GoogleFonts.outfit(fontSize: 11, color: AppColors.accentRed)),
            ),
          ),
        ],
      ],
    );
  }
}

class _SonucSatir extends StatelessWidget {
  final String label;
  final String deger;
  final Color  renk;
  const _SonucSatir(this.label, this.deger, this.renk);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 120,
            child: Text(label,
              style: GoogleFonts.outfit(fontSize: 14, color: c.textSecondary))),
          Text(deger,
            style: GoogleFonts.dmMono(
              fontSize: 16, fontWeight: FontWeight.w700, color: renk)),
        ],
      ),
    );
  }
}

// ── Yardımcı: Önizleme tablosu (adım 1) ──────────────────────────────────────

class _OnizlemeTablosu extends StatelessWidget {
  final List<String>        basliklar;
  final List<List<dynamic>> satirlar;
  const _OnizlemeTablosu({required this.basliklar, required this.satirlar});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('İlk ${satirlar.length} Satır Önizlemesi',
          style: GoogleFonts.outfit(
            fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(c.bgTertiary),
              dataRowColor: WidgetStatePropertyAll(c.bgCard),
              border: TableBorder.all(color: c.border, width: 0.5),
              headingTextStyle: GoogleFonts.outfit(
                fontSize: 11, fontWeight: FontWeight.w600, color: c.textSecondary),
              dataTextStyle: GoogleFonts.dmMono(fontSize: 11, color: c.textPrimary),
              columns: basliklar
                  .map((h) => DataColumn(label: Text(h, overflow: TextOverflow.ellipsis)))
                  .toList(),
              rows: satirlar.map((s) => DataRow(
                cells: List.generate(basliklar.length, (i) =>
                  DataCell(Text(
                    i < s.length ? s[i].toString() : '',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ))),
              )).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

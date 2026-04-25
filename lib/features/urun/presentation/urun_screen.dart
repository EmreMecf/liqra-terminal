import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_color_scheme.dart';
import '../../terminal/data/models/product_model.dart';
import '../viewmodel/urun_viewmodel.dart';
import 'urun_import_screen.dart';

final _fmtMoney = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);

// ══════════════════════════════════════════════════════════════════════════════
// ÜRÜN YÖNETİMİ EKRANI
// ══════════════════════════════════════════════════════════════════════════════

class UrunScreen extends StatefulWidget {
  const UrunScreen({super.key});

  @override
  State<UrunScreen> createState() => _UrunScreenState();
}

class _UrunScreenState extends State<UrunScreen> {
  bool _yeniUrunModu = false;
  ProductModel? _formUrun; // null = seçim yok, değer = düzenle/yeni

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UrunViewModel>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c  = context.colors;
    final vm = context.watch<UrunViewModel>();

    return Scaffold(
      backgroundColor: c.bgPrimary,
      body: Column(
        children: [
          _Header(
            vm: vm,
            onYeniUrun: () => setState(() {
              _yeniUrunModu = true;
              _formUrun     = vm.yeniUrunSablonu();
              vm.urunSec(null);
            }),
            onImport: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UrunImportScreen()),
            ).then((_) => vm.init()),
          ),
          Divider(height: 1, color: c.border),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Sol: Liste ──────────────────────────────────────────
                SizedBox(
                  width: 380,
                  child: _UrunListesi(
                    vm: vm,
                    secilenId: _formUrun?.id,
                    onSec: (p) => setState(() {
                      _yeniUrunModu = false;
                      _formUrun     = p;
                      vm.urunSec(p);
                    }),
                  ),
                ),
                VerticalDivider(width: 1, color: c.border),

                // ── Sağ: Form / Boş ─────────────────────────────────────
                Expanded(
                  child: _formUrun != null
                      ? _UrunForm(
                          key:          ValueKey(_formUrun!.id),
                          urun:         _formUrun!,
                          yeniMi:       _yeniUrunModu,
                          vm:           vm,
                          onKaydet:     (p) async {
                            final ok = await vm.kaydet(p);
                            if (ok && mounted) {
                              setState(() {
                                _yeniUrunModu = false;
                                _formUrun = p;
                              });
                            }
                            return ok;
                          },
                          onSil:        (id) async {
                            final onay = await _silOnay(context, _formUrun!.ad);
                            if (!onay) return;
                            await vm.sil(id);
                            setState(() { _formUrun = null; _yeniUrunModu = false; });
                          },
                          onIptal:      () => setState(() {
                            _formUrun     = null;
                            _yeniUrunModu = false;
                            vm.urunSec(null);
                          }),
                        )
                      : _BosHal(
                          onYeniUrun: () => setState(() {
                            _yeniUrunModu = true;
                            _formUrun     = vm.yeniUrunSablonu();
                          }),
                          onImport: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const UrunImportScreen()),
                          ).then((_) => vm.init()),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _silOnay(BuildContext context, String ad) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ürünü Kaldır',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: Text('"$ad" ürünü pasif yapılacak.\nSatış geçmişi korunur.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accentRed),
            child: const Text('Kaldır')),
        ],
      ),
    ) ?? false;
  }
}

// ── Üst çubuk ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final UrunViewModel vm;
  final VoidCallback  onYeniUrun;
  final VoidCallback  onImport;
  const _Header({required this.vm, required this.onYeniUrun, required this.onImport});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      color: c.bgSecondary,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.inventory_2_rounded, color: AppColors.teal, size: 20),
          const SizedBox(width: 10),
          Text('Ürün Yönetimi',
            style: GoogleFonts.outfit(
              color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(width: 24),

          // Özet chips
          _MiniStat(label: '${vm.toplamUrun} Ürün',       color: AppColors.teal),
          const SizedBox(width: 8),
          if (vm.kritikStokSayisi > 0)
            _MiniStat(label: '${vm.kritikStokSayisi} Kritik', color: AppColors.gold),
          if (vm.stokSifirSayisi > 0) ...[
            const SizedBox(width: 8),
            _MiniStat(label: '${vm.stokSifirSayisi} Tükendi', color: AppColors.accentRed),
          ],

          const Spacer(),

          // CSV Import
          OutlinedButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.upload_file_rounded, size: 16),
            label: const Text('CSV İçe Aktar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.gold,
              side: BorderSide(color: AppColors.gold.withAlpha(80)),
            ),
          ),
          const SizedBox(width: 10),

          // Yeni Ürün
          FilledButton.icon(
            onPressed: onYeniUrun,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Yeni Ürün'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final Color  color;
  const _MiniStat({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Text(label,
        style: GoogleFonts.outfit(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Sol: Ürün Listesi ─────────────────────────────────────────────────────────

class _UrunListesi extends StatefulWidget {
  final UrunViewModel     vm;
  final String?           secilenId;
  final ValueChanged<ProductModel> onSec;
  const _UrunListesi({required this.vm, required this.secilenId, required this.onSec});

  @override
  State<_UrunListesi> createState() => _UrunListesiState();
}

class _UrunListesiState extends State<_UrunListesi> {
  final _aramaCtrl = TextEditingController();

  @override
  void dispose() {
    _aramaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c  = context.colors;
    final vm = widget.vm;

    return Column(
      children: [
        // Arama
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _aramaCtrl,
            onChanged: vm.ara,
            style: GoogleFonts.outfit(fontSize: 13, color: c.textPrimary),
            decoration: InputDecoration(
              hintText: 'Ürün adı veya barkod ara...',
              prefixIcon: Icon(Icons.search_rounded, color: c.textSecondary, size: 18),
              suffixIcon: _aramaCtrl.text.isNotEmpty
                  ? IconButton(
                      onPressed: () { _aramaCtrl.clear(); vm.ara(''); },
                      icon: Icon(Icons.clear_rounded, size: 16, color: c.textSecondary))
                  : null,
              isDense: true,
            ),
          ),
        ),

        // Kategori filtreleri
        if (vm.kategoriler.isNotEmpty)
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _KatChip(label: 'Tümü', sel: vm.secilenKategori == null,
                  onTap: () => vm.kategoriSec(null)),
                ...vm.kategoriler.map((k) => _KatChip(
                  label: k,
                  sel: vm.secilenKategori == k,
                  onTap: () => vm.kategoriSec(k),
                )),
              ],
            ),
          ),

        Divider(height: 1, color: c.border),

        // Liste
        Expanded(
          child: vm.loading
              ? Center(child: CircularProgressIndicator(
                  color: AppColors.teal, strokeWidth: 2))
              : vm.filtered.isEmpty
                  ? Center(
                      child: Text('Ürün bulunamadı',
                        style: GoogleFonts.outfit(color: c.textMuted)))
                  : ListView.builder(
                      itemCount: vm.filtered.length,
                      itemBuilder: (context, i) {
                        final p   = vm.filtered[i];
                        final sel = p.id == widget.secilenId;
                        return _UrunSatiri(urun: p, selected: sel,
                          onTap: () => widget.onSec(p));
                      },
                    ),
        ),
      ],
    );
  }
}

class _KatChip extends StatelessWidget {
  final String label;
  final bool   sel;
  final VoidCallback onTap;
  const _KatChip({required this.label, required this.sel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: sel ? AppColors.teal.withAlpha(25) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? AppColors.teal.withAlpha(100) : c.border),
        ),
        child: Text(label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: sel ? AppColors.teal : c.textSecondary,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
          )),
      ),
    );
  }
}

class _UrunSatiri extends StatelessWidget {
  final ProductModel urun;
  final bool         selected;
  final VoidCallback onTap;
  const _UrunSatiri({required this.urun, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: selected ? AppColors.teal.withAlpha(18) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Stok durumu göstergesi
            Container(
              width: 4, height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: urun.stokTukendi
                    ? AppColors.accentRed
                    : urun.stokKritik
                        ? AppColors.gold
                        : AppColors.accentGreen,
              ),
            ),
            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(urun.ad,
                    style: GoogleFonts.outfit(
                      fontSize: 13, color: c.textPrimary,
                      fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
                  Text(urun.barkod,
                    style: GoogleFonts.dmMono(fontSize: 10, color: c.textMuted)),
                ],
              ),
            ),

            // Stok
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (urun.stokTukendi
                    ? AppColors.accentRed
                    : urun.stokKritik
                        ? AppColors.gold
                        : AppColors.accentGreen).withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${urun.stok}',
                style: GoogleFonts.dmMono(
                  fontSize: 11,
                  color: urun.stokTukendi
                      ? AppColors.accentRed
                      : urun.stokKritik
                          ? AppColors.gold
                          : AppColors.accentGreen,
                  fontWeight: FontWeight.w700,
                )),
            ),
            const SizedBox(width: 8),

            // Fiyat
            SizedBox(
              width: 80,
              child: Text(_fmtMoney.format(urun.satisFiyati),
                textAlign: TextAlign.right,
                style: GoogleFonts.dmMono(
                  fontSize: 12, color: c.textPrimary, fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }
}

// ── Sağ: Ürün Formu ───────────────────────────────────────────────────────────

class _UrunForm extends StatefulWidget {
  final ProductModel                    urun;
  final bool                            yeniMi;
  final UrunViewModel                   vm;
  final Future<bool> Function(ProductModel) onKaydet;
  final void Function(String)           onSil;
  final VoidCallback                    onIptal;

  const _UrunForm({
    super.key,
    required this.urun,
    required this.yeniMi,
    required this.vm,
    required this.onKaydet,
    required this.onSil,
    required this.onIptal,
  });

  @override
  State<_UrunForm> createState() => _UrunFormState();
}

class _UrunFormState extends State<_UrunForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _adCtrl;
  late final TextEditingController _barkodCtrl;
  late final TextEditingController _kategoriCtrl;
  late final TextEditingController _satisFiyatiCtrl;
  late final TextEditingController _alisFiyatiCtrl;
  late final TextEditingController _stokCtrl;
  late final TextEditingController _kritikStokCtrl;
  late final TextEditingController _birimCtrl;

  bool _kaydediliyor = false;
  String? _barkodHata;

  @override
  void initState() {
    super.initState();
    final p = widget.urun;
    _adCtrl          = TextEditingController(text: p.ad);
    _barkodCtrl      = TextEditingController(text: p.barkod);
    _kategoriCtrl    = TextEditingController(text: p.kategori);
    _satisFiyatiCtrl = TextEditingController(text: p.satisFiyati > 0 ? p.satisFiyati.toStringAsFixed(2) : '');
    _alisFiyatiCtrl  = TextEditingController(text: p.alisFiyati  > 0 ? p.alisFiyati.toStringAsFixed(2)  : '');
    _stokCtrl        = TextEditingController(text: '${p.stok}');
    _kritikStokCtrl  = TextEditingController(text: '${p.kritikStok}');
    _birimCtrl       = TextEditingController(text: p.birim ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _adCtrl, _barkodCtrl, _kategoriCtrl, _satisFiyatiCtrl,
      _alisFiyatiCtrl, _stokCtrl, _kritikStokCtrl, _birimCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  void _yeniBarkod() {
    setState(() {
      _barkodCtrl.text = UrunViewModel.otomatikBarkod();
      _barkodHata = null;
    });
  }

  Future<void> _kaydet() async {
    if (!_formKey.currentState!.validate()) return;

    // Barkod tekrar kontrolü
    final barkod   = _barkodCtrl.text.trim();
    if (widget.vm.barkodKullanimda(barkod, haricId: widget.urun.id)) {
      setState(() => _barkodHata = 'Bu barkod başka bir üründe kullanılıyor');
      return;
    }

    setState(() => _kaydediliyor = true);

    final guncellenmis = widget.urun.copyWith(
      ad:          _adCtrl.text.trim(),
      barkod:      barkod,
      kategori:    _kategoriCtrl.text.trim().isEmpty ? 'Genel' : _kategoriCtrl.text.trim(),
      satisFiyati: double.tryParse(_satisFiyatiCtrl.text.replaceAll(',', '.')) ?? 0,
      alisFiyati:  double.tryParse(_alisFiyatiCtrl.text.replaceAll(',', '.'))  ?? 0,
      stok:        int.tryParse(_stokCtrl.text) ?? 0,
      kritikStok:  int.tryParse(_kritikStokCtrl.text) ?? 5,
      birim:       _birimCtrl.text.trim().isEmpty ? null : _birimCtrl.text.trim(),
    );

    final ok = await widget.onKaydet(guncellenmis);
    if (mounted) {
      setState(() => _kaydediliyor = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.yeniMi ? 'Ürün eklendi' : 'Güncellendi'),
            backgroundColor: AppColors.accentGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      children: [
        // Form başlığı
        Container(
          color: c.bgSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(
                widget.yeniMi ? Icons.add_circle_rounded : Icons.edit_rounded,
                color: AppColors.teal, size: 18),
              const SizedBox(width: 10),
              Text(
                widget.yeniMi ? 'Yeni Ürün Ekle' : 'Ürün Düzenle',
                style: GoogleFonts.outfit(
                  color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
              const Spacer(),
              if (!widget.yeniMi)
                IconButton(
                  onPressed: () => widget.onSil(widget.urun.id),
                  icon: Icon(Icons.delete_outline_rounded,
                    size: 18, color: AppColors.accentRed),
                  tooltip: 'Ürünü Kaldır',
                ),
              TextButton(
                onPressed: widget.onIptal,
                child: Text('İptal', style: TextStyle(color: c.textSecondary))),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _kaydediliyor ? null : _kaydet,
                icon: _kaydediliyor
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.save_rounded, size: 16),
                label: const Text('Kaydet'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: c.border),

        // Form alanları
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Wrap(
                spacing: 16, runSpacing: 16,
                children: [
                  // Ürün adı (tam genişlik)
                  _FormAlani(
                    genislik: double.infinity,
                    label: 'Ürün Adı *',
                    ctrl:  _adCtrl,
                    validator: (v) => v!.trim().isEmpty ? 'Ürün adı gerekli' : null,
                  ),

                  // Barkod + Üret butonu
                  _BarkodAlani(
                    ctrl:   _barkodCtrl,
                    hata:   _barkodHata,
                    onYeni: _yeniBarkod,
                    onDegis: (_) => setState(() => _barkodHata = null),
                  ),

                  _FormAlani(
                    label: 'Kategori',
                    ctrl:  _kategoriCtrl,
                    hint:  'örn. İçecek, Atıştırmalık...',
                  ),

                  _FormAlani(
                    label:    'Satış Fiyatı (₺) *',
                    ctrl:     _satisFiyatiCtrl,
                    hint:     '0.00',
                    sayisal:  true,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Fiyat gerekli';
                      final d = double.tryParse(v.replaceAll(',', '.'));
                      if (d == null || d < 0) return 'Geçerli fiyat girin';
                      return null;
                    },
                  ),

                  _FormAlani(
                    label:   'Alış Fiyatı (₺)',
                    ctrl:    _alisFiyatiCtrl,
                    hint:    '0.00',
                    sayisal: true,
                  ),

                  _FormAlani(
                    label:   'Stok',
                    ctrl:    _stokCtrl,
                    hint:    '0',
                    tam:     true,
                  ),

                  _FormAlani(
                    label:   'Kritik Stok Eşiği',
                    ctrl:    _kritikStokCtrl,
                    hint:    '5',
                    tam:     true,
                  ),

                  _FormAlani(
                    label: 'Birim',
                    ctrl:  _birimCtrl,
                    hint:  'adet, kg, lt, paket...',
                  ),

                  // Kâr önizlemesi
                  if (!widget.yeniMi) _KarOnizleme(urun: widget.urun),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FormAlani extends StatelessWidget {
  final String              label;
  final TextEditingController ctrl;
  final String?             hint;
  final bool                sayisal;
  final bool                tam;
  final double?             genislik;
  final String? Function(String?)? validator;

  const _FormAlani({
    required this.label,
    required this.ctrl,
    this.hint,
    this.sayisal  = false,
    this.tam      = false,
    this.genislik,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: genislik ?? 220,
      child: TextFormField(
        controller:     ctrl,
        validator:      validator,
        keyboardType:   tam      ? TextInputType.number
                      : sayisal ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.text,
        inputFormatters: tam ? [FilteringTextInputFormatter.digitsOnly] : null,
        style: GoogleFonts.outfit(fontSize: 13, color: c.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          hintText:  hint,
          labelStyle: GoogleFonts.outfit(fontSize: 12, color: c.textSecondary),
          hintStyle:  GoogleFonts.outfit(fontSize: 12, color: c.textMuted),
        ),
      ),
    );
  }
}

class _BarkodAlani extends StatelessWidget {
  final TextEditingController  ctrl;
  final String?                hata;
  final VoidCallback           onYeni;
  final ValueChanged<String>   onDegis;

  const _BarkodAlani({
    required this.ctrl, required this.hata,
    required this.onYeni, required this.onDegis,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: 280,
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: ctrl,
              onChanged:  onDegis,
              style: GoogleFonts.dmMono(fontSize: 13, color: c.textPrimary),
              decoration: InputDecoration(
                labelText: 'Barkod *',
                labelStyle: GoogleFonts.outfit(fontSize: 12, color: c.textSecondary),
                errorText: hata,
                prefixIcon: Icon(Icons.qr_code_rounded, size: 16, color: c.textSecondary),
              ),
              validator: (v) => v!.trim().isEmpty ? 'Barkod gerekli' : null,
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: 'Otomatik barkod üret (LQR)',
            child: IconButton(
              onPressed: onYeni,
              icon: Icon(Icons.refresh_rounded, color: AppColors.teal, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.teal.withAlpha(20),
                side: BorderSide(color: AppColors.teal.withAlpha(60)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KarOnizleme extends StatelessWidget {
  final ProductModel urun;
  const _KarOnizleme({required this.urun});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.bgTertiary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          _KarStat('Kâr Marjı', _fmtMoney.format(urun.karMarji),
            urun.karMarji >= 0 ? AppColors.accentGreen : AppColors.accentRed),
          const SizedBox(width: 24),
          _KarStat('Kâr Oranı', '%${urun.karOrani.toStringAsFixed(1)}',
            urun.karOrani >= 0 ? AppColors.accentGreen : AppColors.accentRed),
          const SizedBox(width: 24),
          _KarStat('Top. Satılan', '${urun.toplamSatilan} adet', AppColors.teal),
        ],
      ),
    );
  }
}

class _KarStat extends StatelessWidget {
  final String label, deger;
  final Color  renk;
  const _KarStat(this.label, this.deger, this.renk);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 10, color: c.textSecondary)),
        Text(deger,
          style: GoogleFonts.dmMono(
            fontSize: 14, fontWeight: FontWeight.w700, color: renk)),
      ],
    );
  }
}

// ── Boş hal ───────────────────────────────────────────────────────────────────

class _BosHal extends StatelessWidget {
  final VoidCallback onYeniUrun;
  final VoidCallback onImport;
  const _BosHal({required this.onYeniUrun, required this.onImport});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 56, color: c.textMuted),
          const SizedBox(height: 16),
          Text('Bir ürün seçin veya yeni ekleyin',
            style: GoogleFonts.outfit(fontSize: 15, color: c.textSecondary)),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: onYeniUrun,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Yeni Ürün'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal, foregroundColor: Colors.black),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.upload_file_rounded, size: 16),
                label: const Text('CSV\'den Toplu Aktar'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.gold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

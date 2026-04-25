import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_color_scheme.dart';
import '../../terminal/data/models/gider_model.dart';
import '../viewmodel/gider_viewmodel.dart';

final _fmtMoney = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
final _fmtDate  = DateFormat('dd.MM.yyyy HH:mm');

// ══════════════════════════════════════════════════════════════════════════════
// GIDER SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class GiderScreen extends StatefulWidget {
  const GiderScreen({super.key});

  @override
  State<GiderScreen> createState() => _GiderScreenState();
}

class _GiderScreenState extends State<GiderScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GiderViewModel>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Consumer<GiderViewModel>(
      builder: (_, vm, __) => Column(
        children: [
          _GiderHeader(vm: vm),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sol: gider listesi
                Expanded(flex: 3, child: _GiderList(vm: vm)),
                VerticalDivider(width: 1, color: c.border),
                // Sağ: özet paneli
                SizedBox(width: 260, child: _GiderOzetPanel(vm: vm)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _GiderHeader extends StatelessWidget {
  final GiderViewModel vm;
  const _GiderHeader({required this.vm});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: c.bgSecondary,
        border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gider Yönetimi',
                style: GoogleFonts.outfit(
                  color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                '${DateFormat('dd MMM', 'tr_TR').format(vm.baslangic)} – '
                '${DateFormat('dd MMM yyyy', 'tr_TR').format(vm.bitis)}',
                style: GoogleFonts.outfit(color: c.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(width: 16),

          // Ay seçici
          _AySecici(vm: vm),

          const Spacer(),

          // Yeni gider
          FilledButton.icon(
            onPressed: () => _showGiderDialog(context, vm),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
            label: Text('Gider Ekle',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _AySecici extends StatelessWidget {
  final GiderViewModel vm;
  const _AySecici({required this.vm});

  @override
  Widget build(BuildContext context) {
    final c   = context.colors;
    final now = DateTime.now();
    final aylar = List.generate(6, (i) {
      final d = DateTime(now.year, now.month - i, 1);
      return d;
    });

    return DropdownButton<DateTime>(
      value: DateTime(vm.baslangic.year, vm.baslangic.month, 1),
      dropdownColor: c.bgCard,
      underline: const SizedBox(),
      style: GoogleFonts.outfit(color: c.textPrimary, fontSize: 13),
      icon: Icon(Icons.keyboard_arrow_down_rounded,
        color: c.textSecondary, size: 20),
      items: aylar.map((d) => DropdownMenuItem(
        value: d,
        child: Text(DateFormat('MMMM yyyy', 'tr_TR').format(d)),
      )).toList(),
      onChanged: (d) {
        if (d != null) vm.setAylikGorunum(d.year, d.month);
      },
    );
  }
}

// ── Gider Listesi ─────────────────────────────────────────────────────────────

class _GiderList extends StatelessWidget {
  final GiderViewModel vm;
  const _GiderList({required this.vm});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (vm.loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.teal));
    }

    if (vm.giderler.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.money_off_rounded, size: 56, color: c.textSecondary),
            const SizedBox(height: 12),
            Text('Bu dönemde gider yok',
              style: GoogleFonts.outfit(color: c.textSecondary, fontSize: 14)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _showGiderDialog(context, vm),
              icon: const Icon(Icons.add_rounded, color: AppColors.teal, size: 18),
              label: Text('Gider Ekle', style: GoogleFonts.outfit(color: AppColors.teal)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Tablo başlığı
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          color: c.bgTertiary,
          child: const Row(
            children: [
              _HCol('Tarih',     flex: 2),
              _HCol('Kategori',  flex: 2),
              _HCol('Açıklama',  flex: 4),
              _HCol('Kasa',      flex: 2),
              _HCol('Tutar',     flex: 2, align: TextAlign.right),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: c.border),
            itemCount: vm.giderler.length,
            itemBuilder: (_, i) => _GiderRow(gider: vm.giderler[i]),
          ),
        ),
      ],
    );
  }
}

class _HCol extends StatelessWidget {
  final String label;
  final int flex;
  final TextAlign align;
  const _HCol(this.label, {this.flex = 1, this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      flex: flex,
      child: Text(label,
        textAlign: align,
        style: GoogleFonts.outfit(
          color: c.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        )),
    );
  }
}

class _GiderRow extends StatelessWidget {
  final GiderModel gider;
  const _GiderRow({required this.gider});

  static const _kasaLabels = {
    'nakit': 'Nakit Kasa',
    'banka': 'Banka Hesabı',
    'pos':   'POS Cihazı',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(_fmtDate.format(gider.tarih),
            style: GoogleFonts.dmMono(color: c.textSecondary, fontSize: 11))),
          Expanded(flex: 2, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _kategoriColor(gider.kategori, c).withAlpha(25),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(gider.kategoriLabel,
              style: GoogleFonts.outfit(
                color: _kategoriColor(gider.kategori, c),
                fontSize: 11, fontWeight: FontWeight.w600)),
          )),
          Expanded(flex: 4, child: Text(
            gider.aciklama ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(color: c.textSecondary, fontSize: 12))),
          Expanded(flex: 2, child: Text(
            _kasaLabels[gider.kasaId] ?? gider.kasaId,
            style: GoogleFonts.outfit(color: c.textMuted, fontSize: 12))),
          Expanded(flex: 2, child: Text(
            _fmtMoney.format(gider.tutar),
            textAlign: TextAlign.right,
            style: GoogleFonts.dmMono(
              color: AppColors.accentRed,
              fontWeight: FontWeight.w700, fontSize: 13))),
        ],
      ),
    );
  }

  Color _kategoriColor(GiderKategori k, AppColorScheme c) => switch (k) {
    GiderKategori.kira      => AppColors.gold,
    GiderKategori.fatura    => const Color(0xFF6CB4E4),
    GiderKategori.personel  => const Color(0xFFB784A7),
    GiderKategori.malzeme   => const Color(0xFF7EC8A4),
    GiderKategori.bakim     => const Color(0xFFFF8C42),
    GiderKategori.diger     => c.textSecondary,
  };
}

// ── Özet Paneli ───────────────────────────────────────────────────────────────

class _GiderOzetPanel extends StatelessWidget {
  final GiderViewModel vm;
  const _GiderOzetPanel({required this.vm});

  @override
  Widget build(BuildContext context) {
    final c    = context.colors;
    final ozet = vm.kategoriOzeti;

    return Container(
      color: c.bgSecondary,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dönem Özeti',
            style: GoogleFonts.outfit(
              color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),

          // Toplam
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentRed.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accentRed.withAlpha(40)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Toplam Gider',
                  style: GoogleFonts.outfit(
                    color: c.textSecondary, fontSize: 12)),
                Text(_fmtMoney.format(vm.toplamGider),
                  style: GoogleFonts.dmMono(
                    color: AppColors.accentRed,
                    fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text('Kategorilere Göre',
            style: GoogleFonts.outfit(
              color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),

          ...ozet.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _KategoriBar(
              label:   _kategoriLabel(e.key),
              tutar:   e.value,
              toplam:  vm.toplamGider,
              color:   _kategoriColor(e.key, c),
            ),
          )),
        ],
      ),
    );
  }

  String _kategoriLabel(GiderKategori k) => switch (k) {
    GiderKategori.kira      => 'Kira',
    GiderKategori.fatura    => 'Fatura',
    GiderKategori.personel  => 'Personel',
    GiderKategori.malzeme   => 'Malzeme',
    GiderKategori.bakim     => 'Bakım/Tamir',
    GiderKategori.diger     => 'Diğer',
  };

  Color _kategoriColor(GiderKategori k, AppColorScheme c) => switch (k) {
    GiderKategori.kira      => AppColors.gold,
    GiderKategori.fatura    => const Color(0xFF6CB4E4),
    GiderKategori.personel  => const Color(0xFFB784A7),
    GiderKategori.malzeme   => const Color(0xFF7EC8A4),
    GiderKategori.bakim     => const Color(0xFFFF8C42),
    GiderKategori.diger     => c.textSecondary,
  };
}

class _KategoriBar extends StatelessWidget {
  final String label;
  final double tutar;
  final double toplam;
  final Color  color;
  const _KategoriBar({
    required this.label, required this.tutar,
    required this.toplam, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c    = context.colors;
    final oran = toplam > 0 ? (tutar / toplam).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
              style: GoogleFonts.outfit(color: c.textSecondary, fontSize: 11)),
            Text(_fmtMoney.format(tutar),
              style: GoogleFonts.dmMono(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: oran,
            minHeight: 6,
            backgroundColor: color.withAlpha(20),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ── Yeni Gider Dialogu ────────────────────────────────────────────────────────

void _showGiderDialog(BuildContext context, GiderViewModel vm) {
  showDialog(
    context: context,
    builder: (_) => _GiderFormDialog(vm: vm),
  );
}

class _GiderFormDialog extends StatefulWidget {
  final GiderViewModel vm;
  const _GiderFormDialog({required this.vm});

  @override
  State<_GiderFormDialog> createState() => _GiderFormDialogState();
}

class _GiderFormDialogState extends State<_GiderFormDialog> {
  final _tutarCtrl   = TextEditingController();
  final _aciklamaCtrl= TextEditingController();
  GiderKategori _kategori = GiderKategori.diger;
  String        _kasaId   = 'nakit';
  bool          _saving   = false;

  @override
  void dispose() {
    _tutarCtrl.dispose();
    _aciklamaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      backgroundColor: c.bgCard,
      title: Text('Gider Ekle',
        style: GoogleFonts.outfit(
          color: c.textPrimary, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Kategori
            DropdownButtonFormField<GiderKategori>(
              value: _kategori,
              dropdownColor: c.bgCard,
              decoration: InputDecoration(
                labelText: 'Kategori',
                labelStyle: GoogleFonts.outfit(color: c.textSecondary),
              ),
              items: GiderKategori.values.map((k) => DropdownMenuItem(
                value: k,
                child: Text(_kategoriLabel(k),
                  style: GoogleFonts.outfit(color: c.textPrimary)),
              )).toList(),
              onChanged: (v) => setState(() => _kategori = v ?? GiderKategori.diger),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tutarCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.dmMono(color: c.textPrimary, fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Tutar (₺) *',
                labelStyle: GoogleFonts.outfit(color: c.textSecondary),
                prefixIcon: const Icon(Icons.currency_lira_rounded, color: AppColors.accentRed),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _kasaId,
              dropdownColor: c.bgCard,
              decoration: InputDecoration(
                labelText: 'Ödeyen Kasa',
                labelStyle: GoogleFonts.outfit(color: c.textSecondary),
              ),
              items: widget.vm.kasalar.map((k) => DropdownMenuItem(
                value: k.id,
                child: Text(k.ad, style: GoogleFonts.outfit(color: c.textPrimary)),
              )).toList(),
              onChanged: (v) => setState(() => _kasaId = v ?? 'nakit'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _aciklamaCtrl,
              style: GoogleFonts.outfit(color: c.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Açıklama (opsiyonel)',
                labelStyle: GoogleFonts.outfit(color: c.textSecondary),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('İptal', style: TextStyle(color: c.textSecondary)),
        ),
        FilledButton(
          onPressed: _saving ? null : _kaydet,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accentRed, foregroundColor: Colors.white),
          child: Text(_saving ? 'Kaydediliyor...' : 'Kaydet',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Future<void> _kaydet() async {
    final tutar = double.tryParse(_tutarCtrl.text.replaceAll(',', '.'));
    if (tutar == null || tutar <= 0) return;
    setState(() => _saving = true);
    final ok = await widget.vm.giderEkle(
      kategori: _kategori,
      tutar:    tutar,
      kasaId:   _kasaId,
      aciklama: _aciklamaCtrl.text.trim().isEmpty ? null : _aciklamaCtrl.text.trim(),
    );
    if (ok && mounted) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
    }
  }

  String _kategoriLabel(GiderKategori k) => switch (k) {
    GiderKategori.kira      => 'Kira',
    GiderKategori.fatura    => 'Fatura / Elektrik / Su',
    GiderKategori.personel  => 'Personel Maaşı',
    GiderKategori.malzeme   => 'Malzeme / Sarf',
    GiderKategori.bakim     => 'Bakım / Tamir',
    GiderKategori.diger     => 'Diğer',
  };
}

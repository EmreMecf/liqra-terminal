import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../terminal/data/models/cari_hareket_model.dart';
import '../../terminal/data/models/cari_model.dart';
import '../viewmodel/cari_viewmodel.dart';

final _fmtMoney = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
final _fmtDate  = DateFormat('dd.MM.yyyy HH:mm');

// ══════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class CariScreen extends StatefulWidget {
  const CariScreen({super.key});

  @override
  State<CariScreen> createState() => _CariScreenState();
}

class _CariScreenState extends State<CariScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CariViewModel>().init();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CariViewModel>(
      builder: (context, vm, _) {
        // Cari seçiliyse ekstre panelini göster
        if (vm.secilenCari != null) {
          return _EkstrePanel(vm: vm);
        }

        return Column(
          children: [
            _CariHeader(vm: vm),
            _CariTabs(tabCtrl: _tabCtrl),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _CariList(vm: vm, tip: CariTip.musteri),
                  _CariList(vm: vm, tip: CariTip.tedarikci),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _CariHeader extends StatelessWidget {
  final CariViewModel vm;
  const _CariHeader({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(
        color: AppColors.bgSecondary,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cari Yönetimi',
                style: GoogleFonts.outfit(
                  color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Row(children: [
                _HeaderStat('Toplam Alacak', vm.toplamAlacak, AppColors.accentGreen),
                const SizedBox(width: 20),
                _HeaderStat('Toplam Borç', vm.toplamBorc, AppColors.accentRed),
              ]),
            ],
          ),
          const Spacer(),
          // Arama
          SizedBox(
            width: 260,
            height: 38,
            child: TextField(
              style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'İsim, telefon veya VKN ara...',
                hintStyle: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: vm.setSearch,
            ),
          ),
          const SizedBox(width: 12),
          // Yeni cari butonu
          FilledButton.icon(
            onPressed: () => _showCariDialog(context, vm),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: Text('Yeni Cari', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final double value;
  final Color  color;
  const _HeaderStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 10)),
        Text(_fmtMoney.format(value),
          style: GoogleFonts.dmMono(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ── Tabs ──────────────────────────────────────────────────────────────────────

class _CariTabs extends StatelessWidget {
  final TabController tabCtrl;
  const _CariTabs({required this.tabCtrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgSecondary,
      child: TabBar(
        controller: tabCtrl,
        indicatorColor: AppColors.teal,
        labelColor: AppColors.teal,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: const [
          Tab(text: 'Müşteriler'),
          Tab(text: 'Tedarikçiler'),
        ],
      ),
    );
  }
}

// ── Cari Listesi ──────────────────────────────────────────────────────────────

class _CariList extends StatelessWidget {
  final CariViewModel vm;
  final CariTip       tip;
  const _CariList({required this.vm, required this.tip});

  @override
  Widget build(BuildContext context) {
    // tip filtresi uygula
    final list = vm.cariler.where((c) => c.tip == tip || c.tip == CariTip.ikisi).toList();

    if (vm.state == CariViewState.loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.teal));
    }

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline_rounded, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text('Kayıt bulunamadı',
              style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _showCariDialog(context, vm, defaultTip: tip),
              icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.teal),
              label: Text('Yeni Ekle', style: GoogleFonts.outfit(color: AppColors.teal)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: list.length,
      itemBuilder: (_, i) => _CariCard(cari: list[i], vm: vm),
    );
  }
}

class _CariCard extends StatefulWidget {
  final CariModel     cari;
  final CariViewModel vm;
  const _CariCard({required this.cari, required this.vm});

  @override
  State<_CariCard> createState() => _CariCardState();
}

class _CariCardState extends State<_CariCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.cari;
    final isAlacak = c.bakiye > 0;
    final isBorc   = c.bakiye < 0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _hover ? AppColors.bgTertiary : AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hover ? AppColors.teal.withAlpha(60) : AppColors.border),
        ),
        child: InkWell(
          onTap: () => widget.vm.cariSec(c),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.teal.withAlpha(30),
                  child: Text(
                    c.ad.isNotEmpty ? c.ad[0].toUpperCase() : '?',
                    style: GoogleFonts.outfit(
                      color: AppColors.teal, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 14),

                // Bilgiler
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.ad,
                        style: GoogleFonts.outfit(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        )),
                      if (c.telefon != null) ...[
                        const SizedBox(height: 2),
                        Text(c.telefon!,
                          style: GoogleFonts.outfit(
                            color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ],
                  ),
                ),

                // Bakiye
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (c.bakiye != 0) ...[
                      Text(
                        isAlacak ? 'Alacak' : 'Borç',
                        style: GoogleFonts.outfit(
                          color: isAlacak ? AppColors.accentGreen : AppColors.accentRed,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _fmtMoney.format(c.bakiye.abs()),
                        style: GoogleFonts.dmMono(
                          color: isAlacak ? AppColors.accentGreen : AppColors.accentRed,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ] else
                      Text('Bakiye yok',
                        style: GoogleFonts.outfit(
                          color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),

                const SizedBox(width: 12),

                // İşlem butonları
                if (isAlacak)
                  Tooltip(
                    message: 'Tahsilat Yap',
                    child: IconButton(
                      icon: const Icon(Icons.payment_rounded, size: 20, color: AppColors.accentGreen),
                      onPressed: () => _showTahsilatDialog(context, c, widget.vm),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  )
                else if (isBorc)
                  Tooltip(
                    message: 'Ödeme Yap',
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, size: 20, color: AppColors.accentRed),
                      onPressed: () => _showTahsilatDialog(context, c, widget.vm, isOdeme: true),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ),

                Tooltip(
                  message: 'Ekstre',
                  child: IconButton(
                    icon: const Icon(Icons.receipt_long_rounded, size: 20, color: AppColors.textSecondary),
                    onPressed: () => widget.vm.cariSec(c),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EKSTRE PANELİ
// ══════════════════════════════════════════════════════════════════════════════

class _EkstrePanel extends StatelessWidget {
  final CariViewModel vm;
  const _EkstrePanel({required this.vm});

  @override
  Widget build(BuildContext context) {
    final cari = vm.secilenCari!;

    return Column(
      children: [
        // Başlık
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: AppColors.bgSecondary,
            border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary),
                onPressed: vm.ekstreSifirla,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.teal.withAlpha(30),
                child: Text(
                  cari.ad[0].toUpperCase(),
                  style: GoogleFonts.outfit(color: AppColors.teal, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cari.ad,
                      style: GoogleFonts.outfit(
                        color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                    if (cari.telefon != null)
                      Text(cari.telefon!,
                        style: GoogleFonts.outfit(
                          color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              // Güncel bakiye
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    cari.bakiye >= 0 ? 'Alacak Bakiyesi' : 'Borç Bakiyesi',
                    style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 11),
                  ),
                  Text(
                    _fmtMoney.format(cari.bakiye.abs()),
                    style: GoogleFonts.dmMono(
                      color: cari.bakiye >= 0 ? AppColors.accentGreen : AppColors.accentRed,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              if (cari.bakiye > 0)
                FilledButton.icon(
                  onPressed: () => _showTahsilatDialog(context, cari, vm),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(Icons.payment_rounded, size: 16),
                  label: Text('Tahsilat',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
            ],
          ),
        ),

        // Ekstre başlığı
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          color: AppColors.bgTertiary,
          child: Row(
            children: [
              _ExCol('Tarih',    flex: 2),
              _ExCol('Tür',      flex: 2),
              _ExCol('Belge No', flex: 2),
              _ExCol('Açıklama', flex: 3),
              _ExCol('Tutar',    flex: 2, align: TextAlign.right),
              _ExCol('Bakiye',   flex: 2, align: TextAlign.right),
            ],
          ),
        ),

        // Hareketler
        Expanded(
          child: vm.ekstreLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
              : vm.ekstre.isEmpty
                  ? Center(
                      child: Text('Henüz hareket yok',
                        style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 14)))
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.border),
                      itemCount: vm.ekstre.length,
                      itemBuilder: (_, i) => _ExstreRow(hareket: vm.ekstre[i]),
                    ),
        ),
      ],
    );
  }
}

class _ExCol extends StatelessWidget {
  final String    label;
  final int       flex;
  final TextAlign align;
  const _ExCol(this.label, {this.flex = 1, this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(label,
        textAlign: align,
        style: GoogleFonts.outfit(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        )),
    );
  }
}

class _ExstreRow extends StatelessWidget {
  final CariHareket hareket;
  const _ExstreRow({required this.hareket});

  @override
  Widget build(BuildContext context) {
    final isBorcMu = hareket.tutar > 0;
    final tipLabel = switch (hareket.tip) {
      CariHareketTip.satis           => 'Satış',
      CariHareketTip.tahsilat        => 'Tahsilat',
      CariHareketTip.alis            => 'Alım',
      CariHareketTip.tedarikciOdeme  => 'Ödeme',
      CariHareketTip.iade            => 'İade',
      CariHareketTip.duzeltme        => 'Düzeltme',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(_fmtDate.format(hareket.tarih),
            style: GoogleFonts.dmMono(color: AppColors.textSecondary, fontSize: 11))),
          Expanded(flex: 2, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isBorcMu ? AppColors.accentRed.withAlpha(20) : AppColors.accentGreen.withAlpha(20),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(tipLabel,
              style: GoogleFonts.outfit(
                color: isBorcMu ? AppColors.accentRed : AppColors.accentGreen,
                fontSize: 11, fontWeight: FontWeight.w600)),
          )),
          Expanded(flex: 2, child: Text(hareket.belgeNo ?? '—',
            style: GoogleFonts.dmMono(color: AppColors.textMuted, fontSize: 11))),
          Expanded(flex: 3, child: Text(hareket.aciklama ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12))),
          Expanded(flex: 2, child: Text(
            _fmtMoney.format(hareket.tutar.abs()),
            textAlign: TextAlign.right,
            style: GoogleFonts.dmMono(
              color: isBorcMu ? AppColors.accentRed : AppColors.accentGreen,
              fontWeight: FontWeight.w600, fontSize: 12))),
          Expanded(flex: 2, child: Text(
            _fmtMoney.format(hareket.bakiye),
            textAlign: TextAlign.right,
            style: GoogleFonts.dmMono(
              color: hareket.bakiye >= 0 ? AppColors.accentGreen : AppColors.accentRed,
              fontWeight: FontWeight.w600, fontSize: 12))),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DİALOGLAR
// ══════════════════════════════════════════════════════════════════════════════

// ── Yeni / Düzenle Cari ───────────────────────────────────────────────────────

void _showCariDialog(BuildContext context, CariViewModel vm,
    {CariTip defaultTip = CariTip.musteri, CariModel? existing}) {
  showDialog(
    context: context,
    builder: (_) => _CariFormDialog(vm: vm, defaultTip: defaultTip, existing: existing),
  );
}

class _CariFormDialog extends StatefulWidget {
  final CariViewModel vm;
  final CariTip       defaultTip;
  final CariModel?    existing;
  const _CariFormDialog({required this.vm, required this.defaultTip, this.existing});

  @override
  State<_CariFormDialog> createState() => _CariFormDialogState();
}

class _CariFormDialogState extends State<_CariFormDialog> {
  late final _adCtrl    = TextEditingController(text: widget.existing?.ad      ?? '');
  late final _telCtrl   = TextEditingController(text: widget.existing?.telefon ?? '');
  late final _epostaCtrl= TextEditingController(text: widget.existing?.eposta  ?? '');
  late final _adresCtrl = TextEditingController(text: widget.existing?.adres   ?? '');
  late final _vkCtrl    = TextEditingController(text: widget.existing?.vergiNo ?? '');
  late CariTip _tip = widget.existing?.tip ?? widget.defaultTip;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_adCtrl, _telCtrl, _epostaCtrl, _adresCtrl, _vkCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      title: Text(widget.existing == null ? 'Yeni Cari' : 'Cari Düzenle',
        style: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tip seçimi
              Row(
                children: CariTip.values.map((t) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_tipLabel(t), style: GoogleFonts.outfit(fontSize: 12)),
                    selected: _tip == t,
                    onSelected: (_) => setState(() => _tip = t),
                    selectedColor: AppColors.teal.withAlpha(40),
                    labelStyle: GoogleFonts.outfit(
                      color: _tip == t ? AppColors.teal : AppColors.textSecondary),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 12),
              _DialogField('Ad / Unvan *', _adCtrl, autofocus: true),
              _DialogField('Telefon', _telCtrl),
              _DialogField('E-posta', _epostaCtrl),
              _DialogField('Adres', _adresCtrl),
              _DialogField('Vergi / TC Kimlik No', _vkCtrl),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal', style: TextStyle(color: AppColors.textSecondary)),
        ),
        FilledButton(
          onPressed: _saving || _adCtrl.text.trim().isEmpty ? null : _kaydet,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.teal, foregroundColor: Colors.black87),
          child: Text(_saving ? 'Kaydediliyor...' : 'Kaydet',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Future<void> _kaydet() async {
    setState(() => _saving = true);
    if (widget.existing == null) {
      await widget.vm.cariEkle(
        ad:    _adCtrl.text.trim(),
        tip:   _tip,
        telefon:  _telCtrl.text.trim().isEmpty ? null : _telCtrl.text.trim(),
        eposta:   _epostaCtrl.text.trim().isEmpty ? null : _epostaCtrl.text.trim(),
        adres:    _adresCtrl.text.trim().isEmpty ? null : _adresCtrl.text.trim(),
        vergiNo:  _vkCtrl.text.trim().isEmpty ? null : _vkCtrl.text.trim(),
      );
    } else {
      await widget.vm.cariGuncelle(widget.existing!);
    }
    if (mounted) Navigator.pop(context);
  }

  String _tipLabel(CariTip t) => switch (t) {
    CariTip.musteri    => 'Müşteri',
    CariTip.tedarikci  => 'Tedarikçi',
    CariTip.ikisi      => 'Her İkisi',
  };
}

class _DialogField extends StatelessWidget {
  final String              label;
  final TextEditingController ctrl;
  final bool                autofocus;
  const _DialogField(this.label, this.ctrl, {this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        autofocus: autofocus,
        style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12),
        ),
      ),
    );
  }
}

// ── Tahsilat ──────────────────────────────────────────────────────────────────

void _showTahsilatDialog(
  BuildContext context,
  CariModel cari,
  CariViewModel vm, {
  bool isOdeme = false,
}) {
  showDialog(
    context: context,
    builder: (_) => _TahsilatDialog(cari: cari, vm: vm, isOdeme: isOdeme),
  );
}

class _TahsilatDialog extends StatefulWidget {
  final CariModel     cari;
  final CariViewModel vm;
  final bool          isOdeme;
  const _TahsilatDialog({required this.cari, required this.vm, required this.isOdeme});

  @override
  State<_TahsilatDialog> createState() => _TahsilatDialogState();
}

class _TahsilatDialogState extends State<_TahsilatDialog> {
  final _tutarCtrl   = TextEditingController();
  final _aciklamaCtrl= TextEditingController();
  String _kasaId     = 'nakit';
  bool   _saving     = false;

  @override
  void dispose() {
    _tutarCtrl.dispose();
    _aciklamaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm    = widget.vm;
    final cari  = widget.cari;
    final title = widget.isOdeme ? 'Tedarikçi Ödemesi' : 'Tahsilat Yap';

    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
            style: GoogleFonts.outfit(
              color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(cari.ad,
            style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13)),
          Text(
            '${widget.isOdeme ? "Borç Bakiyesi" : "Alacak Bakiyesi"}: ${_fmtMoney.format(cari.bakiye.abs())}',
            style: GoogleFonts.dmMono(
              color: widget.isOdeme ? AppColors.accentRed : AppColors.accentGreen,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _tutarCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.dmMono(color: AppColors.textPrimary, fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Tutar (₺)',
                labelStyle: GoogleFonts.outfit(color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.currency_lira_rounded, color: AppColors.teal),
              ),
            ),
            const SizedBox(height: 10),
            // Kasa seçimi
            DropdownButtonFormField<String>(
              value: _kasaId,
              dropdownColor: AppColors.bgCard,
              decoration: InputDecoration(
                labelText: 'Kasa',
                labelStyle: GoogleFonts.outfit(color: AppColors.textSecondary),
              ),
              items: vm.kasalar.map((k) => DropdownMenuItem(
                value: k.id,
                child: Text(k.ad,
                  style: GoogleFonts.outfit(color: AppColors.textPrimary)),
              )).toList(),
              onChanged: (v) => setState(() => _kasaId = v ?? 'nakit'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _aciklamaCtrl,
              style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Açıklama (opsiyonel)',
                labelStyle: GoogleFonts.outfit(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal', style: TextStyle(color: AppColors.textSecondary)),
        ),
        FilledButton(
          onPressed: _saving ? null : _kaydet,
          style: FilledButton.styleFrom(
            backgroundColor: widget.isOdeme ? AppColors.accentRed : AppColors.accentGreen,
            foregroundColor: Colors.white,
          ),
          child: Text(_saving ? 'İşleniyor...' : title,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Future<void> _kaydet() async {
    final tutar = double.tryParse(_tutarCtrl.text.replaceAll(',', '.'));
    if (tutar == null || tutar <= 0) return;

    setState(() => _saving = true);
    if (widget.isOdeme) {
      await widget.vm.tedarikciOdemesiKaydet(
        cariId:   widget.cari.id,
        tutar:    tutar,
        kasaId:   _kasaId,
        aciklama: _aciklamaCtrl.text.trim().isEmpty ? null : _aciklamaCtrl.text.trim(),
      );
    } else {
      await widget.vm.tahsilatKaydet(
        cariId:   widget.cari.id,
        tutar:    tutar,
        kasaId:   _kasaId,
        aciklama: _aciklamaCtrl.text.trim().isEmpty ? null : _aciklamaCtrl.text.trim(),
      );
    }
    if (mounted) Navigator.pop(context);
  }
}

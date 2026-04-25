import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_color_scheme.dart';
import '../viewmodel/rapor_viewmodel.dart';

// ── Formatlayıcılar ───────────────────────────────────────────────────────────
final _fmtMoney = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
final _fmtMoneyK = NumberFormat.compact(locale: 'tr_TR');
final _fmtDate  = DateFormat('dd MMM yyyy', 'tr_TR');
final _fmtTime  = DateFormat('HH:mm', 'tr_TR');

// ══════════════════════════════════════════════════════════════════════════════
// RAPOR SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class RaporScreen extends StatefulWidget {
  const RaporScreen({super.key});

  @override
  State<RaporScreen> createState() => _RaporScreenState();
}

class _RaporScreenState extends State<RaporScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RaporViewModel>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c  = context.colors;
    final vm = context.watch<RaporViewModel>();

    return Scaffold(
      backgroundColor: c.bgPrimary,
      body: Column(
        children: [
          // ── Başlık + dönem seçici ──────────────────────────────────────
          _Header(vm: vm),
          Divider(height: 1, color: c.border),

          // ── İçerik ────────────────────────────────────────────────────
          Expanded(
            child: vm.loading
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.teal, strokeWidth: 2))
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sol: satış listesi
                      SizedBox(
                        width: 420,
                        child: _SatisList(vm: vm),
                      ),
                      VerticalDivider(width: 1, color: c.border),
                      // Sağ: detay veya özet
                      Expanded(
                        child: vm.secilenSatis != null
                            ? _FisDetay(
                                satis: vm.secilenSatis!,
                                onKapat: () => vm.satisSec(null),
                              )
                            : _OzetPanel(vm: vm),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Başlık + dönem seçici ─────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final RaporViewModel vm;
  const _Header({required this.vm});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      color: c.bgSecondary,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.bar_chart_rounded, color: AppColors.teal, size: 20),
          const SizedBox(width: 10),
          Text('Satış Raporları',
            style: GoogleFonts.outfit(
              color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(width: 24),

          // Dönem filtreleri
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: RaporDonem.values.map((d) {
                  final sel = vm.donem == d;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _DonemChip(
                      label: d.label,
                      selected: sel,
                      onTap: d == RaporDonem.ozel
                          ? () => _ozelAralikSec(context, vm)
                          : () => vm.donemDegistir(d),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Yenile
          IconButton(
            onPressed: vm.yenile,
            icon: Icon(Icons.refresh_rounded, color: c.textSecondary, size: 18),
            tooltip: 'Yenile',
          ),
        ],
      ),
    );
  }

  Future<void> _ozelAralikSec(BuildContext context, RaporViewModel vm) async {
    final now   = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate:   DateTime(now.year - 2),
      lastDate:    now,
      initialDateRange: vm.ozelBaslangic != null
          ? DateTimeRange(start: vm.ozelBaslangic!, end: vm.ozelBitis ?? now)
          : DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
      locale: const Locale('tr', 'TR'),
    );
    if (range != null) {
      vm.ozelAralikAyarla(range.start, range.end);
    }
  }
}

class _DonemChip extends StatelessWidget {
  final String label;
  final bool   selected;
  final VoidCallback onTap;
  const _DonemChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal.withAlpha(28) : c.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.teal.withAlpha(120) : c.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color:      selected ? AppColors.teal : c.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ── Satış Listesi (sol panel) ─────────────────────────────────────────────────

class _SatisList extends StatelessWidget {
  final RaporViewModel vm;
  const _SatisList({required this.vm});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (vm.satislar.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: c.textMuted),
            const SizedBox(height: 12),
            Text('Bu dönemde satış yok',
              style: GoogleFonts.outfit(color: c.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    // Gruplama — aynı tarih_key alanına göre
    final groups = <String, List<SaleModel>>{};
    for (final s in vm.satislar) {
      groups.putIfAbsent(s.tarihKey, () => []).add(s);
    }
    final gunler = groups.keys.toList();

    return Column(
      children: [
        // Mini KPI çubuğu
        _ListKpiBar(vm: vm),
        Divider(height: 1, color: c.border),

        Expanded(
          child: ListView.builder(
            itemCount: gunler.length,
            padding: const EdgeInsets.only(bottom: 16),
            itemBuilder: (context, gi) {
              final gun    = gunler[gi];
              final satislar = groups[gun]!;
              final gunToplam = satislar.fold(0.0, (s, e) => s + e.toplam);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gün başlığı
                  Container(
                    color: c.bgTertiary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          _fmtDate.format(DateTime.parse(gun)),
                          style: GoogleFonts.outfit(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: c.textSecondary),
                        ),
                        const Spacer(),
                        Text(
                          '${satislar.length} satış · ${_fmtMoney.format(gunToplam)}',
                          style: GoogleFonts.dmMono(
                            fontSize: 11, color: AppColors.teal),
                        ),
                      ],
                    ),
                  ),

                  // Satış satırları
                  ...satislar.map((s) => _SatisRow(
                    satis:    s,
                    selected: vm.secilenSatis?.id == s.id,
                    onTap:    () => vm.satisSec(
                      vm.secilenSatis?.id == s.id ? null : s),
                  )),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ListKpiBar extends StatelessWidget {
  final RaporViewModel vm;
  const _ListKpiBar({required this.vm});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: c.bgSecondary,
      child: Row(
        children: [
          _MiniKpi(label: 'Satış', value: '${vm.satisSayisi}', icon: Icons.shopping_cart_rounded),
          _vDivider(c),
          _MiniKpi(label: 'Ciro', value: _fmtMoney.format(vm.toplamCiro), icon: Icons.payments_rounded),
          _vDivider(c),
          _MiniKpi(label: 'Ort.Sepet', value: _fmtMoney.format(vm.ortalamaSepet), icon: Icons.calculate_rounded),
        ],
      ),
    );
  }

  Widget _vDivider(AppColorScheme c) =>
      Container(width: 1, height: 28, color: c.border, margin: const EdgeInsets.symmetric(horizontal: 12));
}

class _MiniKpi extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData icon;
  const _MiniKpi({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.teal),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.outfit(fontSize: 9, color: c.textSecondary)),
                Text(value, style: GoogleFonts.dmMono(
                  fontSize: 12, color: c.textPrimary, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SatisRow extends StatelessWidget {
  final SaleModel satis;
  final bool      selected;
  final VoidCallback onTap;
  const _SatisRow({required this.satis, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: selected ? AppColors.teal.withAlpha(18) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Ödeme tipi ikonu
            _OdemeBadge(tip: satis.odemeTip),
            const SizedBox(width: 10),

            // Saat + cari adı
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _fmtTime.format(satis.tarih),
                        style: GoogleFonts.dmMono(
                          fontSize: 12, fontWeight: FontWeight.w600, color: c.textPrimary),
                      ),
                      if (satis.cariAdi != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            satis.cariAdi!,
                            style: GoogleFonts.outfit(fontSize: 11, color: c.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '${satis.kalemSayisi} ürün',
                    style: GoogleFonts.outfit(fontSize: 10, color: c.textMuted),
                  ),
                ],
              ),
            ),

            // Tutar
            Text(
              _fmtMoney.format(satis.toplam),
              style: GoogleFonts.dmMono(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: satis.veresiyeMi ? AppColors.gold : c.textPrimary),
            ),

            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
              size: 16, color: selected ? AppColors.teal : c.textMuted),
          ],
        ),
      ),
    );
  }
}

class _OdemeBadge extends StatelessWidget {
  final OdemeTip tip;
  const _OdemeBadge({required this.tip});

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (tip) {
      OdemeTip.nakit       => (Icons.payments_rounded,      AppColors.accentGreen, 'NAKİT'),
      OdemeTip.krediKarti  => (Icons.credit_card_rounded,   AppColors.teal,        'KART'),
      OdemeTip.veresiye    => (Icons.account_balance_wallet_rounded, AppColors.gold, 'VER.'),
    };
    return Container(
      width: 52, height: 36,
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: color),
          Text(label, style: GoogleFonts.outfit(fontSize: 7, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Fiş Detayı (sağ panel, seçili satış) ─────────────────────────────────────

class _FisDetay extends StatelessWidget {
  final SaleModel    satis;
  final VoidCallback onKapat;
  const _FisDetay({required this.satis, required this.onKapat});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      children: [
        // Fiş başlığı
        Container(
          color: c.bgSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.receipt_rounded, color: AppColors.teal, size: 18),
              const SizedBox(width: 10),
              Text('Satış Detayı',
                style: GoogleFonts.outfit(
                  color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
              const Spacer(),
              // Ödeme tipi
              _OdemeBadge(tip: satis.odemeTip),
              const SizedBox(width: 12),
              IconButton(
                onPressed: onKapat,
                icon: Icon(Icons.close_rounded, size: 18, color: c.textSecondary),
                tooltip: 'Kapat',
              ),
            ],
          ),
        ),
        Divider(height: 1, color: c.border),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tarih / ID
                _FisSatir(label: 'Tarih',
                  value: DateFormat('dd MMM yyyy HH:mm', 'tr_TR').format(satis.tarih)),
                _FisSatir(label: 'Satış No',
                  value: satis.id.substring(0, 8).toUpperCase(),
                  mono: true),
                if (satis.cariAdi != null)
                  _FisSatir(label: 'Cari', value: satis.cariAdi!),
                const SizedBox(height: 16),

                // Ürün tablosu başlığı
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: c.bgTertiary,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text('Ürün',
                        style: GoogleFonts.outfit(
                          fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w600))),
                      SizedBox(width: 48,
                        child: Text('Adet',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(fontSize: 11, color: c.textSecondary))),
                      SizedBox(width: 80,
                        child: Text('Tutar',
                          textAlign: TextAlign.right,
                          style: GoogleFonts.outfit(fontSize: 11, color: c.textSecondary))),
                    ],
                  ),
                ),

                // Kalemler
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: c.border),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                  ),
                  child: Column(
                    children: satis.kalemler.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final k   = entry.value;
                      final isLast = idx == satis.kalemler.length - 1;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: isLast ? null : Border(
                            bottom: BorderSide(color: c.border, width: 0.5)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(k.urunAdi,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13, color: c.textPrimary,
                                      fontWeight: FontWeight.w500)),
                                  if (k.indirim > 0)
                                    Text('İndirim: %${(k.indirim * 100).toStringAsFixed(0)}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 10, color: AppColors.accentRed)),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 48,
                              child: Text('${k.miktar}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.dmMono(
                                  fontSize: 13, color: c.textSecondary)),
                            ),
                            SizedBox(
                              width: 80,
                              child: Text(_fmtMoney.format(k.toplamFiyat),
                                textAlign: TextAlign.right,
                                style: GoogleFonts.dmMono(
                                  fontSize: 13, color: c.textPrimary,
                                  fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 16),

                // Toplam
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.teal.withAlpha(50)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Brüt Kâr',
                            style: GoogleFonts.outfit(color: c.textSecondary, fontSize: 12)),
                          Text(_fmtMoney.format(satis.karToplami),
                            style: GoogleFonts.dmMono(
                              color: AppColors.accentGreen, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('TOPLAM',
                            style: GoogleFonts.outfit(
                              color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                          Text(_fmtMoney.format(satis.toplam),
                            style: GoogleFonts.dmMono(
                              color: AppColors.teal, fontSize: 16, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FisSatir extends StatelessWidget {
  final String label;
  final String value;
  final bool   mono;
  const _FisSatir({required this.label, required this.value, this.mono = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: GoogleFonts.outfit(fontSize: 12, color: c.textSecondary))),
          Text(value,
            style: mono
                ? GoogleFonts.dmMono(fontSize: 12, color: c.textPrimary)
                : GoogleFonts.outfit(fontSize: 12, color: c.textPrimary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Özet Paneli (sağ, seçim yokken) ──────────────────────────────────────────

class _OzetPanel extends StatelessWidget {
  final RaporViewModel vm;
  const _OzetPanel({required this.vm});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI kartları
          _KpiGrid(vm: vm),
          const SizedBox(height: 20),

          // Ödeme dağılımı
          Text('Ödeme Yöntemi Dağılımı',
            style: GoogleFonts.outfit(
              color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 10),
          _OdemeDagilimi(vm: vm),
          const SizedBox(height: 24),

          // Grafik
          Text(_chartBaslik(vm),
            style: GoogleFonts.outfit(
              color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: _RaporChart(vm: vm),
          ),
        ],
      ),
    );
  }

  String _chartBaslik(RaporViewModel vm) {
    if (vm.gosterSaatlik) return 'Saatlik Ciro (₺)';
    if (vm.gosterGunluk)  return 'Günlük Ciro (₺)';
    return 'Aylık Ciro (₺)';
  }
}

class _KpiGrid extends StatelessWidget {
  final RaporViewModel vm;
  const _KpiGrid({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10, runSpacing: 10,
      children: [
        _KpiKart(
          icon:  Icons.shopping_cart_rounded,
          label: 'Toplam Satış',
          value: '${vm.satisSayisi}',
          color: AppColors.teal,
        ),
        _KpiKart(
          icon:  Icons.payments_rounded,
          label: 'Toplam Ciro',
          value: _fmtMoney.format(vm.toplamCiro),
          color: AppColors.accentGreen,
        ),
        _KpiKart(
          icon:  Icons.trending_up_rounded,
          label: 'Brüt Kâr',
          value: _fmtMoney.format(vm.toplamKar),
          color: AppColors.gold,
        ),
        _KpiKart(
          icon:  Icons.calculate_rounded,
          label: 'Ort. Sepet',
          value: _fmtMoney.format(vm.ortalamaSepet),
          color: AppColors.tealDark,
        ),
      ],
    );
  }
}

class _KpiKart extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;
  const _KpiKart({
    required this.icon, required this.label,
    required this.value, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 10),
          Text(label, style: GoogleFonts.outfit(fontSize: 11, color: c.textSecondary)),
          const SizedBox(height: 2),
          Text(value,
            style: GoogleFonts.dmMono(
              fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary),
            overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _OdemeDagilimi extends StatelessWidget {
  final RaporViewModel vm;
  const _OdemeDagilimi({required this.vm});

  @override
  Widget build(BuildContext context) {
    final c     = context.colors;
    final total = vm.toplamCiro;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          _OdemeRow(
            icon: Icons.payments_rounded, label: 'Nakit',
            sayi: vm.nakitSayisi, ciro: vm.nakitCiro,
            total: total, color: AppColors.accentGreen),
          const SizedBox(height: 8),
          _OdemeRow(
            icon: Icons.credit_card_rounded, label: 'Kart',
            sayi: vm.kartSayisi, ciro: vm.kartCiro,
            total: total, color: AppColors.teal),
          const SizedBox(height: 8),
          _OdemeRow(
            icon: Icons.account_balance_wallet_rounded, label: 'Veresiye',
            sayi: vm.veresiyeSayisi, ciro: vm.veresiyeCiro,
            total: total, color: AppColors.gold),
        ],
      ),
    );
  }
}

class _OdemeRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final int      sayi;
  final double   ciro;
  final double   total;
  final Color    color;
  const _OdemeRow({
    required this.icon, required this.label, required this.sayi,
    required this.ciro, required this.total, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c    = context.colors;
    final pct  = total > 0 ? ciro / total : 0.0;

    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(label,
            style: GoogleFonts.outfit(fontSize: 12, color: c.textSecondary))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.toDouble(),
              backgroundColor: color.withAlpha(18),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text('$sayi',
            textAlign: TextAlign.right,
            style: GoogleFonts.dmMono(fontSize: 11, color: c.textMuted))),
        const SizedBox(width: 6),
        SizedBox(
          width: 86,
          child: Text(_fmtMoney.format(ciro),
            textAlign: TextAlign.right,
            style: GoogleFonts.dmMono(
              fontSize: 12, fontWeight: FontWeight.w600, color: c.textPrimary))),
      ],
    );
  }
}

// ── Grafik ─────────────────────────────────────────────────────────────────────

class _RaporChart extends StatelessWidget {
  final RaporViewModel vm;
  const _RaporChart({required this.vm});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (vm.gosterSaatlik) return _saatlikChart(vm.saatlikVeri, c);
    if (vm.gosterGunluk)  return _gunlukChart(vm.gunlukVeri,   c);
    return _aylikChart(vm.aylikVeri, c);
  }

  // ── Saatlik ──────────────────────────────────────────────────────────────

  Widget _saatlikChart(List<SaatlikOzet> veri, AppColorScheme c) {
    if (veri.isEmpty) return _bos(c);

    final maxCiro = veri.map((v) => v.ciro).reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: maxCiro * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: c.border, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 42,
              getTitlesWidget: (v, _) => Text(
                '${_fmtMoneyK.format(v)}₺',
                style: GoogleFonts.dmMono(fontSize: 9, color: c.textMuted)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 24,
              getTitlesWidget: (v, _) {
                final saat = v.toInt();
                if (saat % 2 != 0) return const SizedBox.shrink();
                return Text('$saat',
                  style: GoogleFonts.dmMono(fontSize: 9, color: c.textSecondary));
              },
            ),
          ),
          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: List.generate(24, (saat) {
          final ozet = veri.firstWhere(
            (v) => v.saat == saat,
            orElse: () => SaatlikOzet(saat: saat, satisSayisi: 0, ciro: 0),
          );
          return BarChartGroupData(x: saat, barRods: [
            BarChartRodData(
              toY:          ozet.ciro,
              gradient:     ozet.ciro > 0 ? _tealGrad() : null,
              color:        ozet.ciro > 0 ? null : c.border,
              width:        10,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ]);
        }),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (_, __, rod, ___) => BarTooltipItem(
              _fmtMoney.format(rod.toY),
              GoogleFonts.dmMono(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  // ── Günlük ────────────────────────────────────────────────────────────────

  Widget _gunlukChart(List<GunlukOzet> veri, AppColorScheme c) {
    if (veri.isEmpty) return _bos(c);

    final maxCiro = veri.map((v) => v.ciro).reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: maxCiro * 1.2,
        gridData: FlGridData(
          show: true, drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: c.border, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 44,
              getTitlesWidget: (v, _) => Text(
                '${_fmtMoneyK.format(v)}₺',
                style: GoogleFonts.dmMono(fontSize: 9, color: c.textMuted)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 24,
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= veri.length) return const SizedBox.shrink();
                if (veri.length > 14 && idx % 3 != 0) return const SizedBox.shrink();
                return Text('${veri[idx].gunNo}',
                  style: GoogleFonts.dmMono(fontSize: 9, color: c.textSecondary));
              },
            ),
          ),
          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: veri.asMap().entries.map((entry) {
          final idx = entry.key;
          final ozet = entry.value;
          return BarChartGroupData(x: idx, barRods: [
            BarChartRodData(
              toY:          ozet.ciro,
              gradient:     _tealGrad(),
              width:        14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ]);
        }).toList(),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, __) {
              final ozet = veri[group.x.toInt()];
              return BarTooltipItem(
                '${ozet.gunNo} — ${_fmtMoney.format(rod.toY)}',
                GoogleFonts.dmMono(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Aylık ──────────────────────────────────────────────────────────────────

  Widget _aylikChart(List<AylikOzet> veri, AppColorScheme c) {
    if (veri.isEmpty) return _bos(c);

    final maxCiro = veri.map((v) => v.ciro).reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: maxCiro * 1.2,
        gridData: FlGridData(
          show: true, drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: c.border, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 44,
              getTitlesWidget: (v, _) => Text(
                '${_fmtMoneyK.format(v)}₺',
                style: GoogleFonts.dmMono(fontSize: 9, color: c.textMuted)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 24,
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= veri.length) return const SizedBox.shrink();
                return Text(veri[idx].ayKisa,
                  style: GoogleFonts.outfit(fontSize: 9, color: c.textSecondary));
              },
            ),
          ),
          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: veri.asMap().entries.map((entry) {
          final idx  = entry.key;
          final ozet = entry.value;
          return BarChartGroupData(x: idx, barRods: [
            BarChartRodData(
              toY:          ozet.ciro,
              gradient:     _tealGrad(),
              width:        22,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ]);
        }).toList(),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, __) {
              final ozet = veri[group.x.toInt()];
              return BarTooltipItem(
                '${ozet.ayKisa} — ${_fmtMoney.format(rod.toY)}',
                GoogleFonts.dmMono(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _bos(AppColorScheme c) => Center(
    child: Text('Grafik verisi yok',
      style: GoogleFonts.outfit(color: c.textMuted, fontSize: 13)));

  LinearGradient _tealGrad() => const LinearGradient(
    begin: Alignment.bottomCenter,
    end:   Alignment.topCenter,
    colors: [AppColors.tealDark, AppColors.teal],
  );
}

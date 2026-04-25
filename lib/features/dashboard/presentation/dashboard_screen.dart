import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_color_scheme.dart';
import '../../terminal/data/models/sale_model.dart';
import '../viewmodel/dashboard_viewmodel.dart';

final _fmtMoney   = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
final _fmtCompact = NumberFormat.compactCurrency(locale: 'tr_TR', symbol: '₺', decimalDigits: 1);

// ══════════════════════════════════════════════════════════════════════════════
// DASHBOARD SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardViewModel>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardViewModel>(
      builder: (_, vm, __) {
        if (vm.loading && vm.ciro == 0) {
          return const Center(child: CircularProgressIndicator(color: AppColors.teal));
        }
        return RefreshIndicator(
          color: AppColors.teal,
          onRefresh: vm.yenile,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DashboardHeader(vm: vm),
                const SizedBox(height: 20),
                _KpiRow(vm: vm),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _CiroChart(vm: vm)),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: _KasalarCard(vm: vm)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _KritikStokCard(vm: vm)),
                    const SizedBox(width: 16),
                    Expanded(flex: 3, child: _SonSatislarCard(vm: vm)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  final DashboardViewModel vm;
  const _DashboardHeader({required this.vm});

  static const _donemLabels = {
    DashboardDonem.bugun    : 'Bugün',
    DashboardDonem.buHafta  : 'Bu Hafta',
    DashboardDonem.buAy     : 'Bu Ay',
    DashboardDonem.gecenAy  : 'Geçen Ay',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dashboard',
              style: GoogleFonts.outfit(
                color: c.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
            Text(DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(DateTime.now()),
              style: GoogleFonts.outfit(color: c.textSecondary, fontSize: 12)),
          ],
        ),
        const Spacer(),
        // Dönem seçici
        ...DashboardDonem.values.map((d) => Padding(
          padding: const EdgeInsets.only(left: 6),
          child: ChoiceChip(
            label: Text(_donemLabels[d]!,
              style: GoogleFonts.outfit(fontSize: 12)),
            selected: vm.donem == d,
            onSelected: (_) => vm.setDonem(d),
            selectedColor: AppColors.teal.withAlpha(40),
            labelStyle: GoogleFonts.outfit(
              color: vm.donem == d ? AppColors.teal : c.textSecondary),
          ),
        )),
        const SizedBox(width: 10),
        IconButton(
          icon: vm.loading
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.teal))
              : Icon(Icons.refresh_rounded, color: c.textSecondary, size: 20),
          onPressed: vm.loading ? null : vm.yenile,
        ),
      ],
    );
  }
}

// ── KPI Kartları ──────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  final DashboardViewModel vm;
  const _KpiRow({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _KpiCard(
          label:    'Ciro',
          value:    _fmtCompact.format(vm.ciro),
          icon:     Icons.trending_up_rounded,
          color:    AppColors.teal,
          sublabel: '${vm.satisAdedi} satış',
        )),
        const SizedBox(width: 12),
        Expanded(child: _KpiCard(
          label:    'Brüt Kâr',
          value:    _fmtCompact.format(vm.kar),
          icon:     Icons.account_balance_wallet_rounded,
          color:    AppColors.accentGreen,
          sublabel: vm.ciro > 0
              ? 'Marj: %${(vm.kar / vm.ciro * 100).toStringAsFixed(1)}'
              : '—',
        )),
        const SizedBox(width: 12),
        Expanded(child: _KpiCard(
          label:    'Giderler',
          value:    _fmtCompact.format(vm.gider),
          icon:     Icons.remove_circle_outline_rounded,
          color:    AppColors.accentRed,
          sublabel: 'Dönem giderleri',
        )),
        const SizedBox(width: 12),
        Expanded(child: _KpiCard(
          label:    'Net Kâr',
          value:    _fmtCompact.format(vm.netKar),
          icon:     Icons.star_rounded,
          color:    vm.netKar >= 0 ? AppColors.gold : AppColors.accentRed,
          sublabel: vm.netKar >= 0 ? 'Kârdasınız ✓' : 'Zararda ✗',
        )),
        const SizedBox(width: 12),
        Expanded(child: _KpiCard(
          label:    'Tahsil Edilecek',
          value:    _fmtCompact.format(vm.toplamAlacak),
          icon:     Icons.people_alt_rounded,
          color:    const Color(0xFF6CB4E4),
          sublabel: 'Müşteri alacakları',
        )),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label, value, sublabel;
  final IconData icon;
  final Color    color;
  const _KpiCard({
    required this.label, required this.value, required this.sublabel,
    required this.icon, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(value,
            style: GoogleFonts.dmMono(
              color: c.textPrimary,
              fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
            style: GoogleFonts.outfit(
              color: c.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(sublabel,
            style: GoogleFonts.outfit(
              color: c.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Ciro Grafiği ──────────────────────────────────────────────────────────────

class _CiroChart extends StatelessWidget {
  final DashboardViewModel vm;
  const _CiroChart({required this.vm});

  @override
  Widget build(BuildContext context) {
    final c    = context.colors;
    final data = vm.gunlukCiro;

    return Container(
      height: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Son 7 Gün Ciro',
            style: GoogleFonts.outfit(
              color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Expanded(
            child: data.isEmpty || data.every((e) => e.value == 0)
                ? Center(
                    child: Text('Veri yok',
                      style: GoogleFonts.outfit(
                        color: c.textSecondary, fontSize: 13)))
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: data.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.2,
                      barGroups: data.asMap().entries.map((e) => BarChartGroupData(
                        x: e.key,
                        barRods: [BarChartRodData(
                          toY: e.value.value,
                          color: AppColors.teal,
                          width: 18,
                          borderRadius: BorderRadius.circular(4),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: data.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.2,
                            color: c.bgTertiary,
                          ),
                        )],
                      )).toList(),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) {
                              final idx = v.toInt();
                              if (idx < 0 || idx >= data.length) return const SizedBox();
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(data[idx].key,
                                  style: GoogleFonts.outfit(
                                    color: c.textMuted, fontSize: 10)),
                              );
                            },
                          ),
                        ),
                      ),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => c.bgSecondary,
                          getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                            _fmtMoney.format(rod.toY),
                            GoogleFonts.dmMono(
                              color: AppColors.teal,
                              fontWeight: FontWeight.w700, fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Kasalar ───────────────────────────────────────────────────────────────────

class _KasalarCard extends StatelessWidget {
  final DashboardViewModel vm;
  const _KasalarCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Kasa Bakiyeleri',
                style: GoogleFonts.outfit(
                  color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(_fmtMoney.format(vm.kasaToplami),
                style: GoogleFonts.dmMono(
                  color: AppColors.teal, fontSize: 14, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          ...vm.kasalar.map((k) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: c.bgTertiary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_kasaIcon(k.id), size: 16, color: c.textSecondary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(k.ad,
                        style: GoogleFonts.outfit(
                          color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                      Text(_kasaTipLabel(k.id),
                        style: GoogleFonts.outfit(
                          color: c.textMuted, fontSize: 10)),
                    ],
                  ),
                ),
                Text(_fmtMoney.format(k.bakiye),
                  style: GoogleFonts.dmMono(
                    color: k.bakiye >= 0 ? c.textPrimary : AppColors.accentRed,
                    fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  IconData _kasaIcon(String id) => switch (id) {
    'banka' => Icons.account_balance_rounded,
    'pos'   => Icons.credit_card_rounded,
    _       => Icons.payments_rounded,
  };

  String _kasaTipLabel(String id) => switch (id) {
    'banka' => 'Banka Havalesi',
    'pos'   => 'Kredi Kartı / POS',
    _       => 'Nakit',
  };
}

// ── Kritik Stok ───────────────────────────────────────────────────────────────

class _KritikStokCard extends StatelessWidget {
  final DashboardViewModel vm;
  const _KritikStokCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: vm.kritikStoklar.isNotEmpty
              ? AppColors.gold.withAlpha(60)
              : c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.gold),
              const SizedBox(width: 8),
              Text('Kritik Stok',
                style: GoogleFonts.outfit(
                  color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (vm.kritikStoklar.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${vm.kritikStoklar.length} ürün',
                    style: GoogleFonts.outfit(
                      color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (vm.kritikStoklar.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Tüm stoklar yeterli ✓',
                style: GoogleFonts.outfit(
                  color: AppColors.accentGreen, fontSize: 13)),
            )
          else
            ...vm.kritikStoklar.take(6).map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(p.ad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: c.textPrimary, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: p.stokTukendi
                          ? AppColors.accentRed.withAlpha(25)
                          : AppColors.gold.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      p.stokTukendi ? 'Tükendi' : 'Stok: ${p.stok}',
                      style: GoogleFonts.outfit(
                        color: p.stokTukendi ? AppColors.accentRed : AppColors.gold,
                        fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }
}

// ── Son Satışlar ──────────────────────────────────────────────────────────────

class _SonSatislarCard extends StatelessWidget {
  final DashboardViewModel vm;
  const _SonSatislarCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bugünkü Satışlar',
            style: GoogleFonts.outfit(
              color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (vm.satislar.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Bugün henüz satış yapılmadı',
                style: GoogleFonts.outfit(
                  color: c.textSecondary, fontSize: 13)),
            )
          else
            ...vm.satislar.take(8).map((s) {
              final odeme = switch (s.odemeTip) {
                OdemeTip.nakit      => ('Nakit',      AppColors.accentGreen),
                OdemeTip.krediKarti => ('Kart',       const Color(0xFF6CB4E4)),
                OdemeTip.veresiye   => ('Veresiye',   AppColors.gold),
              };

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.cariAdi ?? DateFormat('HH:mm').format(s.tarih),
                        style: GoogleFonts.outfit(
                          color: c.textPrimary, fontSize: 13),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: odeme.$2.withAlpha(22),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(odeme.$1,
                        style: GoogleFonts.outfit(
                          color: odeme.$2, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    Text(_fmtMoney.format(s.toplam),
                      style: GoogleFonts.dmMono(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

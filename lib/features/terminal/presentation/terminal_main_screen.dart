import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_shortcuts.dart';
import '../../../core/services/printer_service.dart';
import '../../../core/theme/app_color_scheme.dart';
import '../data/models/cart_item.dart';
import '../viewmodel/terminal_viewmodel.dart';

final _fmtMoney = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);

// ── Manuel barkod dialog ───────────────────────────────────────────────────────
Future<void> showBarcodeDialog(BuildContext context) async {
  final ctrl = TextEditingController();
  final vm   = context.read<TerminalViewModel>();
  final c    = context.colors;

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: c.bgCard,
      title: Text('Manuel Barkod Gir',
        style: GoogleFonts.outfit(color: c.textPrimary, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 320,
        child: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.dmMono(color: c.textPrimary, fontSize: 16),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\-]'))],
          decoration: InputDecoration(
            hintText: 'Barkod numarasını girin...',
            hintStyle: GoogleFonts.outfit(color: c.textSecondary),
            prefixIcon: const Icon(Icons.qr_code_rounded, color: AppColors.teal),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) vm.lookupBarcode(v.trim());
            Navigator.pop(ctx);
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('İptal', style: TextStyle(color: c.textSecondary)),
        ),
        TextButton(
          onPressed: () {
            if (ctrl.text.trim().isNotEmpty) vm.lookupBarcode(ctrl.text.trim());
            Navigator.pop(ctx);
          },
          child: const Text('Ara', style: TextStyle(color: AppColors.teal)),
        ),
      ],
    ),
  );
  ctrl.dispose();
}

// ══════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class TerminalMainScreen extends StatefulWidget {
  const TerminalMainScreen({super.key});

  @override
  State<TerminalMainScreen> createState() => _TerminalMainScreenState();
}

class _TerminalMainScreenState extends State<TerminalMainScreen> {
  final FocusNode _keyFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyFocus.requestFocus();
      context.read<TerminalViewModel>().init();
    });
  }

  @override
  void dispose() {
    _keyFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return KeyboardListener(
      focusNode: _keyFocus,
      autofocus: true,
      onKeyEvent: (e) {
        final vm = context.read<TerminalViewModel>();
        if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.f4) {
          showBarcodeDialog(context);
          return;
        }
        vm.handleKeyEvent(e);
      },
      child: Scaffold(
        backgroundColor: c.bgPrimary,
        body: Column(
          children: [
            const _TopBar(),
            Expanded(
              child: Row(
                children: [
                  const Expanded(flex: 3, child: _ProductsPanel()),
                  VerticalDivider(width: 1, color: c.border),
                  const SizedBox(width: 340, child: _CartPanel()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TOP BAR
// ══════════════════════════════════════════════════════════════════════════════

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.bgSecondary,
        border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              gradient: AppColors.tealGradient,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.point_of_sale_rounded, size: 16, color: Colors.black),
          ),
          const SizedBox(width: 10),
          Text('Satış Terminali',
            style: GoogleFonts.outfit(
              color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),

          const SizedBox(width: 24),

          Consumer<TerminalViewModel>(
            builder: (_, vm, __) => Row(
              children: [
                _TopStat(label: 'Bugün',  value: _fmtMoney.format(vm.dailyTotal)),
                const SizedBox(width: 16),
                _TopStat(label: 'Satış',  value: '${vm.dailySaleCount}'),
                const SizedBox(width: 16),
                _TopStat(label: 'Ürün',   value: '${vm.products.length}'),
                if (vm.statusMessage.isNotEmpty) ...[
                  const SizedBox(width: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: vm.statusIsError
                          ? AppColors.accentRed.withAlpha(20)
                          : AppColors.teal.withAlpha(15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: vm.statusIsError
                            ? AppColors.accentRed.withAlpha(60)
                            : AppColors.teal.withAlpha(40)),
                    ),
                    child: Text(vm.statusMessage,
                      style: GoogleFonts.outfit(
                        color: vm.statusIsError ? AppColors.accentRed : AppColors.teal,
                        fontSize: 11,
                      )),
                  ),
                ],
              ],
            ),
          ),

          const Spacer(),

          _ToolbarButton(
            icon: Icons.qr_code_scanner_rounded,
            label: 'Barkod Gir (F4)',
            onTap: () => showBarcodeDialog(context),
          ),
          const SizedBox(width: 8),
          _ToolbarButton(
            icon: Icons.keyboard_outlined,
            label: 'Kısayollar',
            onTap: () => _showShortcuts(context),
          ),
          const SizedBox(width: 8),
          Consumer<TerminalViewModel>(
            builder: (_, vm, __) => _ToolbarButton(
              icon: vm.loading ? Icons.hourglass_top_rounded : Icons.refresh_rounded,
              label: 'Raporu Yenile (F5)',
              onTap: vm.loading ? () {} : () => vm.refreshDailyReport(),
            ),
          ),
        ],
      ),
    );
  }

  void _showShortcuts(BuildContext context) {
    final c = context.colors;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.bgCard,
        title: Text('Klavye Kısayolları',
          style: GoogleFonts.outfit(
            color: c.textPrimary, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppShortcuts.shortcuts.entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.bgTertiary,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: c.border),
                  ),
                  child: Text(e.key,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmMono(
                      color: AppColors.teal, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(e.value,
                    style: GoogleFonts.outfit(
                      color: c.textSecondary, fontSize: 13)),
                ),
              ],
            ),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat', style: TextStyle(color: AppColors.teal)),
          ),
        ],
      ),
    );
  }
}

class _TopStat extends StatelessWidget {
  final String label, value;
  const _TopStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
          style: GoogleFonts.outfit(color: c.textSecondary, fontSize: 10)),
        Text(value,
          style: GoogleFonts.dmMono(
            color: AppColors.teal, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ToolbarButton({
    required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.border),
          ),
          child: Icon(icon, size: 18, color: c.textSecondary),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// LEFT PANEL — Products + Categories
// ══════════════════════════════════════════════════════════════════════════════

class _ProductsPanel extends StatelessWidget {
  const _ProductsPanel();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        const _SearchBar(),
        const _CategoryBar(),
        Divider(height: 1, color: c.border),
        const Expanded(child: _ProductGrid()),
      ],
    );
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar();

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: TextField(
        controller: _ctrl,
        style: GoogleFonts.outfit(color: c.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Ürün ara veya barkod gir...',
          hintStyle: GoogleFonts.outfit(color: c.textSecondary, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded, color: c.textSecondary, size: 20),
          suffixIcon: _ctrl.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, size: 18, color: c.textSecondary),
                  onPressed: () {
                    _ctrl.clear();
                    context.read<TerminalViewModel>().setSearch('');
                    setState(() {});
                  },
                )
              : null,
        ),
        onChanged: (v) {
          context.read<TerminalViewModel>().setSearch(v);
          setState(() {});
        },
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar();

  @override
  Widget build(BuildContext context) {
    final c          = context.colors;
    final vm         = context.watch<TerminalViewModel>();
    final categories = ['Tümü', ...vm.categories];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemCount: categories.length,
        itemBuilder: (_, i) {
          final cat      = categories[i];
          final isAll    = cat == 'Tümü';
          final selected = isAll
              ? vm.selectedCategory == null
              : vm.selectedCategory == cat;

          return GestureDetector(
            onTap: () => vm.setCategory(isAll ? null : cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.teal.withAlpha(22) : c.bgCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.teal.withAlpha(80) : c.border),
              ),
              child: Text(cat,
                style: GoogleFonts.outfit(
                  color: selected ? AppColors.teal : c.textSecondary,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                )),
            ),
          );
        },
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid();

  @override
  Widget build(BuildContext context) {
    final c        = context.colors;
    final vm       = context.watch<TerminalViewModel>();
    final products = vm.filteredProducts;

    if (vm.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.teal));
    }

    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: c.textSecondary),
            const SizedBox(height: 12),
            Text('Ürün bulunamadı',
              style: GoogleFonts.outfit(color: c.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: products.length,
      itemBuilder: (_, i) => _ProductCard(product: products[i], index: i),
    );
  }
}

class _ProductCard extends StatefulWidget {
  final dynamic product;
  final int index;
  const _ProductCard({required this.product, required this.index});

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c          = context.colors;
    final p          = widget.product;
    final outOfStock = p.isOutOfStock as bool;
    final lowStock   = p.isLowStock   as bool;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: outOfStock ? null : () => context.read<TerminalViewModel>().addToCart(p),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: outOfStock ? c.bgCard.withAlpha(128) : c.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hover && !outOfStock
                  ? AppColors.teal.withAlpha(80)
                  : c.border),
            boxShadow: _hover && !outOfStock
                ? [BoxShadow(color: AppColors.teal.withAlpha(15), blurRadius: 12)]
                : null,
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 56,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: c.bgTertiary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.inventory_2_outlined,
                        color: c.textSecondary, size: 28),
                    ),
                    const SizedBox(height: 8),
                    Text(p.name as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: outOfStock ? c.textSecondary : c.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      )),
                    const Spacer(),
                    Text(_fmtMoney.format(p.price as num),
                      style: GoogleFonts.dmMono(
                        color: outOfStock ? c.textSecondary : AppColors.teal,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      )),
                    const SizedBox(height: 4),
                    Text(
                      outOfStock ? 'Stok yok' : 'Stok: ${p.stock}',
                      style: GoogleFonts.outfit(
                        color: outOfStock
                            ? AppColors.accentRed
                            : lowStock ? AppColors.gold : c.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (lowStock && !outOfStock)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withAlpha(30),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Az',
                      style: GoogleFonts.outfit(
                        color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                ),
              if (outOfStock)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.bgPrimary.withAlpha(128),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text('Tükendi',
                        style: GoogleFonts.outfit(
                          color: AppColors.accentRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        )),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 20 * (widget.index % 20)))
        .fadeIn(duration: 200.ms)
        .slideY(begin: 0.05, end: 0);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// RIGHT PANEL — Cart
// ══════════════════════════════════════════════════════════════════════════════

class _CartPanel extends StatelessWidget {
  const _CartPanel();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      color: c.bgSecondary,
      child: Column(
        children: [
          const _CartHeader(),
          Divider(height: 1, color: c.border),
          const Expanded(child: _CartItemList()),
          Divider(height: 1, color: c.border),
          const _CartFooter(),
        ],
      ),
    );
  }
}

class _CartHeader extends StatelessWidget {
  const _CartHeader();

  @override
  Widget build(BuildContext context) {
    final c  = context.colors;
    final vm = context.watch<TerminalViewModel>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.shopping_cart_rounded, color: AppColors.teal, size: 18),
          const SizedBox(width: 8),
          Text('Sepet',
            style: GoogleFonts.outfit(
              color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          if (vm.cart.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.teal.withAlpha(22),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.teal.withAlpha(60)),
              ),
              child: Text('${vm.cart.length}',
                style: GoogleFonts.dmMono(
                  color: AppColors.teal, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          const Spacer(),
          if (vm.cart.isNotEmpty)
            Tooltip(
              message: 'Sepeti Temizle (F6)',
              child: InkWell(
                onTap: () => _confirmClear(context, vm),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.delete_sweep_rounded,
                    size: 18, color: c.textSecondary),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context, TerminalViewModel vm) {
    final c = context.colors;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.bgCard,
        title: Text('Sepeti Temizle',
          style: GoogleFonts.outfit(
            color: c.textPrimary, fontWeight: FontWeight.w700)),
        content: Text('Tüm ürünler sepetten kaldırılacak.',
          style: GoogleFonts.outfit(color: c.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () { vm.clearCart(); Navigator.pop(context); },
            child: const Text('Temizle', style: TextStyle(color: AppColors.accentRed)),
          ),
        ],
      ),
    );
  }
}

class _CartItemList extends StatelessWidget {
  const _CartItemList();

  @override
  Widget build(BuildContext context) {
    final c  = context.colors;
    final vm = context.watch<TerminalViewModel>();

    if (vm.cart.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined,
              size: 48, color: c.textSecondary),
            const SizedBox(height: 12),
            Text('Sepet boş',
              style: GoogleFonts.outfit(color: c.textSecondary, fontSize: 13)),
            const SizedBox(height: 6),
            Text('Ürüne tıklayın veya barkod okutun',
              style: GoogleFonts.outfit(color: c.textMuted, fontSize: 11)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      separatorBuilder: (_, __) => Divider(
        height: 1, indent: 16, endIndent: 16, color: c.border),
      itemCount: vm.cart.length,
      itemBuilder: (_, i) => _CartRow(item: vm.cart[i], index: i),
    );
  }
}

class _CartRow extends StatefulWidget {
  final CartItem item;
  final int index;
  const _CartRow({required this.item, required this.index});

  @override
  State<_CartRow> createState() => _CartRowState();
}

class _CartRowState extends State<_CartRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c    = context.colors;
    final vm   = context.read<TerminalViewModel>();
    final item = widget.item;
    final i    = widget.index;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _hover ? c.bgTertiary : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: c.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    )),
                  const SizedBox(height: 2),
                  Text(_fmtMoney.format(item.product.price),
                    style: GoogleFonts.dmMono(
                      color: c.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            Row(
              children: [
                _QtyButton(
                  icon: Icons.remove_rounded,
                  onTap: () => item.quantity > 1
                      ? vm.updateCartItemQuantity(i, item.quantity - 1)
                      : vm.removeFromCart(i),
                ),
                SizedBox(
                  width: 36,
                  child: Text('${item.quantity}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmMono(
                      color: c.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    )),
                ),
                _QtyButton(
                  icon: Icons.add_rounded,
                  onTap: () => vm.updateCartItemQuantity(i, item.quantity + 1),
                ),
              ],
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 72,
              child: Text(_fmtMoney.format(item.lineTotal),
                textAlign: TextAlign.right,
                style: GoogleFonts.dmMono(
                  color: AppColors.teal,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                )),
            ),
            const SizedBox(width: 4),
            if (_hover)
              IconButton(
                icon: const Icon(Icons.close_rounded,
                  size: 16, color: AppColors.accentRed),
                onPressed: () => vm.removeFromCart(i),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              )
            else
              const SizedBox(width: 28),
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 24, height: 24,
        decoration: BoxDecoration(
          color: c.bgCard,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: c.border),
        ),
        child: Icon(icon, size: 14, color: c.textSecondary),
      ),
    );
  }
}

// ── Cart Footer ───────────────────────────────────────────────────────────────

class _CartFooter extends StatelessWidget {
  const _CartFooter();

  @override
  Widget build(BuildContext context) {
    final c     = context.colors;
    final vm    = context.watch<TerminalViewModel>();
    final total = vm.cartTotal;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FooterRow(label: 'Ara Toplam', value: _fmtMoney.format(total)),
          const SizedBox(height: 4),
          _FooterRow(
            label: 'Ürün Adedi',
            value: '${vm.cart.fold(0, (s, i) => s + i.quantity)}',
            small: true,
          ),
          const SizedBox(height: 12),
          Divider(color: c.border, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOPLAM',
                style: GoogleFonts.outfit(
                  color: c.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                )),
              Text(_fmtMoney.format(total),
                style: GoogleFonts.dmMono(
                  color: AppColors.teal,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                )),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Veresiye',
                  sublabel: 'F2',
                  icon: Icons.person_add_outlined,
                  color: AppColors.gold,
                  enabled: vm.cart.isNotEmpty,
                  onTap: () => _showCreditDialog(context, vm, total),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  label: 'Kart',
                  sublabel: 'F3',
                  icon: Icons.credit_card_rounded,
                  color: c.textSecondary,
                  enabled: vm.cart.isNotEmpty,
                  onTap: () => _completeSale(context, vm, OdemeTip.krediKarti),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ActionButton(
            label: 'Nakit Tahsil Et',
            sublabel: 'F1',
            icon: Icons.payments_rounded,
            color: AppColors.teal,
            primary: true,
            enabled: vm.cart.isNotEmpty,
            onTap: () => _completeSale(context, vm, OdemeTip.nakit),
          ),
        ],
      ),
    );
  }

  Future<void> _completeSale(
    BuildContext context,
    TerminalViewModel vm,
    OdemeTip odemeTip,
  ) async {
    if (vm.cart.isEmpty) return;
    final cartSnapshot = List<CartItem>.from(vm.cart);
    final total        = vm.cartTotal;
    final saleId       = await vm.completeSale(odemeTip: odemeTip);
    if (saleId != null && context.mounted) {
      final sm = ScaffoldMessenger.of(context);
      await PrinterService.instance.printReceipt(
        saleId: saleId,
        items:  cartSnapshot,
        total:  total,
        odemeTip: odemeTip,
      );
      sm.showSnackBar(SnackBar(
        content: Text('Satış tamamlandı ✓', style: GoogleFonts.outfit()),
        backgroundColor: AppColors.accentGreen,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _showCreditDialog(
    BuildContext context,
    TerminalViewModel vm,
    double total,
  ) async {
    if (vm.cart.isEmpty) return;
    final cartSnapshot = List<CartItem>.from(vm.cart);

    final cari = await showDialog<CariModel>(
      context: context,
      builder: (_) => _CariPickerDialog(cariler: vm.cariler),
    );
    if (cari == null || !context.mounted) return;

    final saleId = await vm.completeSale(
      odemeTip: OdemeTip.veresiye,
      cari:     cari,
    );
    if (saleId != null && context.mounted) {
      final sm = ScaffoldMessenger.of(context);
      final cariAd = cari.ad;
      await PrinterService.instance.printReceipt(
        saleId: saleId,
        items:  cartSnapshot,
        total:  total,
        odemeTip: OdemeTip.veresiye,
        customerName: cariAd,
      );
      sm.showSnackBar(SnackBar(
        content: Text('Veresiye kaydedildi — $cariAd', style: GoogleFonts.outfit()),
        backgroundColor: AppColors.gold,
        duration: const Duration(seconds: 3),
      ));
    }
  }
}

class _FooterRow extends StatelessWidget {
  final String label, value;
  final bool small;
  const _FooterRow({required this.label, required this.value, this.small = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
          style: GoogleFonts.outfit(
            color: c.textSecondary,
            fontSize: small ? 11 : 13)),
        Text(value,
          style: GoogleFonts.dmMono(
            color: small ? c.textSecondary : c.textPrimary,
            fontSize: small ? 11 : 13)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label, sublabel;
  final IconData icon;
  final Color color;
  final bool primary, enabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label, required this.sublabel,
    required this.icon,  required this.color, required this.onTap,
    this.primary = false, this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1.0 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: primary ? 14 : 12, horizontal: 12),
          decoration: BoxDecoration(
            gradient: primary
                ? LinearGradient(
                    colors: [color, color.withAlpha(180)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight)
                : null,
            color: primary ? null : c.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primary ? color : c.border),
            boxShadow: primary
                ? [BoxShadow(
                    color: color.withAlpha(60),
                    blurRadius: 12,
                    offset: const Offset(0, 4))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: primary ? Colors.black87 : color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                  style: GoogleFonts.outfit(
                    color: primary ? Colors.black87 : c.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  )),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: primary ? Colors.black26 : c.bgTertiary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(sublabel,
                  style: GoogleFonts.dmMono(
                    color: primary ? Colors.white70 : c.textSecondary,
                    fontSize: 10,
                  )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CARİ (MÜŞTERİ) SEÇME DİALOGU
// ══════════════════════════════════════════════════════════════════════════════

class _CariPickerDialog extends StatefulWidget {
  final List<CariModel> cariler;
  const _CariPickerDialog({required this.cariler});

  @override
  State<_CariPickerDialog> createState() => _CariPickerDialogState();
}

class _CariPickerDialogState extends State<_CariPickerDialog> {
  String _search = '';

  List<CariModel> get _filtered => widget.cariler
      .where((c) =>
          c.ad.toLowerCase().contains(_search.toLowerCase()) ||
          (c.telefon ?? '').contains(_search))
      .toList();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      backgroundColor: c.bgCard,
      title: Text('Müşteri Seç',
        style: GoogleFonts.outfit(
          color: c.textPrimary, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 360,
        height: 400,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              style: GoogleFonts.outfit(color: c.textPrimary),
              decoration: const InputDecoration(
                hintText: 'İsim veya telefon ara...',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text('Müşteri bulunamadı',
                        style: GoogleFonts.outfit(color: c.textSecondary)))
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final cari = _filtered[i];
                        return ListTile(
                          onTap: () => Navigator.pop(context, cari),
                          title: Text(cari.ad,
                            style: GoogleFonts.outfit(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w600)),
                          subtitle: cari.telefon != null
                              ? Text(cari.telefon!,
                                  style: GoogleFonts.outfit(
                                    color: c.textSecondary, fontSize: 12))
                              : null,
                          trailing: cari.alacaklimi
                              ? Text(_fmtMoney.format(cari.bakiye),
                                  style: GoogleFonts.dmMono(
                                    color: AppColors.accentRed, fontSize: 12))
                              : const Icon(Icons.check_circle_rounded,
                                  color: AppColors.accentGreen, size: 16),
                        );
                      },
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
      ],
    );
  }
}

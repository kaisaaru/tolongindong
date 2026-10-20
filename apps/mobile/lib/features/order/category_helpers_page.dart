import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format/rupiah.dart';
import '../../models/service_category.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'helper_detail_page.dart';
import 'order_models.dart';
import 'order_samples.dart';
import 'order_style.dart';
import 'widgets/order_widgets.dart';

/// Daftar helper dalam satu kategori, dibuka dari ubin kategori di beranda.
/// Bisa dicari lewat nama/keahlian dan disaring per sub-kategori.
///
/// Isinya masih contoh: `GET /helpers?category_id=` sudah ada, tapi belum
/// memberi sub-kategori, label keahlian, maupun harga tetap per jasa.
class CategoryHelpersPage extends StatefulWidget {
  const CategoryHelpersPage({super.key, required this.category, this.listings});

  final ServiceCategory category;

  /// Diisi saat pengujian. Default: data contoh untuk kategori ini.
  final List<HelperListing>? listings;

  @override
  State<CategoryHelpersPage> createState() => _CategoryHelpersPageState();
}

class _CategoryHelpersPageState extends State<CategoryHelpersPage> {
  static const _all = 'Semua';

  late final _listings =
      widget.listings ?? OrderSamples.listingsFor(widget.category.code);
  late final _filters = [
    _all,
    ...?OrderSamples.subcategories[widget.category.code],
  ];

  String _selected = _all;
  String _query = '';

  List<HelperListing> get _visible {
    final q = _query.trim().toLowerCase();
    return [
      for (final item in _listings)
        if ((_selected == _all || item.subcategory == _selected) &&
            (q.isEmpty ||
                item.name.toLowerCase().contains(q) ||
                item.tags.any((t) => t.toLowerCase().contains(q))))
          item,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: OrderStyle.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Jarak diukur dari desain: search 15 dp di bawah judul, chip
              // 20 dp di bawah search, kartu 26 dp di bawah chip.
              SquareTitleBar(widget.category.name),
              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 35),
                child: _SearchField(
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              const SizedBox(height: 15),
              if (_filters.length > 1)
                _FilterChips(
                  filters: _filters,
                  selected: _selected,
                  onSelected: (value) => setState(() => _selected = value),
                ),
              Expanded(
                child: visible.isEmpty
                    ? _EmptyState(
                        hasFilter: _query.isNotEmpty || _selected != _all,
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          22,
                          21,
                          22,
                          24 + MediaQuery.paddingOf(context).bottom,
                        ),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final item = visible[index];
                          return _HelperCard(
                            item: item,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => HelperDetailPage(helper: item),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final hint = AppTypography.style(
      size: AppTypography.small,
      weight: AppTypography.regular,
      color: AppColors.textSecondary,
    );

    return Container(
      height: 37,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.light,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outline, width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration.collapsed(
                hintText: 'Cari jasa yang kamu butuhkan',
                hintStyle: hint,
              ),
              style: hint.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.filters,
    required this.selected,
    required this.onSelected,
  });

  final List<String> filters;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Chip setinggi 27 dp, ditambah ruang 5 dp untuk bayangan chip aktif.
      height: 37,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 5),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final label = filters[index];
          final active = label == selected;
          return Semantics(
            button: true,
            selected: active,
            child: GestureDetector(
              onTap: () => onSelected(label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 13),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.light,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.45),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  style: AppTypography.style(
                    size: 13,
                    weight: AppTypography.semiBold,
                    color: active ? AppColors.light : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HelperCard extends StatelessWidget {
  const _HelperCard({required this.item, required this.onTap});

  final HelperListing item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unit = item.unit;

    return Material(
      color: AppColors.light,
      borderRadius: BorderRadius.circular(12),
      shadowColor: OrderStyle.shadow,
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
          child: Row(
            children: [
              HelperAvatar(name: item.name, photoUrl: item.photoUrl, size: 68),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              size: 12,
                              weight: AppTypography.semiBold,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          unit == null
                              ? rupiah(item.price)
                              : '${rupiah(item.price)}/$unit',
                          style: AppTypography.style(
                            size: 12,
                            weight: AppTypography.regular,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        StarRow(rating: item.rating, size: 13),
                        const SizedBox(width: 12),
                        Text(
                          '(${item.reviewCount})',
                          style: AppTypography.style(
                            size: 10,
                            weight: AppTypography.regular,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [for (final tag in item.tags) TagChip(tag)],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilter});

  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          hasFilter
              ? 'Tidak ada helper yang cocok.'
              : 'Belum ada helper di kategori ini.',
          textAlign: TextAlign.center,
          style: AppTypography.style(
            size: AppTypography.small,
            weight: AppTypography.regular,
            color: AppColors.textDescription,
          ),
        ),
      ),
    );
  }
}

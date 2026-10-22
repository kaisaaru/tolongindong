import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/service_category.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../home/widgets/promo_carousel.dart';
import '../order/order_store.dart';
import 'active_order_page.dart';
import 'household_models.dart';
import 'house_order_form_page.dart';
import 'move_order_form_page.dart';
import 'widgets/household_widgets.dart';

/// Kategori Household: pilih kebutuhan (Pindahan, Rumah, Kamar, Pakaian).
class HouseholdPage extends StatelessWidget {
  const HouseholdPage({super.key, required this.category});

  /// Kategori dari server, untuk `category_id` dan tarif dasar saat
  /// pesanan dikirim ke backend nanti.
  final ServiceCategory category;

  void _open(BuildContext context, HouseholdService service) {
    // Hanya satu pesanan Household boleh berjalan. Diberi tahu sekarang,
    // bukan setelah form panjangnya selesai diisi.
    final orders = context.read<OrderStore>();
    if (orders.active != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Masih ada pesanan Household yang berjalan.'),
            action: SnackBarAction(
              label: 'Lihat',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => ActiveOrderPage()),
              ),
            ),
          ),
        );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => service == HouseholdService.pindahan
            ? MoveOrderFormPage(category: category)
            : HouseOrderFormPage(service: service, category: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.light,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          ColoredHeader(
            title: category.name,
            color: AppColors.primary,
            // Ilustrasi sapu di desain belum diekspor; ikon sementara.
            decoration: Icon(
              Icons.cleaning_services_outlined,
              size: 76,
              color: AppColors.light.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 26),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 35),
            child: SectionLabel('Kategori Kebutuhan'),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Row(
              children: [
                for (final service in HouseholdService.values)
                  Expanded(
                    child: _ServiceTile(
                      service: service,
                      onTap: () => _open(context, service),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 39),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 35),
            child: SectionLabel('Penawaran Spesial'),
          ),
          const SizedBox(height: 16),
          PromoCarousel(
            onTap: (_) => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Voucher belum tersedia.')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, required this.onTap});

  final HouseholdService service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: service.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Column(
            children: [
              // 73 dp di desain. Di layar sempit tetap persegi, mengecil
              // mengikuti lebar kolomnya.
              LayoutBuilder(
                builder: (context, box) => SizedBox.square(
                  dimension: box.maxWidth < 73 ? box.maxWidth : 73,
                  child: _tile(),
                ),
              ),
              const SizedBox(height: 10),
              // Satu baris utuh; "Pindahan" mengecil di layar sempit
              // alih-alih terpotong jadi "Pindah...".
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  service.label,
                  maxLines: 1,
                  style: AppTypography.style(
                    size: 13,
                    weight: AppTypography.regular,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile() => Container(
    decoration: BoxDecoration(
      color: service.tileColor,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6),
      ],
    ),
    child: Icon(service.icon, size: 34, color: service.iconColor),
  );
}

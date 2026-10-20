import 'package:flutter/material.dart';

import '../../models/service_category.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../home/widgets/promo_carousel.dart';
import 'household_models.dart';
import 'house_order_form_page.dart';
import 'widgets/household_widgets.dart';

/// Kategori Household: pilih kebutuhan (Pindahan, Rumah, Kamar, Pakaian).
class HouseholdPage extends StatelessWidget {
  const HouseholdPage({super.key, required this.category});

  /// Kategori dari server, untuk `category_id` dan tarif dasar saat
  /// pesanan dikirim ke backend nanti.
  final ServiceCategory category;

  void _open(BuildContext context, HouseholdService service) {
    if (!service.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${service.label} belum tersedia.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            HouseOrderFormPage(service: service, category: category),
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
              Container(
                width: 73,
                height: 73,
                decoration: BoxDecoration(
                  color: service.tileColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Icon(service.icon, size: 34, color: service.iconColor),
              ),
              const SizedBox(height: 10),
              Text(
                service.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.style(
                  size: 13,
                  weight: AppTypography.regular,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

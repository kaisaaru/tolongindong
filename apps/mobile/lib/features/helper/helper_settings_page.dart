import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../models/service_category.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/empty_state.dart';
import '../auth/session_store.dart';
import '../home/catalog_repository.dart';
import '../order/widgets/order_widgets.dart';
import 'helper_store.dart';
import 'widgets/helper_widgets.dart';

/// Kategori layanan yang siap dikerjakan dan status kerja
/// (`PUT /helper/profile`).
class HelperSettingsPage extends StatefulWidget {
  const HelperSettingsPage({super.key});

  @override
  State<HelperSettingsPage> createState() => _HelperSettingsPageState();
}

class _HelperSettingsPageState extends State<HelperSettingsPage> {
  late final _store = context.read<HelperStore>();
  late final Future<List<ServiceCategory>> _categories = context
      .read<CatalogRepository>()
      .categories();

  late final Set<int> _selected = {
    for (final c in _store.status.categories) c.id,
  };
  late bool _available = _store.status.available;
  bool _saving = false;

  static const _descriptions = {
    'delivery': 'Pengantaran barang dan dokumen',
    'personal': 'Bantuan urusan pribadi sehari-hari',
    'household': 'Bantuan untuk kebutuhan rumah',
  };

  Future<void> _save() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal satu kategori layanan.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _store.saveSettings(
        available: _available,
        categoryIds: _selected.toList()..sort(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengaturan layanan disimpan.')),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = context.watch<SessionStore>().user?.fullName ?? '';
    final muted = AppTypography.style(
      size: 10,
      weight: AppTypography.regular,
      color: HelperStyle.muted,
      height: 1.5,
    );
    final heading = AppTypography.style(
      size: 13,
      weight: AppTypography.semiBold,
      color: HelperStyle.ink,
    );

    return Scaffold(
      backgroundColor: HelperStyle.background,
      body: Column(
        children: [
          HelperHeader(
            title: 'Kategori & ketersediaan',
            subtitle: 'Pengaturan layanan · $name',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                HelperCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kategori layanan', style: heading),
                      const SizedBox(height: 3),
                      Text(
                        'Pilih layanan yang siap kamu kerjakan.',
                        style: muted,
                      ),
                      const SizedBox(height: 6),
                      FutureBuilder<List<ServiceCategory>>(
                        future: _categories,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final categories = snapshot.data;
                          if (categories == null) {
                            return const EmptyState(
                              icon: Icons.cloud_off_rounded,
                              title: 'Kategori gagal dimuat',
                              message: 'Coba buka lagi halaman ini.',
                            );
                          }
                          return Column(
                            children: [
                              for (final c in categories)
                                _CategoryOption(
                                  category: c,
                                  description: _descriptions[c.code] ?? '',
                                  selected: _selected.contains(c.id),
                                  onChanged: (on) => setState(() {
                                    on
                                        ? _selected.add(c.id)
                                        : _selected.remove(c.id);
                                  }),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                HelperCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status kerja', style: heading),
                      const SizedBox(height: 10),
                      RadioGroup<bool>(
                        groupValue: _available,
                        onChanged: (v) => setState(() => _available = v!),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: HelperStyle.cardBorder),
                          ),
                          child: Column(
                            children: [
                              for (final (value, label) in [
                                (true, 'Sedang tersedia'),
                                (false, 'Sedang tidak tersedia'),
                              ])
                                RadioListTile<bool>(
                                  value: value,
                                  dense: true,
                                  activeColor: AppColors.primary,
                                  title: Text(
                                    label,
                                    style: AppTypography.style(
                                      size: 12,
                                      weight: AppTypography.regular,
                                      color: value == _available
                                          ? HelperStyle.ink
                                          : HelperStyle.muted,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Saat tidak tersedia, profilmu tidak muncul di '
                        'pencarian dan tidak menerima permintaan baru. '
                        'Permintaan yang sudah masuk tetap bisa dijawab dan '
                        'pesanan berjalan tetap dapat dikerjakan.',
                        style: muted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Pengaturan ini hanya untuk mode Helper di akun yang sama.',
                  textAlign: TextAlign.center,
                  style: muted,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: HelperBottomBar(
        children: [
          HelperButton(
            label: 'Simpan perubahan',
            isLoading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    required this.category,
    required this.description,
    required this.selected,
    required this.onChanged,
  });

  final ServiceCategory category;
  final String description;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!selected),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: HelperStyle.softRed,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: OrderIcon(
                HelperStyle.categoryIcon(category.code),
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: AppTypography.style(
                      size: 12,
                      weight: AppTypography.semiBold,
                      color: HelperStyle.ink,
                    ),
                  ),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: AppTypography.style(
                        size: 9,
                        weight: AppTypography.regular,
                        color: HelperStyle.muted,
                      ),
                    ),
                ],
              ),
            ),
            Checkbox(
              value: selected,
              activeColor: AppColors.primary,
              onChanged: (v) => onChanged(v ?? false),
            ),
          ],
        ),
      ),
    );
  }
}

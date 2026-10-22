import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format/rupiah.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/primary_button.dart';
import '../chat/chat_room_page.dart';
import '../chat/chat_store.dart';
import 'checkout_page.dart';
import 'order_models.dart';
import 'order_store.dart';
import 'order_style.dart';
import 'personal_order_page.dart';
import 'widgets/order_widgets.dart';

/// Profil helper: tentang, keahlian, review, dan tombol pesan.
class HelperDetailPage extends StatelessWidget {
  const HelperDetailPage({
    super.key,
    required this.helper,
    this.chatStore,
    this.store,
  });

  final HelperListing helper;

  /// Diisi saat pengujian. Default: [ChatStore.instance] dan
  /// [OrderStore.instance].
  final ChatStore? chatStore;
  final OrderStore? store;

  /// Hanya satu pesanan Personal boleh berjalan. Diberi tahu sebelum
  /// checkout, bukan setelah voucher dan pembayaran dipilih.
  void _order(BuildContext context) {
    final orders = store ?? OrderStore.instance;
    if (orders.personal != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Masih ada pesanan Personal yang berjalan.'),
            action: SnackBarAction(
              label: 'Lihat',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PersonalOrderPage(store: orders),
                ),
              ),
            ),
          ),
        );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CheckoutPage(helper: helper, store: orders, chatStore: chatStore),
      ),
    );
  }

  void _soon(BuildContext context, String feature) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$feature belum tersedia.')));

  /// Chat sebelum memesan. Nanti: `POST /chats/helpers/{id}`.
  void _chat(BuildContext context) {
    final store = chatStore ?? ChatStore.instance;
    final room = store.openWithHelper(
      helperId: helper.id,
      name: helper.name,
      photoUrl: helper.photoUrl,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatRoomPage(room: room, store: store),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: OrderStyle.background,
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Header(
              helper: helper,
              onChat: () => _chat(context),
              onFavorite: () => _soon(context, 'Favorit'),
            ),
            // Ukuran dari desain: margin 16 dp, teks Tentang 14 dp dengan
            // jarak baris 24 dp, kartu review berjarak 14 dp.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 25, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('Tentang'),
                  const SizedBox(height: 15),
                  Text(
                    helper.about,
                    style: AppTypography.style(
                      size: 14,
                      weight: AppTypography.regular,
                      height: 24 / 14,
                    ),
                  ),
                  const SizedBox(height: 19),
                  const _SectionTitle('Jasa'),
                  const SizedBox(height: 13),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in helper.tags) TagChip.skill(tag),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const _SectionTitle('Review'),
                  const SizedBox(height: 20),
                  if (helper.reviews.isEmpty)
                    Text(
                      'Belum ada review.',
                      style: AppTypography.style(
                        size: AppTypography.small,
                        weight: AppTypography.regular,
                        color: AppColors.textDescription,
                      ),
                    ),
                  for (final review in helper.reviews) ...[
                    _ReviewCard(review: review),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: OrderBottomBar(
          caption: 'Mulai dari',
          amount: rupiah(helper.price),
          button: PrimaryButton(
            label: 'Pesan Sekarang',
            onPressed: () => _order(context),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.helper,
    required this.onChat,
    required this.onFavorite,
  });

  final HelperListing helper;
  final VoidCallback onChat;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      // Dari desain: pusat tombol 24 dp di bawah status bar, avatar 69 dp
      // berpusat 100 dp di bawahnya, header berakhir 165 dp di bawahnya.
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 24 - OrderStyle.backSize / 2,
        16,
        30,
      ),
      child: Column(
        children: [
          Row(
            children: [
              SquareIconButton.back(context, size: OrderStyle.backSize),
              const Spacer(),
              SquareIconButton(
                label: 'Chat helper',
                size: OrderStyle.backSize,
                onTap: onChat,
                child: const OrderIcon(
                  OrderStyle.iconChat,
                  size: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 14),
              SquareIconButton(
                label: 'Simpan ke favorit',
                size: OrderStyle.backSize,
                onTap: onFavorite,
                child: const OrderIcon(
                  OrderStyle.iconHeart,
                  size: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              HelperAvatar(
                name: helper.name,
                photoUrl: helper.photoUrl,
                size: 69,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      helper.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        size: 18,
                        weight: AppTypography.semiBold,
                        color: AppColors.light,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    HelperStats(
                      rating: helper.rating,
                      completedCount: helper.completedCount,
                      pill: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.style(size: 14, weight: AppTypography.semiBold),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final HelperReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
      decoration: OrderStyle.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.author,
                  style: AppTypography.style(
                    size: 12,
                    weight: AppTypography.medium,
                    height: 1.5,
                  ),
                ),
              ),
              Text(
                review.timeAgo,
                style: AppTypography.style(
                  size: 9,
                  weight: AppTypography.regular,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          StarRow(rating: review.rating.toDouble(), size: 10, gap: 2),
          const SizedBox(height: 12),
          Text(
            review.text,
            style: AppTypography.style(
              size: 13,
              weight: AppTypography.medium,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

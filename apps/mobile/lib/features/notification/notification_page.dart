import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/empty_state.dart';
import '../household/household_models.dart' show dateLabel;
import '../order/widgets/order_widgets.dart';
import 'notification_repository.dart';

/// Daftar notifikasi, dibuka dari lonceng beranda. Mengetuk notifikasi
/// menandainya dibaca; "Tandai dibaca" menandai semuanya.
///
/// Backend baru membuat notifikasi untuk pesan chat; status pesanan dan
/// mutasi saldo menyusul (jenisnya sudah ada di `NotificationType`).
class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key, this.clock});

  /// Diisi saat pengujian. Default: jam nyata.
  final DateTime Function()? clock;

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  late final _repo = context.read<NotificationRepository>();
  late final _clock = widget.clock ?? DateTime.now;

  final _items = <AppNotification>[];
  int _unread = 0;
  int _page = 0;
  bool _hasMore = false;
  bool _loading = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final feed = await _repo.list();
      if (!mounted) return;
      setState(() {
        _unread = feed.unreadCount;
        _items
          ..clear()
          ..addAll(feed.page.items);
        _page = feed.page.page;
        _hasMore = feed.page.hasMore;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final feed = await _repo.list(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(feed.page.items);
        _page = feed.page.page;
        _hasMore = feed.page.hasMore;
      });
    } on ApiException {
      if (mounted) setState(() => _hasMore = false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Langsung tampil terbaca; dikembalikan kalau server menolak.
  Future<void> _open(int index) async {
    final item = _items[index];
    if (item.isRead) return;
    setState(() {
      _items[index] = item.markedRead(_clock());
      _unread = _unread > 0 ? _unread - 1 : 0;
    });
    try {
      await _repo.markRead(item.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _items[index] = item;
        _unread++;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _markAll() async {
    final before = List.of(_items);
    final unreadBefore = _unread;
    final now = _clock();
    setState(() {
      for (var i = 0; i < _items.length; i++) {
        _items[i] = _items[i].markedRead(now);
      }
      _unread = 0;
    });
    try {
      await _repo.markAllRead();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(before);
        _unread = unreadBefore;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.light,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              ArrowTitleBar(
                'Notifikasi',
                trailing: _unread > 0
                    ? TextButton(
                        onPressed: _markAll,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          textStyle: AppTypography.style(
                            size: 12,
                            weight: AppTypography.semiBold,
                          ),
                        ),
                        child: const Text('Tandai dibaca'),
                      )
                    : null,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: RefreshIndicator(onRefresh: _reload, child: _body()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final error = _error;
    // Tetap bisa ditarik untuk memuat ulang walau kosong atau gagal.
    Widget scrollableState(Widget child) => LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(height: box.maxHeight, child: child),
      ),
    );

    if (_items.isEmpty) {
      if (error != null) {
        return scrollableState(
          EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Notifikasi gagal dimuat',
            message: error.message,
            actionLabel: 'Coba lagi',
            onAction: _reload,
          ),
        );
      }
      if (_loading) return const Center(child: CircularProgressIndicator());
      return scrollableState(
        const EmptyState(
          icon: Icons.notifications_none_rounded,
          title: 'Belum ada notifikasi',
          message: 'Kabar pesanan dan pesan dari helper akan muncul di sini.',
        ),
      );
    }

    final now = _clock();
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 300) _loadMore();
        return false;
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          bottom: 24 + MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          return _NotificationTile(
            item: _items[index],
            now: now,
            onTap: () => _open(index),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.now,
    required this.onTap,
  });

  final AppNotification item;
  final DateTime now;
  final VoidCallback onTap;

  IconData get _icon => switch (item.type) {
    'chat_message' => Icons.chat_bubble_outline_rounded,
    'order_offer' || 'order_status_change' => Icons.receipt_long_outlined,
    'wallet_mutation' => Icons.account_balance_wallet_outlined,
    'dispute_update' => Icons.support_agent_rounded,
    'promo' => Icons.local_offer_outlined,
    _ => Icons.notifications_none_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final unread = !item.isRead;

    return Material(
      // Belum dibaca: latar pink pucat dan titik merah.
      color: unread ? const Color(0xFFFFF5F5) : AppColors.light,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 20, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTypography.style(
                        size: 13,
                        weight: unread
                            ? AppTypography.semiBold
                            : AppTypography.medium,
                        height: 1.4,
                      ),
                    ),
                    if (item.body.isNotEmpty)
                      Text(
                        item.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          size: 12,
                          weight: AppTypography.regular,
                          color: AppColors.textDescription,
                          height: 1.4,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      _relativeTime(item.createdAt, now),
                      style: AppTypography.style(
                        size: 10,
                        weight: AppTypography.regular,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Baru saja", "5 menit lalu", "3 jam lalu", "2 hari lalu", lalu tanggal.
String _relativeTime(DateTime then, DateTime now) {
  final d = now.difference(then);
  if (d.inMinutes < 1) return 'Baru saja';
  if (d.inHours < 1) return '${d.inMinutes} menit lalu';
  if (d.inDays < 1) return '${d.inHours} jam lalu';
  if (d.inDays < 7) return '${d.inDays} hari lalu';
  return dateLabel(then);
}

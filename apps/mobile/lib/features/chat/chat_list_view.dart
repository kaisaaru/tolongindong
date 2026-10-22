import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/empty_state.dart';
import '../household/household_models.dart' show clockLabel, dateLabel;
import '../order/order_style.dart';
import '../order/widgets/order_widgets.dart';
import 'chat_models.dart';
import 'chat_room_page.dart';
import 'chat_store.dart';

/// Isi tab "Obrolan": semua ruang obrolan, bisa dicari per nama helper.
///
/// Desain (frame 203) berjudul "Personal" dengan tombol kembali; di sini
/// judulnya "Obrolan" tanpa tombol kembali karena ini isi tab, sama seperti
/// tab Aktifitas.
class ChatListView extends StatefulWidget {
  const ChatListView({super.key, this.bottomPadding = 16, this.onExplore});
  final double bottomPadding;

  /// Ajakan "Cari Helper" saat belum ada obrolan, misal pindah ke Beranda.
  final VoidCallback? onExplore;

  @override
  State<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView> {
  late final _store = context.read<ChatStore>();
  String _query = '';

  void _open(ChatRoom room) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => ChatRoomPage(room: room)));

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 24, 22, widget.bottomPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Obrolan',
              style: AppTypography.style(
                size: 22,
                weight: AppTypography.semiBold,
              ),
            ),
            const SizedBox(height: 18),
            _SearchField(onChanged: (v) => setState(() => _query = v)),
            const SizedBox(height: 16),
            Expanded(
              child: ListenableBuilder(
                listenable: _store,
                builder: (context, _) => _buildList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    final all = _store.rooms;
    if (all.isEmpty) {
      return EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Belum ada obrolan',
        message:
            'Chat helper dari profilnya, sebelum atau sesudah memesan. '
            'Obrolannya tersimpan di sini.',
        actionLabel: 'Cari Helper',
        onAction: widget.onExplore,
      );
    }

    final q = _query.trim().toLowerCase();
    final rooms = [
      for (final room in all)
        if (q.isEmpty || room.peerName.toLowerCase().contains(q)) room,
    ];
    if (rooms.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Helper tidak ditemukan',
        message: 'Coba cari dengan nama lain.',
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: rooms.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _RoomTile(
        room: rooms[index],
        now: _store.now,
        onTap: () => _open(rooms[index]),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFCFCFCF)),
    );

    return TextField(
      onChanged: onChanged,
      style: AppTypography.style(size: 12, weight: AppTypography.regular),
      decoration: InputDecoration(
        hintText: 'Cari nama helper',
        isDense: true,
        filled: true,
        fillColor: AppColors.light,
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 20,
          color: AppColors.textSecondary,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room, required this.now, required this.onTap});

  final ChatRoom room;
  final DateTime now;
  final VoidCallback onTap;

  /// Hari ini: jam ("12.00"); hari lain: tanggal.
  String _timeLabel(DateTime t) =>
      DateUtils.isSameDay(t, now) ? clockLabel(t) : dateLabel(t);

  @override
  Widget build(BuildContext context) {
    final last = room.lastMessage;
    final unread = room.unreadCount;

    return DecoratedBox(
      decoration: OrderStyle.card(radius: 12),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
            child: Row(
              children: [
                HelperAvatar(
                  name: room.peerName,
                  photoUrl: room.peerPhotoUrl,
                  size: 48,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              room.peerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.style(
                                size: 13,
                                weight: AppTypography.semiBold,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _timeLabel(room.updatedAt),
                            style: AppTypography.style(
                              size: 9,
                              weight: AppTypography.regular,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              last?.preview ?? 'Mulai obrolan dengan helper',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.style(
                                size: 10,
                                weight: unread > 0
                                    ? AppTypography.semiBold
                                    : AppTypography.regular,
                                color: unread > 0
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          if (unread > 0) ...[
                            const SizedBox(width: 8),
                            _UnreadBadge(count: unread),
                          ],
                        ],
                      ),
                    ],
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

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: AppTypography.style(
          size: 9,
          weight: AppTypography.semiBold,
          color: AppColors.light,
        ),
      ),
    );
  }
}

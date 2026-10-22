import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../order/order_style.dart';
import '../order/widgets/order_widgets.dart';
import 'chat_models.dart';
import 'chat_store.dart';

/// Ruang obrolan dengan satu helper: gelembung pesan di latar pink, isian
/// pesan di bawah. Pesan terkirim lewat tombol kirim di keyboard, seperti
/// desain (tidak ada tombol kirim di layar).
class ChatRoomPage extends StatefulWidget {
  const ChatRoomPage({super.key, required this.room});

  final ChatRoom room;

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  late final _store = context.read<ChatStore>();
  final _text = TextEditingController();
  final _focus = FocusNode();

  /// Pesan helper yang belum dibaca. Pesannya baru dibaca nanti oleh
  /// helper, jadi pelanggan langsung menandai semuanya terbaca saat membuka.
  /// Ditunda satu frame: store memberi tahu daftar obrolan yang sedang
  /// dibangun.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _store.markRead(widget.room);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send(String text) {
    _store.send(widget.room, text);
    _text.clear();
    // Keyboard tetap terbuka untuk pesan berikutnya.
    _focus.requestFocus();
  }

  // Backend hanya menerima `attachment_url`, belum ada endpoint unggah
  // file, dan app belum memakai pemilih file.
  void _attach() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Kirim lampiran belum tersedia.')),
  );

  @override
  Widget build(BuildContext context) {
    final room = widget.room;

    return Scaffold(
      backgroundColor: OrderStyle.background,
      body: Column(
        children: [
          _ChatHeader(name: room.peerName, photoUrl: room.peerPhotoUrl),
          Expanded(
            child: ListenableBuilder(
              listenable: _store,
              builder: (context, _) {
                final messages = room.messages;
                // Terbalik: pesan terbaru menempel di bawah, dan daftar
                // otomatis tetap di bawah saat pesan baru masuk.
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _Bubble(
                      message: messages[messages.length - 1 - index],
                    ),
                  ),
                );
              },
            ),
          ),
          _InputBar(
            controller: _text,
            focusNode: _focus,
            onSubmitted: _send,
            onAttach: _attach,
          ),
        ],
      ),
    );
  }
}

/// Header merah: tombol kembali, foto, dan nama helper. Tingginya sama
/// dengan header Household (95 dp di bawah status bar, pusat tombol 33 dp).
class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  static const _height = 95.0;
  static const _buttonSize = 34.0;
  static const _buttonCenter = 33.0;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    const avatar = 40.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        height: top + _height,
        color: AppColors.primary,
        padding: EdgeInsets.fromLTRB(
          22,
          top + _buttonCenter - avatar / 2,
          22,
          0,
        ),
        alignment: Alignment.topLeft,
        child: Row(
          children: [
            SquareIconButton.back(context, size: _buttonSize),
            const SizedBox(width: 16),
            HelperAvatar(name: name, photoUrl: photoUrl, size: avatar),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.style(
                  size: 16,
                  weight: AppTypography.semiBold,
                  color: AppColors.light,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gelembung pesan: pelanggan di kanan (merah), helper di kiri (merah tua).
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  static const _helperColor = Color(0xFF9A1919);

  @override
  Widget build(BuildContext context) {
    final mine = message.fromMe;
    final attachment = message.attachment;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        // Di desain gelembung terlebar ±62% lebar layar.
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.62,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: mine ? AppColors.primary : _helperColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: attachment == null
                ? Text(
                    message.text!,
                    style: AppTypography.style(
                      size: 11,
                      weight: AppTypography.medium,
                      color: AppColors.light,
                      height: 1.5,
                    ),
                  )
                : _AttachmentContent(attachment: attachment),
          ),
        ),
      ),
    );
  }
}

class _AttachmentContent extends StatelessWidget {
  const _AttachmentContent({required this.attachment});

  final ChatAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Lampiran ${attachment.name}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.insert_drive_file_outlined,
            size: 34,
            color: AppColors.light,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.name,
                  style: AppTypography.style(
                    size: 11,
                    weight: AppTypography.medium,
                    color: AppColors.light,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${attachment.kind} · ${attachment.sizeLabel}',
                  style: AppTypography.style(
                    size: 9,
                    weight: AppTypography.regular,
                    color: AppColors.light.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onAttach,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFCFCFCF)),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.send,
          onSubmitted: onSubmitted,
          minLines: 1,
          maxLines: 4,
          style: AppTypography.style(size: 12, weight: AppTypography.regular),
          decoration: InputDecoration(
            hintText: 'Ketik pesan',
            filled: true,
            fillColor: AppColors.light,
            contentPadding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            enabledBorder: border,
            focusedBorder: border,
            suffixIcon: IconButton(
              tooltip: 'Lampiran',
              onPressed: onAttach,
              icon: const Icon(
                Icons.link_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

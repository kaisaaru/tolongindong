import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
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
  const ChatRoomPage({
    super.key,
    required this.room,
    this.subtitle,
    this.pinned,
  });

  final ChatRoom room;

  /// Di bawah nama, misal "Client · Delivery" di mode Helper.
  final String? subtitle;

  /// Menempel di atas pesan, misal ringkasan pesanan di mode Helper.
  final Widget? pinned;

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  /// Belum ada push notification: selama ruang terbuka, balasan helper
  /// diperiksa berkala.
  static const _pollEvery = Duration(seconds: 5);

  late final _store = context.read<ChatStore>();
  final _text = TextEditingController();
  final _focus = FocusNode();
  Timer? _poll;

  /// Pemuatan pertama; selama itu (dan belum ada pesan) tampil indikator.
  bool _loading = true;
  ApiException? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Ditunda satu frame: store memberi tahu daftar obrolan yang sedang
    // dibangun.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _poll = Timer.periodic(_pollEvery, (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Memuat isi ruang; server sekaligus menandai pesan helper terbaca.
  /// [quiet]: pemeriksaan berkala, gagalnya tidak ditampilkan.
  Future<void> _load({bool quiet = false}) async {
    if (!mounted) return;
    try {
      await _store.loadMessages(widget.room);
      if (mounted && !quiet) setState(() => _error = null);
    } on ApiException catch (e) {
      if (mounted && !quiet) setState(() => _error = e);
    } finally {
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _store.send(widget.room, text);
      _text.clear();
    } on ApiException catch (e) {
      // Teksnya tetap di kolom supaya bisa dikirim ulang.
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
    // Keyboard tetap terbuka untuk pesan berikutnya.
    if (mounted) _focus.requestFocus();
  }

  // Backend hanya menerima `attachment_url`, belum ada endpoint unggah
  // file, dan app belum memakai pemilih file.
  void _attach() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Kirim lampiran belum tersedia.')),
  );

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final pinned = widget.pinned;

    return Scaffold(
      backgroundColor: OrderStyle.background,
      body: Column(
        children: [
          _ChatHeader(
            name: room.peerName,
            photoUrl: room.peerPhotoUrl,
            subtitle: widget.subtitle,
          ),
          if (pinned != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: pinned,
            ),
          Expanded(
            child: ListenableBuilder(
              listenable: _store,
              builder: (context, _) {
                final messages = room.messages;
                if (messages.isEmpty) {
                  if (_loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return _EmptyRoom(error: _error, onRetry: _load);
                }
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
          // Ruang pesanan yang sudah selesai hanya bisa dibaca.
          if (room.isReadOnly)
            const _ReadOnlyNote()
          else
            _InputBar(
              controller: _text,
              focusNode: _focus,
              enabled: !_sending,
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
  const _ChatHeader({required this.name, this.photoUrl, this.subtitle});

  final String name;
  final String? photoUrl;
  final String? subtitle;

  static const _height = 95.0;
  static const _buttonSize = 34.0;
  static const _buttonCenter = 33.0;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    const avatar = 40.0;
    final subtitle = this.subtitle;

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      size: 16,
                      weight: AppTypography.semiBold,
                      color: AppColors.light,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        size: 10,
                        weight: AppTypography.regular,
                        color: AppColors.light.withValues(alpha: 0.9),
                      ),
                    ),
                ],
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
                  attachment.sizeLabel.isEmpty
                      ? attachment.kind
                      : '${attachment.kind} · ${attachment.sizeLabel}',
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
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onAttach;

  /// False selama pesan dikirim; keyboard tetap terbuka.
  final bool enabled;

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
          readOnly: !enabled,
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

/// Ruang yang belum berisi pesan, atau gagal dimuat.
class _EmptyRoom extends StatelessWidget {
  const _EmptyRoom({required this.error, required this.onRetry});

  final ApiException? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    final style = AppTypography.style(
      size: AppTypography.small,
      weight: AppTypography.regular,
      color: AppColors.textDescription,
      height: 1.5,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              error?.message ??
                  'Belum ada pesan. Sapa helper dan ceritakan kebutuhanmu.',
              textAlign: TextAlign.center,
              style: style,
            ),
            if (error != null)
              TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}

/// Pengganti kolom pesan di ruang pesanan yang sudah selesai.
class _ReadOnlyNote extends StatelessWidget {
  const _ReadOnlyNote();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Text(
          'Pesanan sudah selesai. Obrolan ini hanya bisa dibaca.',
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

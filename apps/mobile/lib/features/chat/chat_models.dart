// Model obrolan, mengikuti bentuk `GET /chats` (peer, last_message,
// unread_count) dan `GET /chats/rooms/{id}/messages`.

/// Lampiran pesan. Backend hanya menyimpan `attachment_url`; nama, jenis,
/// dan ukuran di sini berasal dari data contoh.
class ChatAttachment {
  const ChatAttachment({
    required this.name,
    required this.kind,
    required this.sizeLabel,
  });

  /// Misal "Tugas Kalkulus Aljabar".
  final String name;

  /// Misal "PDF".
  final String kind;

  /// Misal "3 MB".
  final String sizeLabel;
}

class ChatMessage {
  const ChatMessage({
    required this.fromMe,
    required this.sentAt,
    this.text,
    this.attachment,
  }) : assert(text != null || attachment != null);

  /// True kalau dikirim pelanggan (gelembung kanan, merah).
  final bool fromMe;
  final DateTime sentAt;
  final String? text;
  final ChatAttachment? attachment;

  /// Satu baris ringkasan untuk daftar obrolan.
  String get preview => text ?? 'Lampiran: ${attachment!.name}';
}

/// Satu ruang obrolan dengan satu helper. Pesannya bertambah saat dikirim.
class ChatRoom {
  ChatRoom({
    required this.id,
    required this.helperId,
    required this.peerName,
    required this.createdAt,
    this.peerPhotoUrl,
    List<ChatMessage>? messages,
    this.unreadCount = 0,
  }) : messages = messages ?? [];

  final String id;
  final String helperId;
  final String peerName;
  final String? peerPhotoUrl;
  final DateTime createdAt;

  /// Urut lama ke baru.
  final List<ChatMessage> messages;

  /// Pesan helper yang belum dibaca.
  int unreadCount;

  ChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  DateTime get updatedAt => lastMessage?.sentAt ?? createdAt;
}

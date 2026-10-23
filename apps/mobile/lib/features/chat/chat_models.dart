// Model obrolan, mengikuti `GET /chats` (peer, last_message, unread_count)
// dan `GET /chats/rooms/{id}/messages`.

/// Lampiran pesan. Backend hanya menyimpan `attachment_url`, jadi nama dan
/// jenisnya diambil dari alamat berkasnya.
class ChatAttachment {
  const ChatAttachment({
    required this.name,
    required this.kind,
    this.sizeLabel = '',
    this.url,
  });

  /// Dari alamat lampiran, misal `.../tugas-kalkulus.pdf` -> "tugas-kalkulus"
  /// berjenis "PDF".
  factory ChatAttachment.fromUrl(String url) {
    final file = Uri.tryParse(url)?.pathSegments.lastOrNull ?? url;
    final dot = file.lastIndexOf('.');
    return ChatAttachment(
      name: dot > 0 ? file.substring(0, dot) : file,
      kind: dot > 0 ? file.substring(dot + 1).toUpperCase() : 'Berkas',
      url: url,
    );
  }

  /// Misal "Tugas Kalkulus Aljabar".
  final String name;

  /// Misal "PDF".
  final String kind;

  /// Misal "3 MB". Kosong kalau tidak diketahui (lampiran dari server).
  final String sizeLabel;
  final String? url;
}

class ChatMessage {
  const ChatMessage({
    required this.fromMe,
    required this.sentAt,
    this.id,
    this.text,
    this.attachment,
  }) : assert(text != null || attachment != null);

  /// [myUserId]: pengguna yang masuk, untuk menentukan [fromMe].
  factory ChatMessage.fromJson(Map<String, dynamic> json, String? myUserId) {
    final url = json['attachment_url'] as String?;
    final content = json['content'] as String?;
    return ChatMessage(
      id: (json['id'] as num?)?.toInt(),
      fromMe:
          myUserId != null &&
          (json['sender_user_id'] ?? json['sender_id']) == myUserId,
      sentAt:
          DateTime.tryParse('${json['created_at']}')?.toLocal() ??
          DateTime.now(),
      text: content == null || content.isEmpty ? null : content,
      attachment: url == null || url.isEmpty
          ? null
          : ChatAttachment.fromUrl(url),
    );
  }

  final int? id;

  /// True kalau dikirim pelanggan (gelembung kanan, merah).
  final bool fromMe;
  final DateTime sentAt;
  final String? text;
  final ChatAttachment? attachment;

  /// Satu baris ringkasan untuk daftar obrolan.
  String get preview => text ?? 'Lampiran: ${attachment?.name ?? ''}';
}

/// Satu ruang obrolan dengan satu helper.
class ChatRoom {
  ChatRoom({
    required this.id,
    required this.peerName,
    required this.createdAt,
    this.helperId,
    this.peerPhotoUrl,
    this.orderId,
    this.isReadOnly = false,
    this.summary,
    List<ChatMessage>? messages,
    this.unreadCount = 0,
  }) : messages = messages ?? [];

  /// Satu baris `GET /chats`.
  factory ChatRoom.fromJson(Map<String, dynamic> json, String? myUserId) {
    final peer = (json['peer'] as Map?)?.cast<String, dynamic>();
    final last = (json['last_message'] as Map?)?.cast<String, dynamic>();
    return ChatRoom(
      id: (json['id'] as num).toInt(),
      peerName: peer?['full_name'] as String? ?? 'Helper',
      peerPhotoUrl: peer?['photo_url'] as String?,
      orderId: (json['order_id'] as num?)?.toInt(),
      isReadOnly: json['is_read_only'] as bool? ?? false,
      createdAt:
          DateTime.tryParse('${json['updated_at']}')?.toLocal() ??
          DateTime.now(),
      summary: last == null || last['content'] == null
          ? null
          : ChatMessage.fromJson(last, myUserId),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    );
  }

  final int id;

  /// Id profil helper (`helper_profiles.id`), kalau ruang dibuka dari
  /// profil helper. Daftar `GET /chats` tidak mengirimnya.
  final String? helperId;
  final String peerName;
  final String? peerPhotoUrl;
  final int? orderId;

  /// Ruang pesanan yang sudah selesai: hanya bisa dibaca.
  final bool isReadOnly;
  final DateTime createdAt;

  /// Pesan terakhir dari daftar ruang, sebelum isi ruang dimuat.
  final ChatMessage? summary;

  /// Urut lama ke baru. Kosong sampai ruangnya dibuka.
  final List<ChatMessage> messages;

  /// Pesan helper yang belum dibaca.
  int unreadCount;

  /// Yang terbaru antara isi ruang yang sudah dimuat dan ringkasan dari
  /// daftar ruang (bisa lebih baru kalau helper membalas sesudahnya).
  ChatMessage? get lastMessage {
    final loaded = messages.isEmpty ? null : messages.last;
    final latest = summary;
    if (loaded == null) return latest;
    if (latest == null) return loaded;
    return latest.sentAt.isAfter(loaded.sentAt) ? latest : loaded;
  }

  DateTime get updatedAt => lastMessage?.sentAt ?? createdAt;
}

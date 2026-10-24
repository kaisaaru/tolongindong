import 'package:mobile/core/api/api_exception.dart';
import 'package:mobile/features/chat/chat_models.dart';
import 'package:mobile/features/chat/chat_repository.dart';

/// Satu ruang di [FakeChatRepository].
class FakeRoom {
  FakeRoom({
    required this.id,
    required this.peerName,
    this.helperId,
    this.orderId,
    this.isReadOnly = false,
    this.unread = 0,
    List<ChatMessage>? messages,
  }) : messages = messages ?? [];

  final int id;
  final String peerName;
  final String? helperId;
  final int? orderId;
  final bool isReadOnly;
  int unread;
  final List<ChatMessage> messages;
}

/// Pengganti [ChatRepository] untuk widget test: ruang di memori. Setiap
/// pemanggilan mengembalikan objek baru, seperti JSON dari server.
class FakeChatRepository implements ChatRepository {
  FakeChatRepository({List<FakeRoom>? rooms, DateTime Function()? clock})
    : stored = rooms ?? [],
      _clock = clock ?? (() => DateTime(2026, 10, 22, 10));

  final List<FakeRoom> stored;
  final DateTime Function() _clock;

  /// Kalau diisi, [send] berikutnya gagal dengan error ini (sekali).
  ApiException? failNextSend;

  /// Helper yang dibukakan ruangnya lewat [startWithHelper].
  final started = <String>[];

  FakeRoom _room(int id) => stored.firstWhere((r) => r.id == id);

  ChatRoom _toRoom(FakeRoom r) => ChatRoom(
    id: r.id,
    peerName: r.peerName,
    helperId: r.helperId,
    orderId: r.orderId,
    isReadOnly: r.isReadOnly,
    createdAt: r.messages.isEmpty ? _clock() : r.messages.last.sentAt,
    summary: r.messages.lastOrNull,
    unreadCount: r.unread,
  );

  @override
  Future<List<ChatRoom>> rooms(String? myUserId) async => [
    for (final r in stored) _toRoom(r),
  ];

  @override
  Future<int> startWithHelper(String helperProfileId) async {
    started.add(helperProfileId);
    for (final r in stored) {
      if (r.helperId == helperProfileId) return r.id;
    }
    final room = FakeRoom(
      id: stored.length + 1,
      peerName: 'Agus Nomercy',
      helperId: helperProfileId,
    );
    stored.add(room);
    return room.id;
  }

  /// Pesanan yang dibukakan ruangnya lewat [roomForOrder].
  final openedOrders = <int>[];

  @override
  Future<int> roomForOrder(int orderId) async {
    openedOrders.add(orderId);
    for (final r in stored) {
      if (r.orderId == orderId) return r.id;
    }
    final room = FakeRoom(
      id: stored.length + 1,
      peerName: 'Nadia Putri',
      orderId: orderId,
    );
    stored.add(room);
    return room.id;
  }

  @override
  Future<List<ChatMessage>> messages(int roomId, String? myUserId) async {
    final room = _room(roomId)..unread = 0;
    return [...room.messages];
  }

  @override
  Future<ChatMessage> send(int roomId, String content, String? myUserId) async {
    final fail = failNextSend;
    if (fail != null) {
      failNextSend = null;
      throw fail;
    }
    final message = ChatMessage(fromMe: true, sentAt: _clock(), text: content);
    _room(roomId).messages.add(message);
    return message;
  }

  /// Helper membalas.
  void reply(int roomId, String text) {
    _room(roomId)
      ..messages.add(ChatMessage(fromMe: false, sentAt: _clock(), text: text))
      ..unread += 1;
  }
}

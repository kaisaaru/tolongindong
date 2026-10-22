import 'package:flutter/foundation.dart';

import 'chat_models.dart';
import 'chat_samples.dart';

/// Satu-satunya sumber ruang obrolan, dipakai tab Obrolan, ruang chat, dan
/// tombol "Chat helper" di profil helper.
///
/// SIMULASI: backend belum dipakai, isinya [ChatSamples]. Padanannya:
/// [rooms] = `GET /chats`, [openWithHelper] = `POST /chats/helpers/{id}`,
/// [send] = `POST /chats/rooms/{id}/messages`, dan [markRead] terjadi
/// otomatis di `GET /chats/rooms/{id}/messages`.
class ChatStore extends ChangeNotifier {
  ChatStore({List<ChatRoom>? rooms, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      _rooms = rooms ?? ChatSamples.rooms((clock ?? DateTime.now)());

  final DateTime Function() _clock;
  final List<ChatRoom> _rooms;

  DateTime get now => _clock();

  /// Yang terakhir aktif di atas.
  List<ChatRoom> get rooms =>
      [..._rooms]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  /// Ruang obrolan dengan helper ini; dibuat kalau belum ada.
  ChatRoom openWithHelper({
    required String helperId,
    required String name,
    String? photoUrl,
  }) {
    for (final room in _rooms) {
      if (room.helperId == helperId) return room;
    }
    final room = ChatRoom(
      id: 'room-$helperId',
      helperId: helperId,
      peerName: name,
      peerPhotoUrl: photoUrl,
      createdAt: _clock(),
    );
    _rooms.add(room);
    notifyListeners();
    return room;
  }

  /// Pesan kosong (hanya spasi) diabaikan.
  void send(ChatRoom room, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    room.messages.add(
      ChatMessage(fromMe: true, sentAt: _clock(), text: trimmed),
    );
    notifyListeners();
  }

  /// Kembali ke isi awal, misal saat keluar akun.
  void reset() {
    _rooms
      ..clear()
      ..addAll(ChatSamples.rooms(_clock()));
    notifyListeners();
  }

  void markRead(ChatRoom room) {
    if (room.unreadCount == 0) return;
    room.unreadCount = 0;
    notifyListeners();
  }
}

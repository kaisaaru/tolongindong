import 'package:flutter/foundation.dart';

import '../../core/api/api_exception.dart';
import 'chat_models.dart';
import 'chat_repository.dart';

/// Ruang obrolan pengguna, dipakai tab Obrolan, ruang chat, dan tombol
/// "Chat helper" di profil helper dan halaman pesanan.
///
/// Isinya dari server: [refresh] = `GET /chats`, [openWithHelper] =
/// `POST /chats/helpers/{id}`, [openForOrder] = `GET /orders/{id}/messages`,
/// [loadMessages] = `GET /chats/rooms/{id}/messages` (sekaligus menandai
/// terbaca), [send] = `POST .../messages`.
class ChatStore extends ChangeNotifier {
  ChatStore(
    this._repo, {
    String? Function()? userId,
    DateTime Function()? clock,
  }) : _userId = userId ?? (() => null),
       _clock = clock ?? DateTime.now;

  final ChatRepository _repo;
  final String? Function() _userId;
  final DateTime Function() _clock;

  final List<ChatRoom> _rooms = [];
  bool _loading = false;
  ApiException? _error;

  DateTime get now => _clock();

  /// Sedang memuat daftar ruang.
  bool get loading => _loading;

  /// Kegagalan memuat daftar ruang terakhir; null kalau berhasil.
  ApiException? get error => _error;

  /// Yang terakhir aktif di atas.
  List<ChatRoom> get rooms =>
      [..._rooms]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  int get unreadCount => _rooms.fold(0, (sum, r) => sum + r.unreadCount);

  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final fresh = await _repo.rooms(_userId());
      // Pesan ruang yang sudah dibuka dipertahankan, supaya kembali dari
      // ruang chat tidak mengosongkan isinya.
      final loaded = {for (final r in _rooms) r.id: r.messages};
      for (final r in fresh) {
        r.messages.addAll(loaded[r.id] ?? const []);
      }
      _rooms
        ..clear()
        ..addAll(fresh);
    } on ApiException catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Ruang obrolan dengan helper ini; dibuat server kalau belum ada.
  /// [helperId] adalah `helper_profiles.id`.
  Future<ChatRoom> openWithHelper({
    required String helperId,
    required String name,
    String? photoUrl,
  }) async {
    final id = await _repo.startWithHelper(helperId);
    for (final room in _rooms) {
      if (room.id == id) return room;
    }
    final room = ChatRoom(
      id: id,
      helperId: helperId,
      peerName: name,
      peerPhotoUrl: photoUrl,
      createdAt: _clock(),
    );
    _rooms.add(room);
    notifyListeners();
    return room;
  }

  /// Ruang obrolan pesanan [orderId] dengan pemesannya; dibuat server
  /// kalau belum ada. Untuk helper.
  Future<ChatRoom> openForOrder({
    required int orderId,
    required String name,
    String? photoUrl,
  }) async {
    final id = await _repo.roomForOrder(orderId);
    for (final room in _rooms) {
      if (room.id == id) return room;
    }
    final room = ChatRoom(
      id: id,
      peerName: name,
      peerPhotoUrl: photoUrl,
      orderId: orderId,
      createdAt: _clock(),
    );
    _rooms.add(room);
    notifyListeners();
    return room;
  }

  /// Isi ruang dari server. Pesan lawan bicara ikut ditandai terbaca.
  Future<void> loadMessages(ChatRoom room) async {
    final messages = await _repo.messages(room.id, _userId());
    room.messages
      ..clear()
      ..addAll(messages);
    room.unreadCount = 0;
    notifyListeners();
  }

  /// Pesan kosong (hanya spasi) diabaikan. Gagal: [ApiException] dilempar,
  /// pesannya tidak ditambahkan.
  Future<void> send(ChatRoom room, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final message = await _repo.send(room.id, trimmed, _userId());
    room.messages.add(message);
    notifyListeners();
  }

  /// Kosongkan, misal saat keluar akun.
  void reset() {
    _rooms.clear();
    _error = null;
    notifyListeners();
  }
}

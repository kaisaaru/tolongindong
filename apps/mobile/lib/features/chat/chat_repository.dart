import '../../core/api/api_client.dart';
import 'chat_models.dart';

/// Obrolan pelanggan dengan helper, sebelum maupun selama pesanan.
class ChatRepository {
  ChatRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// `GET /chats`: semua ruang, terbaru di atas. [myUserId] untuk
  /// menentukan pesan mana yang dikirim pengguna ini.
  Future<List<ChatRoom>> rooms(String? myUserId) async {
    final data = await _api.get('/chats');
    return [
      for (final e in data as List)
        ChatRoom.fromJson((e as Map).cast<String, dynamic>(), myUserId),
    ];
  }

  /// `POST /chats/helpers/{id}`: ruang dengan helper ini, dibuat kalau
  /// belum ada. [helperProfileId] adalah `helper_profiles.id`.
  Future<int> startWithHelper(String helperProfileId) async {
    final data = await _api.post('/chats/helpers/$helperProfileId');
    return ((data as Map)['room_id'] as num).toInt();
  }

  /// `GET /chats/rooms/{id}/messages`. Server sekaligus menandai pesan
  /// lawan bicara sebagai sudah dibaca.
  Future<List<ChatMessage>> messages(int roomId, String? myUserId) async {
    final data = await _api.get('/chats/rooms/$roomId/messages');
    final list = (data as Map)['messages'] as List? ?? const [];
    return [
      for (final e in list)
        ChatMessage.fromJson((e as Map).cast<String, dynamic>(), myUserId),
    ];
  }

  Future<ChatMessage> send(int roomId, String content, String? myUserId) async {
    final data = await _api.post(
      '/chats/rooms/$roomId/messages',
      body: {'content': content},
    );
    return ChatMessage.fromJson(
      (data as Map).cast<String, dynamic>(),
      myUserId,
    );
  }
}

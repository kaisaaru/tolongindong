import 'chat_models.dart';

/// Data contoh dari desain Obrolan (frame 197 dan 203).
class ChatSamples {
  const ChatSamples._();

  /// Ruang obrolan baru tiap dipanggil, karena pesannya bisa bertambah.
  /// Jam pesan relatif ke [now]: pesan terakhir pukul 12.00 hari itu.
  static List<ChatRoom> rooms(DateTime now) {
    final noon = DateTime(now.year, now.month, now.day, 12);

    return [
      ChatRoom(
        id: 'room-sample-1',
        // Sama dengan helper contoh di kategori Personal, jadi tombol
        // "Chat helper" di profilnya membuka ruang ini.
        helperId: 'sample-1',
        peerName: 'Agus Nomercy',
        createdAt: noon.subtract(const Duration(minutes: 20)),
        messages: [
          ChatMessage(
            fromMe: true,
            sentAt: noon.subtract(const Duration(minutes: 15)),
            text:
                'Hai! apakah kamu bisa mengerjakan tugas kalkulus pada '
                'materi aljabar?',
          ),
          ChatMessage(
            fromMe: false,
            sentAt: noon.subtract(const Duration(minutes: 10)),
            text: 'Ya tentu! silahkan kirimkan tugasnya',
          ),
          ChatMessage(
            fromMe: true,
            sentAt: noon.subtract(const Duration(minutes: 5)),
            attachment: const ChatAttachment(
              name: 'Tugas Kalkulus Aljabar',
              kind: 'PDF',
              sizeLabel: '3 MB',
            ),
          ),
          ChatMessage(
            fromMe: false,
            sentAt: noon,
            text: 'Baik akan saya kerjakan segera!',
          ),
        ],
      ),
    ];
  }
}

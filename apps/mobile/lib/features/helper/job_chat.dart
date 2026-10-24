import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../chat/chat_models.dart';
import '../chat/chat_room_page.dart';
import '../chat/chat_store.dart';
import '../order/order_repository.dart';
import 'widgets/helper_widgets.dart';

/// Ruang chat di mode Helper: "Client · Delivery" di bawah nama, dan
/// ringkasan pesanan di atas pesan kalau [job] diketahui.
Widget helperChatRoom(ChatRoom room, ServerOrder? job) => ChatRoomPage(
  room: room,
  subtitle: job == null
      ? 'Client'
      : 'Client · ${HelperStyle.categoryName(job.categoryCode)}',
  pinned: job == null ? null : JobChatCard(order: job),
);

/// Buka obrolan pesanan [job] dengan pemesannya. Ruangnya dibuat server
/// kalau belum ada, jadi helper bisa menyapa lebih dulu.
Future<void> openJobChat(BuildContext context, ServerOrder job) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final room = await context.read<ChatStore>().openForOrder(
      orderId: job.id,
      name: job.client?.name ?? 'Client',
      photoUrl: job.client?.photoUrl,
    );
    await navigator.push(
      MaterialPageRoute<void>(builder: (_) => helperChatRoom(room, job)),
    );
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

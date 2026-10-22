import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/storage/token_storage.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/session_store.dart';
import 'features/chat/chat_store.dart';
import 'features/home/catalog_repository.dart';
import 'features/notification/notification_repository.dart';
import 'features/order/order_store.dart';
import 'features/wallet/wallet_repository.dart';
import 'models/auth_user.dart';

/// Objek yang dipakai bersama seluruh halaman, dipasang sekali di atas
/// `MaterialApp`: satu [ApiClient] beserta repository di atasnya, sesi
/// login, dan store pesanan/obrolan.
///
/// Halaman mengambilnya lewat `context.read<T>()` untuk sekali pakai (misal
/// memanggil repository), atau `context.watch<T>()` supaya ikut dibangun
/// ulang saat isinya berubah (misal saldo di [SessionStore]).
///
/// Semua isian opsional hanya untuk pengujian dan entri debug: pengganti
/// tanpa jaringan, atau store yang sudah berisi pesanan. Store yang
/// diberikan dari luar tidak dibuang saat [AppScope] dilepas.
class AppScope extends StatelessWidget {
  const AppScope({
    super.key,
    required this.child,
    this.authRepo,
    this.catalogRepo,
    this.walletRepo,
    this.notificationRepo,
    this.orderStore,
    this.chatStore,
    this.user,
  });

  final Widget child;
  final AuthRepository? authRepo;
  final CatalogRepository? catalogRepo;
  final WalletRepository? walletRepo;
  final NotificationRepository? notificationRepo;
  final OrderStore? orderStore;
  final ChatStore? chatStore;

  /// Pengguna yang sudah masuk sejak awal, tanpa lewat login.
  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    final orders = orderStore;
    final chats = chatStore;

    return MultiProvider(
      providers: [
        Provider(create: (_) => TokenStorage()),
        Provider(create: (c) => ApiClient(storage: c.read<TokenStorage>())),
        Provider<AuthRepository>(
          create: (c) =>
              authRepo ??
              AuthRepository(
                api: c.read<ApiClient>(),
                storage: c.read<TokenStorage>(),
              ),
        ),
        Provider<CatalogRepository>(
          create: (c) => catalogRepo ?? CatalogRepository(api: c.read()),
        ),
        Provider<WalletRepository>(
          create: (c) => walletRepo ?? WalletRepository(api: c.read()),
        ),
        Provider<NotificationRepository>(
          create: (c) =>
              notificationRepo ?? NotificationRepository(api: c.read()),
        ),
        ChangeNotifierProvider(
          create: (c) => SessionStore(c.read<AuthRepository>(), user: user),
        ),
        if (orders == null)
          ChangeNotifierProvider(create: (_) => OrderStore())
        else
          ChangeNotifierProvider.value(value: orders),
        if (chats == null)
          ChangeNotifierProvider(create: (_) => ChatStore())
        else
          ChangeNotifierProvider.value(value: chats),
      ],
      child: child,
    );
  }
}

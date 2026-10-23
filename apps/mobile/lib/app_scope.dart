import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/media/photo_picker.dart';
import 'core/storage/token_storage.dart';
import 'features/address/address_repository.dart';
import 'features/address/location_service.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/session_store.dart';
import 'features/chat/chat_repository.dart';
import 'features/chat/chat_store.dart';
import 'features/helper/helper_store.dart';
import 'features/helper/helper_work_repository.dart';
import 'features/home/catalog_repository.dart';
import 'features/notification/notification_repository.dart';
import 'features/order/helper_repository.dart';
import 'features/order/order_repository.dart';
import 'features/order/order_store.dart';
import 'features/wallet/wallet_repository.dart';
import 'models/auth_user.dart';

/// Objek yang dipakai bersama seluruh halaman, dipasang sekali di atas
/// `MaterialApp`: satu [ApiClient] beserta repository di atasnya, sesi
/// login, dan store pesanan, obrolan, dan mode Helper.
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
    this.helperRepo,
    this.addressRepo,
    this.orderRepo,
    this.chatRepo,
    this.locationService,
    this.helperWorkRepo,
    this.photoPicker,
    this.orderStore,
    this.chatStore,
    this.helperStore,
    this.user,
  });

  final Widget child;
  final AuthRepository? authRepo;
  final CatalogRepository? catalogRepo;
  final WalletRepository? walletRepo;
  final NotificationRepository? notificationRepo;
  final HelperRepository? helperRepo;
  final AddressRepository? addressRepo;
  final OrderRepository? orderRepo;
  final ChatRepository? chatRepo;
  final LocationService? locationService;
  final HelperWorkRepository? helperWorkRepo;
  final PhotoPicker? photoPicker;
  final OrderStore? orderStore;
  final ChatStore? chatStore;
  final HelperStore? helperStore;

  /// Pengguna yang sudah masuk sejak awal, tanpa lewat login.
  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    final orders = orderStore;
    final chats = chatStore;
    final helper = helperStore;

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
        Provider<HelperRepository>(
          create: (c) => helperRepo ?? HelperRepository(api: c.read()),
        ),
        Provider<AddressRepository>(
          create: (c) => addressRepo ?? AddressRepository(api: c.read()),
        ),
        Provider<OrderRepository>(
          create: (c) => orderRepo ?? OrderRepository(api: c.read()),
        ),
        Provider<ChatRepository>(
          create: (c) => chatRepo ?? ChatRepository(api: c.read()),
        ),
        Provider<LocationService>(
          create: (_) => locationService ?? LocationService(),
        ),
        Provider<HelperWorkRepository>(
          create: (c) => helperWorkRepo ?? HelperWorkRepository(api: c.read()),
        ),
        Provider<PhotoPicker>(create: (_) => photoPicker ?? PhotoPicker()),
        ChangeNotifierProvider(
          create: (c) => SessionStore(c.read<AuthRepository>(), user: user),
        ),
        if (orders == null)
          ChangeNotifierProvider(
            create: (c) => OrderStore(c.read<OrderRepository>()),
          )
        else
          ChangeNotifierProvider.value(value: orders),
        if (chats == null)
          ChangeNotifierProvider(
            // Pesan "dari saya" ditentukan dari pengguna yang sedang masuk.
            create: (c) => ChatStore(
              c.read<ChatRepository>(),
              userId: () => c.read<SessionStore>().user?.id,
            ),
          )
        else
          ChangeNotifierProvider.value(value: chats),
        if (helper == null)
          ChangeNotifierProvider(
            create: (c) => HelperStore(c.read<HelperWorkRepository>()),
          )
        else
          ChangeNotifierProvider.value(value: helper),
      ],
      child: child,
    );
  }
}

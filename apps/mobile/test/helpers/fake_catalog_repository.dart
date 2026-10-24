import 'package:mobile/features/home/catalog_repository.dart';
import 'package:mobile/models/service_category.dart';

/// Pengganti [CatalogRepository] untuk widget test: tidak menyentuh jaringan.
class FakeCatalogRepository implements CatalogRepository {
  FakeCatalogRepository({
    this.result = const [],
    this.address,
    this.unreadCount = 0,
  });

  final List<ServiceCategory> result;
  final String? address;
  final int unreadCount;

  @override
  Future<List<ServiceCategory>> categories() async => result;

  @override
  Future<String?> primaryAddress() async => address;

  @override
  Future<int> unreadNotificationCount() async => unreadCount;
}

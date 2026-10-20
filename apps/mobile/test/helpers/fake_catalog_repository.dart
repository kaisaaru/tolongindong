import 'package:mobile/features/home/catalog_repository.dart';
import 'package:mobile/models/service_category.dart';

/// Pengganti [CatalogRepository] untuk widget test: tidak menyentuh jaringan.
class FakeCatalogRepository implements CatalogRepository {
  FakeCatalogRepository({this.result = const []});

  final List<ServiceCategory> result;

  @override
  Future<List<ServiceCategory>> categories() async => result;
}

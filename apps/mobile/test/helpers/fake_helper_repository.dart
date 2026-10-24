import 'package:mobile/core/api/api_exception.dart';
import 'package:mobile/features/household/household_models.dart';
import 'package:mobile/features/order/helper_repository.dart';
import 'package:mobile/features/order/order_models.dart';

import 'test_data.dart';

/// Pengganti [HelperRepository] untuk widget test.
class FakeHelperRepository implements HelperRepository {
  FakeHelperRepository({
    this.hourlyResult = testHelpers,
    this.listingResult = testListings,
    this.error,
  });

  List<HourlyHelper> hourlyResult;
  List<HelperListing> listingResult;

  /// Kalau diisi, setiap pemanggilan gagal dengan error ini.
  ApiException? error;

  /// Kategori yang diminta, berurutan.
  final requested = <int>[];

  @override
  Future<List<HourlyHelper>> hourly(int categoryId) async {
    requested.add(categoryId);
    if (error case final e?) throw e;
    return hourlyResult;
  }

  @override
  Future<List<HelperListing>> listings(int categoryId) async {
    requested.add(categoryId);
    if (error case final e?) throw e;
    return listingResult;
  }
}

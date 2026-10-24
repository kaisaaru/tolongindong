import 'package:mobile/features/address/location_service.dart';

/// Pengganti [LocationService]: koordinat tetap, atau [error].
class FakeLocationService implements LocationService {
  FakeLocationService({this.error});

  LocationException? error;

  @override
  Future<({double latitude, double longitude})> current() async {
    if (error case final e?) throw e;
    return (latitude: -6.9175, longitude: 107.6191);
  }
}

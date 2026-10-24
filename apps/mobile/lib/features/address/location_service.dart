import 'package:geolocator/geolocator.dart';

/// Lokasi perangkat untuk alamat baru. Dibungkus supaya bisa diganti versi
/// palsu saat pengujian (lewat `AppScope`).
class LocationService {
  /// Koordinat saat ini. Gagal: [LocationException] berisi pesan untuk
  /// pengguna (GPS mati, izin ditolak, atau sinyal lemah).
  Future<({double latitude, double longitude})> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(
        'Layanan lokasi di HP sedang mati. Nyalakan GPS dulu.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Izin lokasi ditolak. Aktifkan lewat Pengaturan HP.',
      );
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException('Izin lokasi ditolak.');
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return (latitude: position.latitude, longitude: position.longitude);
    } on Exception {
      throw const LocationException(
        'Lokasi belum didapat. Coba di tempat terbuka, lalu ulangi.',
      );
    }
  }
}

class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

import 'package:image_picker/image_picker.dart';

/// Foto yang dipilih: lokasi file di perangkat dan namanya.
typedef PickedPhoto = ({String path, String name});

/// Ambil foto dari kamera atau galeri. Dibungkus supaya bisa diganti versi
/// palsu saat pengujian (lewat `AppScope`).
class PhotoPicker {
  PhotoPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Null kalau dibatalkan. Diperkecil supaya ringan saat nanti diunggah.
  Future<PickedPhoto?> pick({required bool camera}) async {
    final file = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (file == null) return null;
    return (path: file.path, name: file.name);
  }
}

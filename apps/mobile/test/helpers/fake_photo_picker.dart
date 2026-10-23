import 'package:mobile/core/media/photo_picker.dart';

/// Pengganti [PhotoPicker]: mengembalikan [result] tanpa kamera.
class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker({this.result = (path: '/tmp/bukti.jpg', name: 'bukti.jpg')});

  PickedPhoto? result;

  /// Sumber tiap pemanggilan: true = kamera.
  final sources = <bool>[];

  @override
  Future<PickedPhoto?> pick({required bool camera}) async {
    sources.add(camera);
    return result;
  }
}

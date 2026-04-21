import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerService {
  static final ImagePickerService _instance = ImagePickerService._internal();
  static ImagePickerService? _mockInstance;

  factory ImagePickerService() {
    return _mockInstance ?? _instance;
  }

  ImagePickerService._internal();

  /// For subclassing in tests only.
  @visibleForTesting
  ImagePickerService.forTesting();

  @visibleForTesting
  static void setMockInstance(ImagePickerService? instance) {
    _mockInstance = instance;
  }

  final _picker = ImagePicker();

  /// Returns a single image from the camera, or null if the user cancels or
  /// denies permission (ImagePicker's native behavior — no extra permission
  /// logic needed per AD-3).
  Future<XFile?> pickFromCamera() async {
    return _picker.pickImage(source: ImageSource.camera);
  }

  /// Returns up to [maxCount] images from the gallery.  Returns an empty list
  /// if the user cancels.  The cap is enforced via `.take(maxCount)` on the
  /// result so it works regardless of the OS picker's own limit support.
  Future<List<XFile>> pickFromGallery({int maxCount = 5}) async {
    final results = await _picker.pickMultiImage();
    if (results.isEmpty) return [];
    return results.take(maxCount).toList();
  }
}

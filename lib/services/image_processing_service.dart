import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class OversizeImageException implements Exception {
  final String originalName;
  final int sizeBytes;

  OversizeImageException(this.originalName, this.sizeBytes);

  @override
  String toString() =>
      'Image too large after compression: ${sizeBytes ~/ 1024}KB (max 1536KB) — $originalName';
}

class ImageProcessingService {
  static final ImageProcessingService _instance = ImageProcessingService._internal();
  static ImageProcessingService? _mockInstance;

  factory ImageProcessingService() {
    return _mockInstance ?? _instance;
  }

  ImageProcessingService._internal();

  @visibleForTesting
  static void setMockInstance(ImageProcessingService? instance) {
    _mockInstance = instance;
  }

  /// Reads [picked], applies AD-5 pass-through rule, compresses if needed, and
  /// returns JPEG bytes.  Throws [OversizeImageException] if the result exceeds
  /// 1.5 MB after compression.
  Future<Uint8List> processPickedImage(XFile picked) async {
    final bytes = await picked.readAsBytes();

    // AD-5 pass-through: skip re-encoding for small images.
    // We use byte-length as a proxy (≤ 512 KB) to avoid decoding just for
    // dimension inspection.  HEIC files always go through compression so they
    // are converted to JPEG.
    final isHeic = picked.name.toLowerCase().endsWith('.heic') ||
        picked.mimeType?.toLowerCase() == 'image/heic';

    if (!isHeic && bytes.length <= 512 * 1024) {
      // Small non-HEIC image: return raw bytes (pass-through).
      return bytes;
    }

    // Compress / convert to JPEG.
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 1600,
      minHeight: 1600,
      quality: 85,
      format: CompressFormat.jpeg,
      keepExif: false,
    );

    final result = Uint8List.fromList(compressed);

    if (result.length > 1_500_000) {
      throw OversizeImageException(picked.name, result.length);
    }

    return result;
  }

  /// Returns a pure base64 string (no `data:` URI prefix).
  String toBase64(Uint8List bytes) => base64Encode(bytes);
}

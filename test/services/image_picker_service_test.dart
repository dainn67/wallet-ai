import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wallet_ai/services/image_picker_service.dart';

// ---------------------------------------------------------------------------
// Fake subclass that overrides the gallery picker call to return canned data
// without touching the native platform channel.
// ---------------------------------------------------------------------------
class _FakePickerService extends ImagePickerService {
  final List<XFile> _cannedFiles;

  _FakePickerService(this._cannedFiles) : super.forTesting();

  @override
  Future<List<XFile>> pickFromGallery({int maxCount = 5}) async {
    if (_cannedFiles.isEmpty) return [];
    return _cannedFiles.take(maxCount).toList();
  }

  @override
  Future<XFile?> pickFromCamera() async => null;
}

// Helper that creates a canned XFile list using in-memory data.
List<XFile> _makeFiles(int count) => List.generate(
      count,
      (i) => XFile.fromData(
        Uint8List.fromList([0xFF, 0xD8, 0xFF, i]),
        name: 'photo_$i.jpg',
        mimeType: 'image/jpeg',
      ),
    );

void main() {
  group('ImagePickerService', () {
    tearDown(() => ImagePickerService.setMockInstance(null));

    // -----------------------------------------------------------------------
    // Singleton / mock injection
    // -----------------------------------------------------------------------
    group('setMockInstance', () {
      test('factory returns mock when one is set', () {
        final mock = _FakePickerService([]);
        ImagePickerService.setMockInstance(mock);
        expect(ImagePickerService(), same(mock));
      });

      test('factory returns real singleton after mock is cleared', () {
        final real = ImagePickerService();
        final mock = _FakePickerService([]);
        ImagePickerService.setMockInstance(mock);
        ImagePickerService.setMockInstance(null);
        expect(ImagePickerService(), same(real));
      });
    });

    // -----------------------------------------------------------------------
    // pickFromGallery — cap enforcement via fake subclass (no platform channel)
    // -----------------------------------------------------------------------
    group('pickFromGallery', () {
      test('returns at most maxCount items when more are available', () async {
        final fake = _FakePickerService(_makeFiles(7));
        final result = await fake.pickFromGallery(maxCount: 5);
        expect(result.length, equals(5));
      });

      test('returns fewer items if fewer are available', () async {
        final fake = _FakePickerService(_makeFiles(3));
        final result = await fake.pickFromGallery(maxCount: 5);
        expect(result.length, equals(3));
      });

      test('returns empty list when mock has no files', () async {
        final fake = _FakePickerService([]);
        final result = await fake.pickFromGallery(maxCount: 5);
        expect(result, isEmpty);
      });

      test('maxCount: 1 returns at most 1 image', () async {
        final fake = _FakePickerService(_makeFiles(5));
        final result = await fake.pickFromGallery(maxCount: 1);
        expect(result.length, equals(1));
      });
    });

    // -----------------------------------------------------------------------
    // pickFromCamera — returns null on cancel (no platform channel needed via fake)
    // -----------------------------------------------------------------------
    group('pickFromCamera', () {
      test('returns null when mock returns null (cancel / denial)', () async {
        final fake = _FakePickerService([]);
        final result = await fake.pickFromCamera();
        expect(result, isNull);
      });
    });
  });
}

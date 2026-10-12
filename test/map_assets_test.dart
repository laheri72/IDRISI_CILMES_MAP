import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> decodeAsset(String path) async {
  final bytes = await rootBundle.load(path);
  final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('overview maps and edge tiles decode at the expected sizes', () async {
    for (final entry in [
      ('ar', 2048, 1012, 11, 5, 176, 534),
      ('en', 2048, 939, 12, 5, 711, 838),
    ]) {
      final (
        language,
        previewWidth,
        previewHeight,
        lastColumn,
        lastRow,
        edgeWidth,
        edgeHeight
      ) = entry;
      final preview =
          await decodeAsset('assets/maps/previews/idrisi_map_$language.webp');
      expect(preview.width, previewWidth);
      expect(preview.height, previewHeight);
      preview.dispose();

      final firstTile =
          await decodeAsset('assets/maps/tiles/$language/0-0.webp');
      expect(firstTile.width, 1024);
      expect(firstTile.height, 1024);
      firstTile.dispose();

      final edgeTile = await decodeAsset(
          'assets/maps/tiles/$language/$lastColumn-$lastRow.webp');
      expect(edgeTile.width, edgeWidth);
      expect(edgeTile.height, edgeHeight);
      edgeTile.dispose();
    }
  });
}

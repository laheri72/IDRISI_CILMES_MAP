import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idrisi_map_app/models/city_model.dart';
import 'package:idrisi_map_app/providers/map_providers.dart';
import 'package:idrisi_map_app/services/city_overrides.dart';
import 'package:idrisi_map_app/services/city_storage_service.dart';
import 'package:idrisi_map_app/utils/map_coordinates.dart';

class _FailingStorage extends CityStorageService {
  @override
  Future<List<City>> loadMergedCities() async => [sampleCity()];

  @override
  Future<SaveResult> saveUpdatedCities(List<City> cities) async =>
      const SaveResult(false, 'write failed');
}

City sampleCity({
  String id = 'jarma',
  double? px = 0.1,
  double? py = 0.2,
}) {
  return City(
    id: id,
    name: 'Jarmā al-Kubrā',
    arabicName: 'جرمى كبرى',
    clime: 1,
    history: 'history text',
    idrisiHint: 'hint text',
    modernLat: 26.5333,
    modernLng: 13.0667,
    px: px,
    py: py,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled cities have no historical pins', () async {
    final raw = await rootBundle.loadString('assets/data/cities.json');
    final cities = (jsonDecode(raw) as List<dynamic>)
        .map((value) => City.fromJson(value as Map<String, dynamic>))
        .toList();
    expect(cities, hasLength(60));
    expect(cities.where((city) => city.isPinned), isEmpty);
  });

  test('clear writes an empty pin set that stays empty after reload', () async {
    final base = [sampleCity(px: null, py: null)];
    String? current;
    final service = CityStorageService(
      loadBaseAsset: () async =>
          jsonEncode(base.map((city) => city.toJson()).toList()),
      readRawOverride: () async => current,
      writeRawOverride: (raw) async {
        current = raw;
        return true;
      },
    );

    expect((await service.loadMergedCities()).where((city) => city.isPinned),
        isEmpty);
    expect(
        (await service.saveUpdatedCities([
          base.single.copyWith(px: 0.6, py: 0.7),
        ]))
            .success,
        isTrue);
    expect((await service.loadMergedCities()).single.isPinned, isTrue);
    expect((await service.clearOverrides()).success, isTrue);
    expect(current, '{}');
    expect((await service.loadMergedCities()).single.isPinned, isFalse);
  });

  group('City JSON round-trip', () {
    test('preserves pinned coordinates', () {
      final city = sampleCity(px: 0.123, py: 0.456);
      final restored = City.fromJson(city.toJson());
      expect(restored.px, 0.123);
      expect(restored.py, 0.456);
      expect(restored.id, city.id);
      expect(restored.clime, city.clime);
      expect(restored.arabicName, city.arabicName);
    });

    test('preserves null (unpinned) coordinates', () {
      final city = sampleCity(px: null, py: null);
      expect(city.isPinned, isFalse);
      final restored = City.fromJson(city.toJson());
      expect(restored.px, isNull);
      expect(restored.py, isNull);
      expect(restored.isPinned, isFalse);
    });

    test('copyWith changes only the requested coordinate', () {
      final city = sampleCity(px: 0.1, py: 0.2);
      final moved = city.copyWith(px: 0.9);
      expect(moved.px, 0.9);
      expect(moved.py, 0.2); // unchanged
    });
  });

  group('Override merge', () {
    test('applies saved coordinates over bundled ones', () {
      final base = [sampleCity(id: 'a', px: 0.1, py: 0.1)];
      final overrides = {
        'a': (px: 0.75, py: 0.85),
      };
      final merged = mergeCityOverrides(base, overrides);
      expect(merged.single.px, 0.75);
      expect(merged.single.py, 0.85);
    });

    test('leaves cities without an override untouched', () {
      final base = [
        sampleCity(id: 'a', px: 0.1, py: 0.1),
        sampleCity(id: 'b', px: null, py: null),
      ];
      final overrides = {
        'a': (px: 0.5, py: 0.5),
      };
      final merged = mergeCityOverrides(base, overrides);
      expect(merged.first.px, 0.5);
      expect(merged[1].px, isNull); // b untouched, still unpinned
    });
  });

  group('Saved pin overrides', () {
    test('stores only pins changed from the bundled data', () {
      final base = [
        sampleCity(id: 'same'),
        sampleCity(id: 'moved'),
        sampleCity(id: 'new', px: null, py: null),
      ];
      final current = [
        base[0],
        base[1].copyWith(px: 0.8),
        base[2].copyWith(px: 0.4, py: 0.6),
      ];
      final changes = changedCityPins(base, current);
      expect(changes.keys, containsAll(['moved', 'new']));
      expect(changes, isNot(contains('same')));
      expect(changes['moved'], (px: 0.8, py: 0.2));
    });

    test('rejects invalid saved coordinates', () {
      final decoded = decodeCityOverrides(
        '{"good":{"px":0.25,"py":0.75},'
        '"bad":{"px":1.5,"py":0.5},"partial":{"px":0.3}}',
      );
      expect(decoded.keys, ['good']);
    });
  });

  test('map calibration preserves positions through both toggle directions',
      () {
    for (final point in [
      (px: 0.1, py: 0.15),
      (px: 0.25, py: 0.4),
      (px: 0.5, py: 0.5),
      (px: 0.75, py: 0.7),
      (px: 0.9, py: 0.9),
    ]) {
      final english =
          MapCoordinates.forDisplay(point.px, point.py, english: true);
      expect(english.px, closeTo(point.px, 0.03));
      expect(english.py, closeTo(point.py, 0.07));
      final restored =
          MapCoordinates.fromDisplay(english.px, english.py, english: true);
      expect(restored.px, closeTo(point.px, 1e-7));
      expect(restored.py, closeTo(point.py, 1e-7));
    }
  });

  test('unmatched scan borders cannot receive shared pins', () {
    expect(MapCoordinates.isOnBothMaps(0.5, 0.5), isTrue);
    expect(MapCoordinates.isOnBothMaps(0.5, 0), isFalse);
    expect(MapCoordinates.isOnBothMaps(0.5, 1), isFalse);
  });

  test('failed pin save restores the previous provider state', () async {
    final provider =
        StateNotifierProvider<CitiesNotifier, AsyncValue<List<City>>>(
      (ref) => CitiesNotifier(_FailingStorage()),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(provider.notifier);
    await notifier.loadCities();

    final result = await notifier.updateCityLocations({
      'jarma': (px: 0.8, py: 0.9),
    });

    expect(result.success, isFalse);
    expect(container.read(provider).value!.single.px, 0.1);
    expect(container.read(provider).value!.single.py, 0.2);
  });

  test('storage saves, reloads, and clears only changed pins', () async {
    final base = [sampleCity(id: 'same'), sampleCity(id: 'moved')];
    String? stored;
    final service = CityStorageService(
      loadBaseAsset: () async =>
          jsonEncode(base.map((city) => city.toJson()).toList()),
      readRawOverride: () async => stored,
      writeRawOverride: (raw) async {
        stored = raw;
        return true;
      },
    );

    final result = await service.saveUpdatedCities([
      base[0],
      base[1].copyWith(px: 0.8, py: 0.9),
    ]);
    expect(result.success, isTrue);
    expect((jsonDecode(stored!) as Map<String, dynamic>).keys, ['moved']);
    expect((await service.loadMergedCities())[1].px, 0.8);

    expect((await service.clearOverrides()).success, isTrue);
    expect((await service.loadMergedCities())[1].px, 0.1);
  });

  test('storage rejects a write that reads back different coordinates',
      () async {
    final base = [sampleCity()];
    String? stored;
    final service = CityStorageService(
      loadBaseAsset: () async =>
          jsonEncode(base.map((city) => city.toJson()).toList()),
      readRawOverride: () async => stored,
      writeRawOverride: (raw) async {
        stored = '{"jarma":{"px":0.3,"py":0.4}}';
        return true;
      },
    );

    final result = await service.saveUpdatedCities([
      base.single.copyWith(px: 0.8, py: 0.9),
    ]);
    expect(result.success, isFalse);
  });
}

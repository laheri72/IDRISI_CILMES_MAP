import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/city_model.dart';
import 'city_overrides.dart';

/// Result of a persistence operation, carrying a human-readable reason so the
/// UI can surface exactly what went wrong instead of failing silently.
class SaveResult {
  final bool success;
  final String? error;

  const SaveResult(this.success, [this.error]);

  static const SaveResult ok = SaveResult(true);
}

/// Loads the bundled city dataset and layers user-authored pin-position
/// overrides on top of it.
///
/// Only the *coordinates* are persisted (a compact `id -> {px,py}` map), keyed
/// per-platform:
/// Web -> a single key in [SharedPreferences] (localStorage).
///
/// Every write is verified by reading it back, so a save only reports success
/// when the data can actually be reloaded.
class CityStorageService {
  static const String _defaultAssetPath = 'assets/data/cities.json';
  static const String _webPrefsKey = 'al_idrisi_pin_overrides_v3';
  static const _legacyWebPrefsKeys = [
    'al_idrisi_pin_overrides_v1',
    'al_idrisi_pin_overrides_v2',
  ];

  final Future<String> Function()? _loadBaseAsset;
  final Future<String?> Function()? _readRawOverride;
  final Future<bool> Function(String)? _writeRawOverride;
  bool _legacyChecked = false;

  CityStorageService({
    Future<String> Function()? loadBaseAsset,
    Future<String?> Function()? readRawOverride,
    Future<bool> Function(String)? writeRawOverride,
  })  : _loadBaseAsset = loadBaseAsset,
        _readRawOverride = readRawOverride,
        _writeRawOverride = writeRawOverride;

  /// Human-readable description of where overrides are stored, for diagnostics.
  String get storageDescription => 'web localStorage ("$_webPrefsKey")';

  Future<List<City>> _loadBaseCities() async {
    debugPrint(
        '[CityStorageService] Loading base asset from $_defaultAssetPath');
    final String assetString = await (_loadBaseAsset?.call() ??
        rootBundle.loadString(_defaultAssetPath));
    final List<dynamic> assetJson = jsonDecode(assetString) as List<dynamic>;
    return assetJson
        .map((e) => City.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Loads the bundled cities and applies any saved coordinate overrides.
  Future<List<City>> loadMergedCities() async {
    final baseCities = await _loadBaseCities();

    final overrides = await _readOverrides();

    if (overrides.isEmpty) {
      return baseCities;
    }

    debugPrint(
      '[CityStorageService] Applying ${overrides.length} saved override(s).',
    );

    return mergeCityOverrides(baseCities, overrides);
  }

  /// Old trial pins are intentionally retired. A new v3 store starts empty,
  /// while these removals prevent stale v1/v2 values from surviving in the browser.
  Future<void> _discardLegacyOverrides() async {
    if (_legacyChecked || _readRawOverride != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in _legacyWebPrefsKeys) {
        if (prefs.containsKey(key)) await prefs.remove(key);
      }
      _legacyChecked = true;
    } catch (error, stackTrace) {
      debugPrint('[CityStorageService] Could not remove old trial pins: '
          '$error\n$stackTrace');
    }
  }

  /// Reads saved coordinate overrides into a map keyed by city id.
  Future<Map<String, PinPosition>> _readOverrides() async {
    try {
      await _discardLegacyOverrides();
      String? raw;
      if (_readRawOverride != null) {
        raw = await _readRawOverride!();
      } else {
        final prefs = await SharedPreferences.getInstance();
        raw = prefs.getString(_webPrefsKey);
      }

      return raw == null || raw.isEmpty ? {} : decodeCityOverrides(raw);
    } catch (e, stackTrace) {
      debugPrint(
          '[CityStorageService] Error reading overrides: $e\n$stackTrace');
    }

    return {};
  }

  /// Persists only coordinates that differ from the bundled city data.
  ///
  /// Stores only a compact override map (not full city records), then reads it
  /// back to verify the write succeeded before reporting success.
  Future<SaveResult> saveUpdatedCities(List<City> cities) async {
    try {
      final overrides = changedCityPins(await _loadBaseCities(), cities);
      final String encodedJson = jsonEncode({
        for (final entry in overrides.entries)
          entry.key: {'px': entry.value.px, 'py': entry.value.py},
      });

      if (_writeRawOverride != null) {
        if (!await _writeRawOverride!(encodedJson)) {
          return const SaveResult(false, 'Storage rejected the write.');
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        final success = await prefs.setString(_webPrefsKey, encodedJson);
        if (!success) {
          return const SaveResult(false, 'Browser storage rejected the write.');
        }
      }

      // Verify by reading back what we just wrote.
      final verified = await _readOverrides();
      final matches = verified.length == overrides.length &&
          overrides.entries
              .every((entry) => verified[entry.key] == entry.value);
      if (!matches) {
        return SaveResult(
          false,
          'Verification failed: saved pin positions did not match storage.',
        );
      }

      debugPrint(
        '[CityStorageService] Saved and verified ${overrides.length} pin(s).',
      );
      return SaveResult.ok;
    } catch (e, stackTrace) {
      debugPrint('[CityStorageService] Error saving cities: $e\n$stackTrace');
      return SaveResult(false, '$e');
    }
  }

  /// Writes an empty v3 override set so old pin stores cannot be read again.
  Future<SaveResult> clearOverrides() async {
    try {
      final result = await saveUpdatedCities(const <City>[]);
      if (!result.success) return result;
      if ((await _readOverrides()).isNotEmpty) {
        return const SaveResult(
            false, 'Could not verify that pins were reset.');
      }
      debugPrint('[CityStorageService] Cleared overrides.');
      return SaveResult.ok;
    } catch (e, stackTrace) {
      debugPrint(
          '[CityStorageService] Error clearing overrides: $e\n$stackTrace');
      return SaveResult(false, '$e');
    }
  }
}

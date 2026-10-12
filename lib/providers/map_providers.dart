import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/city_model.dart';
import '../models/clime_model.dart';
import '../services/city_storage_service.dart';

final cityStorageServiceProvider = Provider<CityStorageService>((ref) {
  return CityStorageService();
});

/// Holds the merged city dataset (bundled data + saved pin overrides).
final citiesProvider =
    StateNotifierProvider<CitiesNotifier, AsyncValue<List<City>>>((ref) {
  final storageService = ref.watch(cityStorageServiceProvider);
  return CitiesNotifier(storageService);
});

class CitiesNotifier extends StateNotifier<AsyncValue<List<City>>> {
  final CityStorageService _storageService;

  CitiesNotifier(this._storageService) : super(const AsyncValue.loading()) {
    loadCities();
  }

  /// Loads the initial (merged) city dataset on startup.
  Future<void> loadCities() async {
    state = const AsyncValue.loading();
    try {
      final cities = await _storageService.loadMergedCities();
      state = AsyncValue.data(cities);
    } catch (error, stack) {
      debugPrint('[CitiesNotifier] Failed to load cities: $error\n$stack');
      state = AsyncValue.error(error, stack);
    }
  }

  /// Saves a batch of pin changes and rolls back the optimistic state on error.
  Future<SaveResult> updateCityLocations(
      Map<String, ({double px, double py})> updates) async {
    final currentState = state;
    if (!currentState.hasValue || currentState.value == null) {
      return const SaveResult(false, 'City data is not loaded yet.');
    }

    final currentCities = currentState.value!;

    final List<City> updatedCities = currentCities.map((city) {
      final newCoords = updates[city.id];
      if (newCoords != null) {
        return city.copyWith(px: newCoords.px, py: newCoords.py);
      }
      return city;
    }).toList();

    // Push to state synchronously to avoid UI snap-back.
    state = AsyncValue.data(updatedCities);
    debugPrint('[CitiesNotifier] In-memory state updated synchronously.');

    final result = await _storageService.saveUpdatedCities(updatedCities);
    if (!result.success) {
      state = AsyncValue.data(currentCities);
    }
    return result;
  }

  /// Discards all saved pin overrides and reloads the bundled dataset.
  Future<SaveResult> resetToDefaults() async {
    final result = await _storageService.clearOverrides();
    if (result.success) {
      await loadCities();
      if (state.hasError || !state.hasValue) {
        return const SaveResult(
            false, 'Could not reload cities after clearing pins.');
      }
    }
    return result;
  }
}

/// Loads the climes represented by the bundled city dataset.
final climesProvider = FutureProvider<List<ClimeModel>>((ref) async {
  final String raw = await rootBundle.loadString('assets/data/climes.json');
  final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
  return decoded
      .map((e) => ClimeModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

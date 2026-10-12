import 'dart:convert';

import '../models/city_model.dart';

typedef PinPosition = ({double px, double py});

/// Applies saved pin edits without replacing city content from the app bundle.
List<City> mergeCityOverrides(
  List<City> baseCities,
  Map<String, PinPosition> overrides,
) {
  return baseCities.map((city) {
    final pin = overrides[city.id];
    return pin == null ? city : city.copyWith(px: pin.px, py: pin.py);
  }).toList();
}

/// Persists only pins that differ from the current bundled data.
Map<String, PinPosition> changedCityPins(
  List<City> baseCities,
  List<City> currentCities,
) {
  final baseById = {for (final city in baseCities) city.id: city};
  final changes = <String, PinPosition>{};
  for (final city in currentCities) {
    final base = baseById[city.id];
    if (base == null || !city.isPinned) continue;
    if (city.px != base.px || city.py != base.py) {
      changes[city.id] = (px: city.px!, py: city.py!);
    }
  }
  return changes;
}

Map<String, PinPosition> decodeCityOverrides(String raw) {
  final decoded = jsonDecodeOverrides(raw);
  final result = <String, PinPosition>{};
  for (final entry in decoded.entries) {
    final value = entry.value;
    if (value is! Map) continue;
    final px = value['px'];
    final py = value['py'];
    if (px is num &&
        py is num &&
        px.isFinite &&
        py.isFinite &&
        px >= 0 &&
        px <= 1 &&
        py >= 0 &&
        py <= 1) {
      result[entry.key] = (px: px.toDouble(), py: py.toDouble());
    }
  }
  return result;
}

// Kept separate so malformed JSON fails clearly instead of applying partial data.
Map<String, dynamic> jsonDecodeOverrides(String raw) {
  final value = jsonDecode(raw);
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Pin overrides must be a JSON object.');
  }
  return value;
}

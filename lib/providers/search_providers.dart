import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/city_model.dart';
import '../utils/string_normalizer.dart';
import 'map_providers.dart';

/// Current free-text search query (matches English + normalized Arabic names).
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Currently selected clime filter, or null for "all climes".
final selectedClimeFilterProvider = StateProvider<int?>((ref) => null);

/// Cities filtered by the active clime filter and search query.
final filteredCitiesProvider = Provider<List<City>>((ref) {
  final citiesAsync = ref.watch(citiesProvider);
  final query = ref.watch(searchQueryProvider);
  final climeFilter = ref.watch(selectedClimeFilterProvider);

  return citiesAsync.maybeWhen(
    data: (cities) {
      final trimmedQuery = query.trim();
      final normalizedQuery =
          trimmedQuery.isEmpty ? '' : StringNormalizer.normalize(trimmedQuery);

      return cities.where((city) {
        // Clime filter.
        if (climeFilter != null && city.clime != climeFilter) {
          return false;
        }

        // Empty query matches everything (within the clime filter).
        if (normalizedQuery.isEmpty) return true;

        final normalizedName = StringNormalizer.normalize(city.name);
        final normalizedArabicName =
            StringNormalizer.normalize(city.arabicName);

        return normalizedName.contains(normalizedQuery) ||
            normalizedArabicName.contains(normalizedQuery);
      }).toList();
    },
    orElse: () => [],
  );
});

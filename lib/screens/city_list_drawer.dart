import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/city_model.dart';
import '../providers/map_providers.dart';
import '../providers/search_providers.dart';

/// A navigation drawer listing every city in the dataset so all of them are
/// browsable — including the ones that have not yet been pinned to the map.
///
/// The list honours the active search query and clime filter, so it stays in
/// sync with what is highlighted on the map.
class CityListDrawer extends ConsumerWidget {
  final bool asPanel;
  final bool isPickerMode;
  final String? selectedCityId;
  final void Function(City city) onCityTap;

  const CityListDrawer({
    Key? key,
    this.asPanel = false,
    required this.isPickerMode,
    required this.selectedCityId,
    required this.onCityTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cities = ref.watch(filteredCitiesProvider);
    final allCities = ref.watch(citiesProvider).maybeWhen(
          data: (list) => list,
          orElse: () => const <City>[],
        );
    final pinnedCount = allCities.where((c) => c.isPinned).length;
    final totalCount = allCities.length;

    final content = SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            color: const Color(0xFF2C1A0E),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cities',
                  style: TextStyle(
                    color: Color(0xFFE8D3A7),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$pinnedCount of $totalCount saved historical pins',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select a pinned city to locate it. Modern coordinates are in city details.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: cities.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No cities match your search / filter.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: cities.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (context, index) {
                      final city = cities[index];
                      final selected = city.id == selectedCityId;
                      return ListTile(
                        selected: selected,
                        selectedTileColor:
                            const Color(0xFF8C2D19).withValues(alpha: 0.25),
                        leading: Icon(
                          city.isPinned
                              ? Icons.location_on
                              : Icons.location_off_outlined,
                          color:
                              city.isPinned ? Colors.redAccent : Colors.white38,
                        ),
                        title: Text(
                          city.name,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                        subtitle: Text(
                          '${city.arabicName}  •  Clime ${city.clime}'
                          '${city.isPinned ? '' : '  •  Not pinned'}',
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                        onTap: () => onCityTap(city),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
    if (asPanel) {
      return ColoredBox(color: const Color(0xFF1E120A), child: content);
    }
    return Drawer(backgroundColor: const Color(0xFF1E120A), child: content);
  }
}

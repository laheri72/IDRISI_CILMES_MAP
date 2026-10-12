import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/city_model.dart';
import '../providers/map_providers.dart';
import '../providers/search_providers.dart';
import '../theme/clime_palette.dart';

/// Searchable city atlas, grouped and marked by climatic zone.
class CityListDrawer extends ConsumerWidget {
  final bool asPanel;
  final bool isPickerMode;
  final String? selectedCityId;
  final void Function(City city) onCityTap;

  const CityListDrawer({
    super.key,
    this.asPanel = false,
    required this.isPickerMode,
    required this.selectedCityId,
    required this.onCityTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cities = ref.watch(filteredCitiesProvider);
    final allCities = ref.watch(citiesProvider).maybeWhen(
          data: (list) => list,
          orElse: () => const <City>[],
        );
    final groups = <int, List<City>>{};
    for (final city in cities) {
      groups.putIfAbsent(city.clime, () => []).add(city);
    }

    final content = SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            color: ClimePalette.panelRaised,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('City atlas',
                    style: TextStyle(
                        color: ClimePalette.parchment,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '${allCities.where((city) => city.isPinned).length} historical pins · ${allCities.length} places',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Text(
                  isPickerMode
                      ? 'Select a city, then drag its pin on the map.'
                      : 'Choose a city to explore its history.',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: cities.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No cities match your search or clime.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54)),
                    ),
                  )
                : ListView(
                    children: [
                      for (final group in groups.entries) ...[
                        _ClimeHeading(
                            number: group.key, count: group.value.length),
                        for (final city in group.value)
                          _CityRow(
                            city: city,
                            selected: city.id == selectedCityId,
                            onTap: () => onCityTap(city),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
    if (asPanel) {
      return ColoredBox(color: ClimePalette.panel, child: content);
    }
    return Drawer(backgroundColor: ClimePalette.panel, child: content);
  }
}

class _ClimeHeading extends StatelessWidget {
  final int number;
  final int count;

  const _ClimeHeading({required this.number, required this.count});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 7),
        child: Row(children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
                color: ClimePalette.of(number),
                borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 9),
          Text('CLIME $number',
              style: const TextStyle(
                  color: ClimePalette.parchment,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.2)),
          const Spacer(),
          Text('$count',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ]),
      );
}

class _CityRow extends StatelessWidget {
  final City city;
  final bool selected;
  final VoidCallback onTap;

  const _CityRow(
      {required this.city, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Column(children: [
        ListTile(
          selected: selected,
          selectedTileColor: ClimePalette.of(city.clime).withValues(alpha: 0.2),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Stack(
            alignment: const Alignment(0, -0.2),
            children: [
              Icon(Icons.location_on,
                  size: 32,
                  color: city.isPinned
                      ? ClimePalette.of(city.clime)
                      : Colors.white38),
              Text('${city.clime}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          title: Text(city.name,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
          subtitle: Text(city.arabicName,
              textDirection: TextDirection.rtl,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          onTap: onTap,
        ),
        const Divider(color: Colors.white10, height: 1),
      ]);
}

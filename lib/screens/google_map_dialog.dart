import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/city_model.dart';
import '../models/modern_reference.dart';
import '../providers/modern_reference_provider.dart';
import '../theme/clime_palette.dart';
import 'google_map_stub.dart' if (dart.library.html) 'google_map_web.dart';

/// Both entry points use the same custom Google My Map. A selected city changes
/// only the camera, using the linked point from the supplied KMZ export.
class GoogleMyMapDialog extends ConsumerWidget {
  final City? selectedCity;
  const GoogleMyMapDialog({super.key, this.selectedCity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = MediaQuery.sizeOf(context);
    final reference = ref.watch(modernReferenceProvider);
    return Dialog(
      backgroundColor: ClimePalette.panel,
      insetPadding: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: (window.width - 24).clamp(0.0, 1160.0),
        height: (window.height - 24).clamp(0.0, 780.0),
        child: Column(children: [
          AppBar(
            title: const Text('Modern map reference',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 17)),
            backgroundColor: ClimePalette.panelRaised,
            foregroundColor: ClimePalette.parchment,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                tooltip: 'Open custom map in browser',
                icon: const Icon(Icons.open_in_new),
                onPressed: reference.valueOrNull == null
                    ? null
                    : () => launchUrl(
                        reference.value!.uri(city: selectedCity, embed: false),
                        mode: LaunchMode.externalApplication),
              ),
              IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          Expanded(
              child: reference.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('The custom map reference could not load.'),
                TextButton(
                    onPressed: () => ref.invalidate(modernReferenceProvider),
                    child: const Text('Try again')),
              ],
            )),
            data: (map) => _ReferenceView(map: map, city: selectedCity),
          )),
        ]),
      ),
    );
  }
}

class _ReferenceView extends StatelessWidget {
  final ModernReference map;
  final City? city;
  const _ReferenceView({required this.map, this.city});

  @override
  Widget build(BuildContext context) {
    final point = map.pointFor(city);
    final accent =
        city == null ? ClimePalette.parchment : ClimePalette.of(city!.clime);
    return Column(children: [
      if (city != null)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: accent.withValues(alpha: 0.12),
          child: Row(children: [
            Icon(Icons.location_on, color: accent),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(city!.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(
                    point == null
                        ? 'No matching point in the supplied custom map. Showing all custom points.'
                        : 'Custom map point: ${point.name}',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            )),
          ]),
        ),
      Expanded(child: getGoogleMapWidget(map.uri(city: city).toString())),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          const Icon(Icons.layers_outlined, size: 16, color: Colors.white54),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  'Your custom map · ${map.points.length} exported points',
                  style: const TextStyle(color: Colors.white70, fontSize: 12))),
        ]),
      ),
    ]);
  }
}

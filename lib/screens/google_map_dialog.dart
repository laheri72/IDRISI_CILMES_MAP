import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/city_model.dart';

// Conditional import to isolate Web iframe logic
import 'google_map_stub.dart' if (dart.library.html) 'google_map_web.dart';

class GoogleMyMapDialog extends StatelessWidget {
  final City? selectedCity;

  const GoogleMyMapDialog({Key? key, this.selectedCity}) : super(key: key);

  static const String mapEmbedUrl =
      'https://www.google.com/maps/d/embed?mid=1XMnqIQnu7SdgRlxMWgl07WWR8DMkz5w';

  static const String mapViewerUrl =
      'https://www.google.com/maps/d/viewer?mid=1XMnqIQnu7SdgRlxMWgl07WWR8DMkz5w';

  Future<void> _launchMapInBrowser([City? city]) async {
    final Uri url = city == null
        ? Uri.parse(mapViewerUrl)
        : Uri.https('www.google.com', '/maps/search/', {
            'api': '1',
            'query': '${city.modernLat},${city.modernLng}',
          });
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  Widget _selectedLocationDialog(BuildContext context, City city) {
    final window = MediaQuery.sizeOf(context);
    final point = LatLng(city.modernLat, city.modernLng);
    return Dialog(
      backgroundColor: const Color(0xFF2C1A0E),
      insetPadding: const EdgeInsets.all(12),
      child: SizedBox(
        width: (window.width - 24).clamp(0.0, 950.0),
        height: (window.height - 24).clamp(0.0, 650.0),
        child: Column(
          children: [
            AppBar(
              title: Text(window.width < 500
                  ? 'Modern map'
                  : 'Modern map reference'),
              backgroundColor: const Color(0xFF2C1A0E),
              foregroundColor: const Color(0xFFE8D3A7),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  tooltip: 'Open selected location in browser',
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => _launchMapInBrowser(city),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF3A2517),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Color(0xFFFFC26B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      city.name,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (window.width >= 500)
                    const Text('Present-day reference',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            Expanded(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: 7,
                  minZoom: 2,
                  maxZoom: 18,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'org.idrisi.map_explorer',
                  ),
                  CircleLayer(circles: [
                    CircleMarker(
                      point: point,
                      radius: 24,
                      color: const Color(0x44FFB74D),
                      borderColor: const Color(0xFFFFB74D),
                      borderStrokeWidth: 2,
                    ),
                  ]),
                  MarkerLayer(markers: [
                    Marker(
                      point: point,
                      width: 44,
                      height: 44,
                      alignment: Alignment.bottomCenter,
                      child: const Icon(Icons.location_on,
                          size: 40, color: Color(0xFFAD2D20)),
                    ),
                  ]),
                  SimpleAttributionWidget(
                    source: const Text('OpenStreetMap contributors'),
                    onTap: () => launchUrl(
                      Uri.parse('https://www.openstreetmap.org/copyright'),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = selectedCity;
    if (selected != null) return _selectedLocationDialog(context, selected);

    if (kIsWeb) {
      final window = MediaQuery.sizeOf(context);
      return Dialog(
        backgroundColor: const Color(0xFF2C1A0E),
        insetPadding: const EdgeInsets.all(12),
        child: SizedBox(
          width: (window.width - 24).clamp(0.0, 950.0),
          height: (window.height - 24).clamp(0.0, 650.0),
          child: Column(
            children: [
              AppBar(
                title: const Text('Modern map reference'),
                backgroundColor: const Color(0xFF2C1A0E),
                foregroundColor: const Color(0xFFE8D3A7),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    tooltip: 'Open in browser',
                    icon: const Icon(Icons.open_in_new),
                    onPressed: () => _launchMapInBrowser(),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Expanded(
                child: getGoogleMapWidget(mapEmbedUrl),
              ),
            ],
          ),
        ),
      );
    } else {
      // DESKTOP PLATFORM: Prompt user to open full interactive map in default browser
      return AlertDialog(
        backgroundColor: const Color(0xFF2C1A0E),
        title: const Text(
          'Modern Google Map Reference',
          style: TextStyle(color: Color(0xFFE8D3A7)),
        ),
        content: const Text(
          'Open the interactive Google My Map reference layer in your browser to view modern locations.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8C2D19),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Map in Browser'),
            onPressed: () {
              _launchMapInBrowser();
              Navigator.pop(context);
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
        ],
      );
    }
  }
}

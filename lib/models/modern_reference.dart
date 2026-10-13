import 'city_model.dart';

/// The exported custom map is the sole source for modern point coordinates.
class ModernReference {
  final String mapId;
  final String title;
  final List<ModernReferencePoint> points;

  const ModernReference(
      {required this.mapId, required this.title, required this.points});

  factory ModernReference.fromJson(Map<String, dynamic> json) =>
      ModernReference(
          mapId: json['mapId'] as String,
          title: json['title'] as String,
          points: (json['points'] as List<dynamic>)
              .map((value) =>
                  ModernReferencePoint.fromJson(value as Map<String, dynamic>))
              .toList());

  ModernReferencePoint? pointFor(City? city) {
    if (city == null) return null;
    for (final point in points) {
      if (point.id == city.modernReferenceId || point.cityId == city.id) {
        return point;
      }
    }
    return null;
  }

  Uri uri({City? city, bool embed = true}) {
    final point = pointFor(city);
    return Uri.https(
        'www.google.com', '/maps/d/${embed ? 'embed' : 'viewer'}', {
      'mid': mapId,
      if (point != null) 'll': '${point.latitude},${point.longitude}',
      if (point != null) 'z': city?.pinBasis == 'region' ? '5' : '7',
    });
  }
}

class ModernReferencePoint {
  final String id;
  final String? cityId;
  final String name;
  final int clime;
  final double latitude;
  final double longitude;

  const ModernReferencePoint(
      {required this.id,
      this.cityId,
      required this.name,
      required this.clime,
      required this.latitude,
      required this.longitude});

  factory ModernReferencePoint.fromJson(Map<String, dynamic> json) =>
      ModernReferencePoint(
          id: json['id'] as String,
          cityId: json['cityId'] as String?,
          name: json['name'] as String,
          clime: json['clime'] as int,
          latitude: (json['latitude'] as num).toDouble(),
          longitude: (json['longitude'] as num).toDouble());
}

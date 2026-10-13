import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idrisi_map_app/models/city_model.dart';
import 'package:idrisi_map_app/models/modern_reference.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ModernReference map;
  late List<City> cities;
  setUpAll(() async {
    map = ModernReference.fromJson(jsonDecode(
            await rootBundle.loadString('assets/data/modern_reference.json'))
        as Map<String, dynamic>);
    cities = (jsonDecode(await rootBundle.loadString('assets/data/cities.json'))
            as List<dynamic>)
        .map((value) => City.fromJson(value as Map<String, dynamic>))
        .toList();
  });

  test('custom source retains 81 points and all explicit catalog links', () {
    expect(map.points, hasLength(81));
    expect(map.points.map((point) => point.id).toSet(), hasLength(81));
    expect(map.points.where((point) => point.clime == 7), hasLength(15));
    final unmatched =
        cities.where((city) => map.pointFor(city) == null).toList();
    expect(unmatched.map((city) => city.id), ['barqa']);
    for (final city in cities.where((city) => city.modernReferenceId != null)) {
      final point = map.pointFor(city)!;
      expect(point.clime, city.clime);
      expect(point.latitude, city.modernLat);
      expect(point.longitude, city.modernLng);
    }
  });

  test(
      'overview and selected cities share the custom map using KMZ coordinates',
      () {
    final jarma = cities.firstWhere((city) => city.id == 'jarma');
    final atil = cities.firstWhere((city) => city.id == 'atil');
    final overview = map.uri();
    final first = map.uri(city: jarma.copyWith(modernLat: 0, modernLng: 0));
    final second = map.uri(city: atil);
    expect(first.queryParameters['mid'], overview.queryParameters['mid']);
    expect(second.queryParameters['mid'], overview.queryParameters['mid']);
    expect(first.queryParameters['ll'], '26.526147,13.0760273');
    expect(second.queryParameters['ll'], '46.35,48.05');
    expect(overview.queryParameters.containsKey('ll'), isFalse);
    expect(map.uri(city: atil, embed: false).path, '/maps/d/viewer');
    expect(
        map
            .uri(city: cities.firstWhere((city) => city.id == 'barqa'))
            .queryParameters
            .containsKey('ll'),
        isFalse);
  });

  test('expanded journal histories survive pin edits and JSON serialization',
      () {
    for (final city in cities) {
      expect(city.historySections, isNotEmpty, reason: city.id);
      expect(
          city.historySections
              .every((section) => section.paragraphs.isNotEmpty),
          isTrue);
      final edited = City.fromJson(city.copyWith(px: 0.5, py: 0.5).toJson());
      expect(edited.historySections.map((section) => section.toJson()).toList(),
          city.historySections.map((section) => section.toJson()).toList());
      expect(edited.modernReferenceId, city.modernReferenceId);
      expect(edited.sourceNote, city.sourceNote);
    }
  });
}

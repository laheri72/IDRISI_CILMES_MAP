import 'package:flutter/foundation.dart';

/// A city/place referenced in the Ikhwan al-Safa "Risalah Geographia"
/// (Epistles of the Brethren of Purity) and located on al-Idrisi's 1154 CE map.
///
/// Coordinates [px] and [py] are normalized (0.0 – 1.0) positions on the map
/// image. They are nullable because a city may not yet have been pinned to a
/// specific spot on the historical map (see picker mode in the map screen).
@immutable
class City {
  final String id;
  final String name;
  final String arabicName;
  final int clime;
  final String history;
  final String idrisiHint;

  /// Modern-day latitude used for the "open in maps" reference.
  final double modernLat;
  /// Modern-day longitude used for the "open in maps" reference.
  final double modernLng;

  /// Normalized X coordinate on the map image (0.0 – 1.0), or null if unpinned.
  final double? px;
  /// Normalized Y coordinate on the map image (0.0 – 1.0), or null if unpinned.
  final double? py;

  const City({
    required this.id,
    required this.name,
    required this.arabicName,
    required this.clime,
    required this.history,
    required this.idrisiHint,
    required this.modernLat,
    required this.modernLng,
    this.px,
    this.py,
  });

  /// Whether this city has been positioned on the historical map.
  bool get isPinned => px != null && py != null;

  City copyWith({
    String? id,
    String? name,
    String? arabicName,
    int? clime,
    String? history,
    String? idrisiHint,
    double? modernLat,
    double? modernLng,
    double? px,
    double? py,
  }) {
    return City(
      id: id ?? this.id,
      name: name ?? this.name,
      arabicName: arabicName ?? this.arabicName,
      clime: clime ?? this.clime,
      history: history ?? this.history,
      idrisiHint: idrisiHint ?? this.idrisiHint,
      modernLat: modernLat ?? this.modernLat,
      modernLng: modernLng ?? this.modernLng,
      px: px ?? this.px,
      py: py ?? this.py,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'arabicName': arabicName,
      'clime': clime,
      'history': history,
      'idrisiHint': idrisiHint,
      'modernLat': modernLat,
      'modernLng': modernLng,
      'px': px,
      'py': py,
    };
  }

  factory City.fromJson(Map<String, dynamic> json) {
    double? _toDoubleOrNull(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    return City(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      arabicName: json['arabicName']?.toString() ?? '',
      clime: (json['clime'] as num?)?.toInt() ?? 0,
      history: json['history']?.toString() ?? '',
      idrisiHint: json['idrisiHint']?.toString() ?? '',
      modernLat: (json['modernLat'] as num?)?.toDouble() ?? 0.0,
      modernLng: (json['modernLng'] as num?)?.toDouble() ?? 0.0,
      px: _toDoubleOrNull(json['px']),
      py: _toDoubleOrNull(json['py']),
    );
  }
}

import 'dart:math' as math;

import 'map_alignment_data.dart';

/// Converts positions between two scans of the same, upright map.
///
/// Saved pins use normalized Arabic-image coordinates. The English scan has
/// different borders and small local distortions, measured by matching common
/// image features. The grid gives a smooth, locally calibrated conversion.
class MapCoordinates {
  static ({double px, double py}) forDisplay(
    double px,
    double py, {
    required bool english,
  }) =>
      english ? _arabicToEnglish(px, py) : (px: px, py: py);

  static ({double px, double py}) fromDisplay(
    double px,
    double py, {
    required bool english,
  }) {
    if (!english) return (px: px, py: py);

    // Newton iteration in normalized image coordinates. The two maps have the
    // same orientation, so the initial point is already close to the answer.
    var x = px;
    var y = py;
    const step = 0.00001;
    for (var iteration = 0; iteration < 7; iteration++) {
      final mapped = _arabicToEnglish(x, y);
      final errorX = mapped.px - px;
      final errorY = mapped.py - py;
      if (math.max(errorX.abs(), errorY.abs()) < 1e-10) break;
      final xStep = _arabicToEnglish(x + step, y);
      final yStep = _arabicToEnglish(x, y + step);
      final a = (xStep.px - mapped.px) / step;
      final b = (yStep.px - mapped.px) / step;
      final c = (xStep.py - mapped.py) / step;
      final d = (yStep.py - mapped.py) / step;
      final determinant = a * d - b * c;
      if (determinant.abs() < 1e-8) break;
      x -= (d * errorX - b * errorY) / determinant;
      y -= (-c * errorX + a * errorY) / determinant;
    }
    return (px: x, py: y);
  }

  /// A point in either image's unmatched border cannot represent a shared pin.
  static bool isOnBothMaps(double arabicX, double arabicY) {
    if (!_inside(arabicX) || !_inside(arabicY)) return false;
    final english = _arabicToEnglish(arabicX, arabicY);
    return _inside(english.px) && _inside(english.py);
  }

  static bool _inside(double value) => value >= 0 && value <= 1;

  static ({double px, double py}) _arabicToEnglish(double px, double py) {
    final gridX = px * (mapAlignmentColumns - 1);
    final gridY = py * (mapAlignmentRows - 1);
    final column = gridX.floor().clamp(0, mapAlignmentColumns - 2);
    final row = gridY.floor().clamp(0, mapAlignmentRows - 2);
    final fx = gridX - column;
    final fy = gridY - row;

    double interpolate(int coordinate) {
      final topLeft = 2 * (row * mapAlignmentColumns + column) + coordinate;
      final topRight = topLeft + 2;
      final bottomLeft = topLeft + 2 * mapAlignmentColumns;
      final bottomRight = bottomLeft + 2;
      final top = mapAlignmentEnglishNodes[topLeft] * (1 - fx) +
          mapAlignmentEnglishNodes[topRight] * fx;
      final bottom = mapAlignmentEnglishNodes[bottomLeft] * (1 - fx) +
          mapAlignmentEnglishNodes[bottomRight] * fx;
      return top * (1 - fy) + bottom * fy;
    }

    return (px: interpolate(0), py: interpolate(1));
  }
}

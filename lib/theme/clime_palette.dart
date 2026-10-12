import 'package:flutter/material.dart';

/// A fixed identity for each of al-Idrisi's seven climatic zones.
/// Colors are chosen to remain distinct against the parchment map.
abstract final class ClimePalette {
  static const parchment = Color(0xFFF2E6C8);
  static const ink = Color(0xFF211A19);
  static const panel = Color(0xFF241F22);
  static const panelRaised = Color(0xFF322A2D);

  static const colors = <Color>[
    Color(0xFF007F83), // 1 — teal
    Color(0xFFC13B43), // 2 — vermilion
    Color(0xFF3267BD), // 3 — cobalt
    Color(0xFF884BB0), // 4 — violet
    Color(0xFFA66712), // 5 — ochre
    Color(0xFF39804A), // 6 — green
    Color(0xFFB12F80), // 7 — magenta
  ];

  static Color of(int number) =>
      number >= 1 && number <= colors.length ? colors[number - 1] : colors[0];
}

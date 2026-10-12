import 'package:flutter/material.dart';

Widget getGoogleMapWidget(String url) {
  return const Center(
    child: Text(
      'Embedded map view is only supported on Web.\nUse external window for Desktop.',
      textAlign: TextAlign.center,
      style: TextStyle(color: Colors.white70),
    ),
  );
}
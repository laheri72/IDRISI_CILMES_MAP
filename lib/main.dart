import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/map_screen.dart';
import 'theme/clime_palette.dart';

void main() {
  runApp(
    const ProviderScope(
      child: IdrisiMapApp(),
    ),
  );
}

class IdrisiMapApp extends StatelessWidget {
  const IdrisiMapApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Al-Idrisi Map Explorer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: ClimePalette.panel,
        scaffoldBackgroundColor: ClimePalette.ink,
        colorScheme: const ColorScheme.dark(
          primary: ClimePalette.parchment,
          secondary: Color(0xFF007F83),
          surface: ClimePalette.panel,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: ClimePalette.panelRaised,
          foregroundColor: ClimePalette.parchment,
        ),
      ),
      home: const MapScreen(),
    );
  }
}

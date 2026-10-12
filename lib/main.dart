import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/map_screen.dart';

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
        primaryColor: const Color(0xFF2C1A0E),
        scaffoldBackgroundColor: const Color(0xFF1E120A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8C2D19),
          secondary: Color(0xFFE8D3A7),
          surface: Color(0xFF2C1A0E),
        ),
      ),
      home: const MapScreen(),
    );
  }
}
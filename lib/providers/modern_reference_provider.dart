import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/modern_reference.dart';

final modernReferenceProvider = FutureProvider<ModernReference>((ref) async {
  final raw = await rootBundle.loadString('assets/data/modern_reference.json');
  return ModernReference.fromJson(jsonDecode(raw) as Map<String, dynamic>);
});

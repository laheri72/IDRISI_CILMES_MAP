import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idrisi_map_app/models/city_model.dart';
import 'package:idrisi_map_app/screens/city_detail_sheet.dart';

void main() {
  testWidgets(
      'long journal reading scrolls while its modern-map action stays visible',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final raw = await tester
        .runAsync(() => rootBundle.loadString('assets/data/cities.json'));
    final entries = jsonDecode(raw!) as List<dynamic>;
    final city = City.fromJson(entries
        .firstWhere((entry) => entry['id'] == 'bijar') as Map<String, dynamic>);
    var opened = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CityDetailSheet(
      city: city,
      onViewModernLocation: () => opened = true,
    ))));
    await tester.pump();
    expect(tester.takeException(), isNull);
    final action = find.text('View modern location');
    final before = tester.getRect(action);
    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getRect(action), before);
    await tester.tap(action);
    expect(opened, isTrue);
  });
}

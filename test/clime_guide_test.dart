import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idrisi_map_app/providers/map_providers.dart';
import 'package:idrisi_map_app/providers/search_providers.dart';
import 'package:idrisi_map_app/screens/clime_study_guide.dart';
import 'package:idrisi_map_app/services/city_storage_service.dart';

void main() {
  testWidgets('clime guide reverses orientation and filters Clime 7 on mobile',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
        overrides: [
          cityStorageServiceProvider.overrideWithValue(
              CityStorageService(readRawOverride: () async => null)),
        ],
        child: MaterialApp(
            home: Builder(
          builder: (context) => Scaffold(
              body: Center(
                  child: TextButton(
                      onPressed: () => showDialog(
                          context: context,
                          builder: (_) => const ClimeStudyGuide()),
                      child: const Text('Guide')))),
        ))));
    await tester.tap(find.text('Guide'));
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(ClimeStudyGuide)));
    final seventh = find.byKey(const ValueKey('clime-belt-7'));
    final sixth = find.byKey(const ValueKey('clime-belt-6'));
    expect(
        tester.getTopLeft(seventh).dy, lessThan(tester.getTopLeft(sixth).dy));
    await tester.ensureVisible(find.text('Idrisi: south up'));
    await tester.pump();
    await tester.tap(find.text('Idrisi: south up'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    final first = find.byKey(const ValueKey('clime-belt-1'));
    expect(
        tester.getTopLeft(first).dy, lessThan(tester.getTopLeft(seventh).dy));
    await tester.ensureVisible(seventh);
    await tester.tap(seventh);
    await tester.pump();
    await tester.tap(find.text('Explore Clime 7'));
    await tester.pump();
    expect(container.read(selectedClimeFilterProvider), 7);
    expect(container.read(filteredCitiesProvider), hasLength(15));
  });
}

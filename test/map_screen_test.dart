import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idrisi_map_app/providers/map_providers.dart';
import 'package:idrisi_map_app/screens/map_screen.dart';
import 'package:idrisi_map_app/screens/google_map_dialog.dart';
import 'package:idrisi_map_app/services/city_storage_service.dart';
import 'package:idrisi_map_app/models/city_model.dart';
import 'package:idrisi_map_app/providers/modern_reference_provider.dart';

class _TrialPinStorage extends CityStorageService {
  bool cleared = false;

  @override
  Future<List<City>> loadMergedCities() async => [
        City(
          id: 'jarma',
          name: 'Jarma',
          arabicName: 'جرمى',
          clime: 1,
          history: 'Jarma historical significance',
          idrisiHint: 'Trial navigation hint',
          modernLat: 26.53,
          modernLng: 13.07,
          px: cleared ? 0.1 : 0.3,
          py: cleared ? 0.2 : 0.4,
        ),
      ];

  @override
  Future<SaveResult> clearOverrides() async {
    cleared = true;
    return SaveResult.ok;
  }
}

void main() {
  testWidgets('map fits on load and requests detail tiles after zoom',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        cityStorageServiceProvider.overrideWithValue(
          CityStorageService(readRawOverride: () async => null),
        ),
      ],
      child: const MaterialApp(home: MapScreen()),
    ));
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MapScreen), findsOneWidget);
    final viewer =
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final viewportSize = tester.getSize(find.byType(InteractiveViewer));
    expect(viewportSize.width, greaterThan(0));
    final fittedScale = viewer.transformationController!.value.entry(0, 0);
    expect(fittedScale, greaterThan(0));
    expect(fittedScale, lessThan(0.2));
    expect(
      tester.widgetList<Image>(find.byType(Image)).any((image) =>
          image.image is AssetImage &&
          (image.image as AssetImage).assetName ==
              'assets/maps/previews/idrisi_map_ar.webp'),
      isTrue,
    );
    expect(find.textContaining('map image could not load'), findsNothing);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pump();
    }
    expect(
      tester.widgetList<Image>(find.byType(Image)).any((image) =>
          image.image is AssetImage &&
          (image.image as AssetImage)
              .assetName
              .startsWith('assets/maps/tiles/ar/')),
      isTrue,
    );
  });

  testWidgets('restore defaults replaces an edited pin', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final storage = _TrialPinStorage();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        cityStorageServiceProvider.overrideWithValue(storage),
      ],
      child: const MaterialApp(home: MapScreen()),
    ));
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(MapScreen)));
    for (var attempt = 0;
        attempt < 30 && !container.read(citiesProvider).hasValue;
        attempt++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(container.read(citiesProvider).hasValue, isTrue);
    expect(
        container
            .read(citiesProvider)
            .value!
            .where((city) => city.isPinned)
            .length,
        1);

    expect(find.byTooltip('Modern map reference'), findsOneWidget);
    expect(find.byTooltip('Edit map pins'), findsOneWidget);
    await tester.tap(find.byTooltip('Restore default pin positions'));
    await tester.pump();
    await tester.tap(find.text('Restore defaults'));
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    for (var attempt = 0;
        attempt < 30 && !container.read(citiesProvider).hasValue;
        attempt++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(storage.cleared, isTrue);
    final restored = container.read(citiesProvider).value!.single;
    expect(restored.px, 0.1);
    expect(restored.py, 0.2);
  });

  testWidgets('map toggle keeps an existing pin in the same region',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        cityStorageServiceProvider.overrideWithValue(_TrialPinStorage()),
      ],
      child: const MaterialApp(home: MapScreen()),
    ));
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    await tester.pump();

    final pin = find.byTooltip('Jarma · Clime 1');
    expect(pin, findsOneWidget);
    final arabicPosition = tester.getTopLeft(pin);
    await tester.tap(find.byTooltip('Switch to English map'));
    await tester.pump();
    await tester.pump();
    final englishPosition = tester.getTopLeft(pin);
    expect((englishPosition.dx - arabicPosition.dx).abs(), lessThan(100));

    await tester.tap(find.byTooltip('Switch to Arabic map'));
    await tester.pump();
    await tester.pump();
    final restoredPosition = tester.getTopLeft(pin);
    expect(restoredPosition.dx, closeTo(arabicPosition.dx, 0.1));
    expect(restoredPosition.dy, closeTo(arabicPosition.dy, 0.1));
  });

  testWidgets('direct map actions fit a narrow app bar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        cityStorageServiceProvider.overrideWithValue(_TrialPinStorage()),
      ],
      child: const MaterialApp(home: MapScreen()),
    ));
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();

    expect(find.byTooltip('Switch to English map'), findsOneWidget);
    expect(find.byTooltip('Modern map reference'), findsOneWidget);
    expect(find.byTooltip('Edit map pins'), findsOneWidget);
    expect(find.byTooltip('Restore default pin positions'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Edit map pins'));
    await tester.pump();
    expect(find.byTooltip('Exit pin editor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'city detail opens the same custom map at its KMZ reference point',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        cityStorageServiceProvider.overrideWithValue(_TrialPinStorage()),
      ],
      child: const MaterialApp(home: MapScreen()),
    ));
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('Jarma · Clime 1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Jarma historical significance'), findsOneWidget);
    expect(find.text('Al-Idrisi Map Navigation Hint'), findsNothing);
    expect(find.textContaining('Modern coordinates:'), findsNothing);

    await tester.tap(find.text('View modern location'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    final dialog =
        tester.widget<GoogleMyMapDialog>(find.byType(GoogleMyMapDialog));
    expect(dialog.selectedCity?.id, 'jarma');
    final container = ProviderScope.containerOf(
        tester.element(find.byType(GoogleMyMapDialog)));
    final reference = container.read(modernReferenceProvider).value!;
    final uri = reference.uri(city: dialog.selectedCity);
    expect(uri.path, '/maps/d/embed');
    expect(uri.queryParameters['mid'], reference.mapId);
    expect(uri.queryParameters['ll'], '26.526147,13.0760273');
    expect(find.text('Custom map point: Germa'), findsOneWidget);
    expect(find.byTooltip('Open custom map in browser'), findsOneWidget);
  });
}

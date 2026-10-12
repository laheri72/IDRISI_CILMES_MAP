import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/city_model.dart';
import '../providers/map_providers.dart';
import '../providers/search_providers.dart';
import '../utils/map_coordinates.dart';
import 'city_detail_sheet.dart';
import 'city_list_drawer.dart';
import 'google_map_dialog.dart';

/// Main screen: an interactive, zoomable rendering of al-Idrisi's 1154 CE map
/// with the cities of the Ikhwan al-Safa "Risalah Geographia" pinned on it.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final TransformationController _transformController =
      TransformationController();
  final GlobalKey _viewportKey = GlobalKey();
  Size? _viewportSize;
  bool _hasFittedMap = false;

  bool _isPickerMode = false;
  bool _isSaving = false;
  bool _isResetting = false;
  bool _useEnglishMap = false;
  bool _isWide = false;
  String? _selectedCityId;

  /// Unsaved pin-position changes staged during picker mode.
  final Map<String, ({double px, double py})> _pendingChanges = {};

  // Real pixel dimensions of the two bundled map images. Stored pins use
  // Arabic coordinates and are aligned to the English sheet on display.
  static const Size _arCanvas = Size(11440, 5654);
  static const Size _enCanvas = Size(12999, 5958);

  Size get _canvasSize => _useEnglishMap ? _enCanvas : _arCanvas;

  String get _mapLanguage => _useEnglishMap ? 'en' : 'ar';
  String get _previewAsset =>
      'assets/maps/previews/idrisi_map_$_mapLanguage.webp';

  static const int _tileSize = 1024;

  /// Load native-resolution tiles only around the visible scene.
  List<Widget> _visibleTiles() {
    final viewport = _viewportSize;
    if (viewport == null || _currentScale < _fitScale * 3.6) return const [];
    final topLeft = _transformController.toScene(Offset.zero);
    final bottomRight =
        _transformController.toScene(Offset(viewport.width, viewport.height));
    const margin = _tileSize / 2;
    final firstColumn =
        math.max(0, ((topLeft.dx - margin) / _tileSize).floor());
    final firstRow = math.max(0, ((topLeft.dy - margin) / _tileSize).floor());
    final lastColumn = math.min((_canvasSize.width / _tileSize).ceil() - 1,
        ((bottomRight.dx + margin) / _tileSize).floor());
    final lastRow = math.min((_canvasSize.height / _tileSize).ceil() - 1,
        ((bottomRight.dy + margin) / _tileSize).floor());
    final tiles = <Widget>[];
    for (var row = firstRow; row <= lastRow; row++) {
      for (var column = firstColumn; column <= lastColumn; column++) {
        final left = column * _tileSize.toDouble();
        final top = row * _tileSize.toDouble();
        tiles.add(Positioned(
          left: left,
          top: top,
          width: math.min(_tileSize.toDouble(), _canvasSize.width - left),
          height: math.min(_tileSize.toDouble(), _canvasSize.height - top),
          child: Image.asset(
            'assets/maps/tiles/$_mapLanguage/$column-$row.webp',
            key: ValueKey('$_mapLanguage:$column:$row'),
            fit: BoxFit.fill,
            filterQuality: FilterQuality.low,
            errorBuilder: (context, error, stack) => const SizedBox.shrink(),
          ),
        ));
      }
    }
    return tiles;
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  double? _effectivePx(City city) => _pendingChanges[city.id]?.px ?? city.px;
  double? _effectivePy(City city) => _pendingChanges[city.id]?.py ?? city.py;

  /// Current uniform zoom scale of the map, used to convert a screen-space
  /// drag delta into normalized map coordinates.
  double get _currentScale => _transformController.value.entry(0, 0);

  double get _fitScale {
    final viewport = _viewportSize;
    if (viewport == null || viewport.isEmpty) return 0.05;
    return (viewport.width / _canvasSize.width)
        .clamp(0.001, viewport.height / _canvasSize.height);
  }

  void _setView(double scale, Offset sceneCenter) {
    final viewport = _viewportSize;
    if (viewport == null) return;
    final translation =
        Offset(viewport.width / 2, viewport.height / 2) - sceneCenter * scale;
    _transformController.value = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(0, 3, translation.dx)
      ..setEntry(1, 3, translation.dy);
  }

  void _fitMap() {
    _setView(_fitScale, Offset(_canvasSize.width / 2, _canvasSize.height / 2));
  }

  void _updateViewport(Size size) {
    if (size.isEmpty || size == _viewportSize) return;
    final oldSize = _viewportSize;
    final oldFit = _fitScale;
    final oldCenter = oldSize == null
        ? null
        : _transformController
            .toScene(Offset(oldSize.width / 2, oldSize.height / 2));
    final ratio = oldSize == null ? 1.0 : _currentScale / oldFit;
    _viewportSize = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _viewportSize != size) return;
      if (!_hasFittedMap || oldCenter == null) {
        _fitMap();
        _hasFittedMap = true;
      } else {
        _setView((_fitScale * ratio).clamp(_fitScale, 1.5), oldCenter);
      }
    });
  }

  void _zoom(double factor) {
    final viewport = _viewportSize;
    if (viewport == null) return;
    final center = _transformController
        .toScene(Offset(viewport.width / 2, viewport.height / 2));
    _setView((_currentScale * factor).clamp(_fitScale, 1.5), center);
  }

  void _focusCity(City city) {
    final px = _effectivePx(city);
    final py = _effectivePy(city);
    if (px == null || py == null) {
      _showSnack('${city.name} has no historical map pin yet.');
      return;
    }
    final display = MapCoordinates.forDisplay(px, py, english: _useEnglishMap);
    _setView(
        (_fitScale * 4).clamp(_fitScale, 1.5),
        Offset(
            display.px * _canvasSize.width, display.py * _canvasSize.height));
  }

  void _switchMap() {
    final viewport = _viewportSize;
    final center = viewport == null
        ? null
        : _transformController
            .toScene(Offset(viewport.width / 2, viewport.height / 2));
    final oldCanvas = _canvasSize;
    final zoomRatio = _currentScale / _fitScale;
    final oldEnglish = _useEnglishMap;
    final canonicalCenter = center == null
        ? null
        : MapCoordinates.fromDisplay(
            center.dx / oldCanvas.width,
            center.dy / oldCanvas.height,
            english: oldEnglish,
          );
    setState(() => _useEnglishMap = !_useEnglishMap);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || canonicalCenter == null) return;
      final displayCenter = MapCoordinates.forDisplay(
        canonicalCenter.px,
        canonicalCenter.py,
        english: _useEnglishMap,
      );
      final newCenter = Offset(displayCenter.px * _canvasSize.width,
          displayCenter.py * _canvasSize.height);
      _setView((_fitScale * zoomRatio).clamp(_fitScale, 1.5), newCenter);
    });
  }

  /// Converts a global (screen) position into normalized map coordinates,
  /// accounting for the current pan/zoom of the [InteractiveViewer].
  ({double px, double py})? _toNormalized(Offset globalPosition) {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || box.size.isEmpty) return null;
    final local =
        _transformController.toScene(box.globalToLocal(globalPosition));
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx > _canvasSize.width ||
        local.dy > _canvasSize.height) {
      return null;
    }
    final displayCoords = (
      px: local.dx / _canvasSize.width,
      py: local.dy / _canvasSize.height,
    );
    final canonical = MapCoordinates.fromDisplay(
      displayCoords.px,
      displayCoords.py,
      english: _useEnglishMap,
    );
    return MapCoordinates.isOnBothMaps(canonical.px, canonical.py)
        ? canonical
        : null;
  }

  /// Places a city at an absolute point on the map (used for tap-to-place).
  void _placeCityAt(String cityId, Offset globalPosition) {
    final coords = _toNormalized(globalPosition);
    if (coords == null) {
      _showSnack('Choose a point within the area shared by both maps.',
          success: false);
      return;
    }
    setState(() {
      _pendingChanges[cityId] = coords;
      if (_selectedCityId == cityId) {
        _selectedCityId = _nextUnpinnedCityId(afterId: cityId);
      }
    });
  }

  /// Nudges an already-placed city by a drag delta.
  ///
  /// Using the gesture *delta* (rather than the absolute pointer position)
  /// keeps the pin under the finger even though the [InteractiveViewer] is
  /// simultaneously panning — the two gestures no longer fight each other.
  void _dragCityBy(String cityId, Offset delta) {
    final city = _cityById(cityId);
    if (city == null) return;
    final basePx = _effectivePx(city);
    final basePy = _effectivePy(city);
    if (basePx == null || basePy == null) return;

    final display =
        MapCoordinates.forDisplay(basePx, basePy, english: _useEnglishMap);
    final moved = MapCoordinates.fromDisplay(
      display.px + delta.dx / (_canvasSize.width * _currentScale),
      display.py + delta.dy / (_canvasSize.height * _currentScale),
      english: _useEnglishMap,
    );
    if (!MapCoordinates.isOnBothMaps(moved.px, moved.py)) return;

    setState(() {
      _pendingChanges[cityId] = moved;
    });
  }

  City? _cityById(String id) {
    return ref.read(citiesProvider).maybeWhen(
          data: (list) => list.where((c) => c.id == id).firstOrNull,
          orElse: () => null,
        );
  }

  /// Finds the next city that still has no pin, for auto-advancing the picker.
  String? _nextUnpinnedCityId({String? afterId}) {
    final cities = ref.read(filteredCitiesProvider);
    if (cities.isEmpty) return null;

    final startIndex =
        afterId == null ? -1 : cities.indexWhere((c) => c.id == afterId);
    for (var i = 1; i <= cities.length; i++) {
      final city = cities[(startIndex + i) % cities.length];
      final bool hasPin = _pendingChanges.containsKey(city.id) ||
          (_effectivePx(city) != null && _effectivePy(city) != null);
      if (!hasPin) return city.id;
    }
    return null;
  }

  Future<void> _savePendingChanges() async {
    if (_pendingChanges.isEmpty) {
      _showSnack('No position changes to save.');
      return;
    }
    setState(() => _isSaving = true);
    final snapshot =
        Map<String, ({double px, double py})>.from(_pendingChanges);
    final result =
        await ref.read(citiesProvider.notifier).updateCityLocations(snapshot);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (result.success) {
      setState(() {
        for (final entry in snapshot.entries) {
          if (_pendingChanges[entry.key] == entry.value) {
            _pendingChanges.remove(entry.key);
          }
        }
      });
      _showSnack('Saved ${snapshot.length} pin position(s).', success: true);
    } else {
      _showSnack(
        'Could not save: ${result.error ?? 'unknown error'}',
        success: false,
      );
    }
  }

  Future<void> _resetToDefaults() async {
    if (_isSaving || _isResetting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C1A0E),
        title: const Text('Clear all saved pins?',
            style: TextStyle(color: Color(0xFFE8D3A7))),
        content: const Text(
          'This removes interactive city pins saved on this device. '
          'Symbols printed in the historical map image remain. '
          'City details and modern locations stay available.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8C2D19)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear pins'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isResetting = true);
    final result = await ref.read(citiesProvider.notifier).resetToDefaults();
    if (!mounted) return;
    setState(() => _isResetting = false);
    if (result.success) {
      setState(() {
        _pendingChanges.clear();
        _selectedCityId = null;
      });
    }
    _showSnack(
      result.success
          ? 'All saved pins cleared.'
          : 'Could not clear pins: ${result.error ?? 'unknown error'}',
      success: result.success,
    );
  }

  void _showSnack(String message, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
  }

  void _openCityDetail(City city) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (sheetContext) => CityDetailSheet(
        city: city,
        onViewModernLocation: () {
          Navigator.of(sheetContext).pop();
          showDialog(
            context: context,
            builder: (_) => GoogleMyMapDialog(selectedCity: city),
          );
        },
      ),
    );
  }

  /// Handles a tap on a city in the navigation drawer list.
  void _onCityTappedFromList(City city) {
    if (!_isWide) Navigator.of(context).pop();

    if (_isPickerMode) {
      // Select it for placement on the map.
      setState(
          () => _selectedCityId = _selectedCityId == city.id ? null : city.id);
    } else {
      setState(() => _selectedCityId = city.id);
      _focusCity(city);
      _openCityDetail(city);
    }
  }

  @override
  Widget build(BuildContext context) {
    final citiesState = ref.watch(citiesProvider);
    final filteredCities = ref.watch(filteredCitiesProvider);

    // Set of ids currently visible after filtering, used to dim hidden pins.
    final visibleIds = filteredCities.map((c) => c.id).toSet();
    final query = ref.watch(searchQueryProvider);
    final bool isFiltering = query.trim().isNotEmpty ||
        ref.watch(selectedClimeFilterProvider) != null;

    final screenWidth = MediaQuery.sizeOf(context).width;
    _isWide = screenWidth >= 900;
    return Scaffold(
      drawer: _isWide
          ? null
          : CityListDrawer(
              isPickerMode: _isPickerMode,
              selectedCityId: _selectedCityId,
              onCityTap: _onCityTappedFromList,
            ),
      appBar: AppBar(
        title: screenWidth >= 600
            ? Text(_isWide ? 'Al-Idrisi Map (1154 CE)' : 'Al-Idrisi Map')
            : null,
        actions: [
          IconButton(
            tooltip: _useEnglishMap
                ? 'Switch to Arabic map'
                : 'Switch to English map',
            icon: Icon(_useEnglishMap ? Icons.g_translate : Icons.translate),
            onPressed: _switchMap,
          ),
          IconButton(
            tooltip: 'Modern map reference',
            icon: const Icon(Icons.public),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const GoogleMyMapDialog(),
            ),
          ),
          IconButton(
            tooltip: _isPickerMode ? 'Exit pin editor' : 'Edit map pins',
            icon: Icon(_isPickerMode
                ? Icons.edit_location_alt
                : Icons.edit_location_alt_outlined),
            color: _isPickerMode ? const Color(0xFFE8D3A7) : null,
            onPressed: () => setState(() {
              _isPickerMode = !_isPickerMode;
              if (!_isPickerMode) _selectedCityId = null;
            }),
          ),
          IconButton(
            tooltip: 'Clear all saved pins',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _isResetting || _isSaving ? null : _resetToDefaults,
          ),
          if (_pendingChanges.isNotEmpty)
            IconButton(
              tooltip: 'Save pin positions',
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              onPressed: _isSaving ? null : _savePendingChanges,
            ),
        ],
      ),
      body: Row(
        children: [
          if (_isWide)
            SizedBox(
              width: 320,
              child: CityListDrawer(
                asPanel: true,
                isPickerMode: _isPickerMode,
                selectedCityId: _selectedCityId,
                onCityTap: _onCityTappedFromList,
              ),
            ),
          Expanded(
              child: Column(children: [
            _SearchAndFilterBar(
              isPickerMode: _isPickerMode,
              selectedCityId: _selectedCityId,
              onSelectCity: (id) => setState(() => _selectedCityId = id),
            ),
            if (_isPickerMode && _selectedCityId != null)
              _PlacementHint(selectedCityId: _selectedCityId!),
            Expanded(
                child: citiesState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error loading cities: $err',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red)),
                ),
              ),
              data: (cities) {
                return LayoutBuilder(builder: (context, constraints) {
                  _updateViewport(constraints.biggest);
                  return Stack(fit: StackFit.expand, children: [
                    Positioned.fill(
                        child: InteractiveViewer(
                      key: _viewportKey,
                      transformationController: _transformController,
                      constrained: false,
                      boundaryMargin: const EdgeInsets.all(1000),
                      minScale: _fitScale,
                      maxScale: 1.5,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (_isPickerMode && _selectedCityId != null)
                            ? (details) => _placeCityAt(
                                _selectedCityId!, details.globalPosition)
                            : null,
                        child: SizedBox(
                          width: _canvasSize.width,
                          height: _canvasSize.height,
                          child: ValueListenableBuilder<Matrix4>(
                            valueListenable: _transformController,
                            child: Positioned.fill(
                              child: Image.asset(
                                _previewAsset,
                                fit: BoxFit.fill,
                                filterQuality: FilterQuality.low,
                                frameBuilder: (context, child, frame,
                                        wasSynchronouslyLoaded) =>
                                    frame != null || wasSynchronouslyLoaded
                                        ? child
                                        : Center(
                                            child: SizedBox(
                                              width: 800,
                                              height: 800,
                                              child:
                                                  const CircularProgressIndicator(
                                                strokeWidth: 80,
                                              ),
                                            ),
                                          ),
                                errorBuilder: (context, error, stack) =>
                                    const Center(
                                  child: Text(
                                    'The map image could not load. Reload the page.',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                            builder: (context, matrix, preview) => Stack(
                              children: [preview!, ..._visibleTiles()],
                            ),
                          ),
                        ),
                      ),
                    )),
                    ValueListenableBuilder<Matrix4>(
                      valueListenable: _transformController,
                      builder: (context, matrix, _) => Stack(children: [
                        ...cities.map((city) {
                          final px = _effectivePx(city);
                          final py = _effectivePy(city);
                          if (px == null || py == null) {
                            return const SizedBox.shrink();
                          }
                          final bool dimmed =
                              isFiltering && !visibleIds.contains(city.id);
                          final bool staged =
                              _pendingChanges.containsKey(city.id);
                          final displayCoords = MapCoordinates.forDisplay(
                            px,
                            py,
                            english: _useEnglishMap,
                          );

                          return _CityPin(
                            city: city,
                            position: MatrixUtils.transformPoint(
                                matrix,
                                Offset(displayCoords.px * _canvasSize.width,
                                    displayCoords.py * _canvasSize.height)),
                            dimmed: dimmed,
                            staged: staged,
                            isSelected: _selectedCityId == city.id,
                            pickerMode: _isPickerMode,
                            onTap: () {
                              if (_isPickerMode) {
                                setState(() => _selectedCityId =
                                    _selectedCityId == city.id
                                        ? null
                                        : city.id);
                              } else {
                                setState(() => _selectedCityId = city.id);
                                _openCityDetail(city);
                              }
                            },
                            onDrag: _isPickerMode
                                ? (delta) => _dragCityBy(city.id, delta)
                                : null,
                          );
                        }).toList(),
                      ]),
                    ),
                    Positioned(
                        right: 12,
                        bottom: 12,
                        child: Column(children: [
                          FloatingActionButton.small(
                              heroTag: 'zoomIn',
                              tooltip: 'Zoom in',
                              onPressed: () => _zoom(1.6),
                              child: const Icon(Icons.add)),
                          const SizedBox(height: 8),
                          FloatingActionButton.small(
                              heroTag: 'zoomOut',
                              tooltip: 'Zoom out',
                              onPressed: () => _zoom(1 / 1.6),
                              child: const Icon(Icons.remove)),
                          const SizedBox(height: 8),
                          FloatingActionButton.small(
                              heroTag: 'fitMap',
                              tooltip: 'Fit whole map',
                              onPressed: _fitMap,
                              child: const Icon(Icons.fit_screen)),
                        ])),
                  ]);
                });
              },
            )),
          ])),
        ],
      ),
    );
  }
}

/// A single positioned city marker on the map.
class _CityPin extends StatelessWidget {
  final City city;
  final Offset position;
  final bool dimmed;
  final bool staged;
  final bool isSelected;
  final bool pickerMode;
  final VoidCallback onTap;
  final void Function(Offset delta)? onDrag;

  const _CityPin({
    required this.city,
    required this.position,
    required this.dimmed,
    required this.staged,
    required this.isSelected,
    required this.pickerMode,
    required this.onTap,
    this.onDrag,
  });

  @override
  Widget build(BuildContext context) {
    final Color markerColor = staged
        ? Colors.orange
        : isSelected
            ? Colors.yellow
            : Colors.red;

    return Positioned(
      left: position.dx - 18,
      top: position.dy - 32,
      child: Tooltip(
        message: city.name,
        child: Semantics(
          label: '${city.name}, historical map pin',
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            onPanUpdate:
                onDrag == null ? null : (details) => onDrag!(details.delta),
            child: Opacity(
              opacity: dimmed ? 0.25 : 1.0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on,
                      size: 30,
                      color: markerColor,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 5)
                      ]),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        city.name,
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Search field, clime filter chips, and the picker-mode city selector.
class _SearchAndFilterBar extends ConsumerStatefulWidget {
  final bool isPickerMode;
  final String? selectedCityId;
  final void Function(String? id) onSelectCity;

  const _SearchAndFilterBar({
    required this.isPickerMode,
    required this.selectedCityId,
    required this.onSelectCity,
  });

  @override
  ConsumerState<_SearchAndFilterBar> createState() =>
      _SearchAndFilterBarState();
}

class _SearchAndFilterBarState extends ConsumerState<_SearchAndFilterBar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(searchQueryProvider),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(searchQueryProvider, (previous, next) {
      if (_searchController.text != next) {
        _searchController.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      }
    });
    final query = ref.watch(searchQueryProvider);
    final selectedClime = ref.watch(selectedClimeFilterProvider);
    final climesAsync = ref.watch(climesProvider);
    final filteredCities = ref.watch(filteredCitiesProvider);
    final unpinned = filteredCities.where((c) => !c.isPinned).toList();

    return Container(
      color: const Color(0xFF241408),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search city names in English or Arabic',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: Color(0xFFE8D3A7)),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      onPressed: () =>
                          ref.read(searchQueryProvider.notifier).state = '',
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF2C1A0E),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) =>
                ref.read(searchQueryProvider.notifier).state = value,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: const Text('All climes'),
                    selected: selectedClime == null,
                    onSelected: (_) => ref
                        .read(selectedClimeFilterProvider.notifier)
                        .state = null,
                    selectedColor: const Color(0xFF8C2D19),
                    backgroundColor: const Color(0xFF2C1A0E),
                    labelStyle: TextStyle(
                      color:
                          selectedClime == null ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
                ...climesAsync.maybeWhen(
                  data: (climes) => climes.map((clime) {
                    final selected = selectedClime == clime.number;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('Clime ${clime.number}'),
                        selected: selected,
                        onSelected: (_) => ref
                            .read(selectedClimeFilterProvider.notifier)
                            .state = selected ? null : clime.number,
                        selectedColor: const Color(0xFF8C2D19),
                        backgroundColor: const Color(0xFF2C1A0E),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                        ),
                      ),
                    );
                  }).toList(),
                  orElse: () => <Widget>[],
                ),
              ],
            ),
          ),
          if (widget.isPickerMode) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: unpinned.isEmpty
                  ? const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'All visible cities are pinned.',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: unpinned.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final city = unpinned[index];
                        final selected = city.id == widget.selectedCityId;
                        return ChoiceChip(
                          avatar: Icon(
                            selected ? Icons.check : Icons.add,
                            size: 16,
                            color: selected ? Colors.white : Colors.white70,
                          ),
                          label: Text(city.name),
                          selected: selected,
                          onSelected: (_) =>
                              widget.onSelectCity(selected ? null : city.id),
                          selectedColor: const Color(0xFF8C2D19),
                          backgroundColor: const Color(0xFF2C1A0E),
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : Colors.white70,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A short instruction banner shown while a city is selected for placement.
class _PlacementHint extends ConsumerWidget {
  final String selectedCityId;

  const _PlacementHint({required this.selectedCityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cities = ref.watch(citiesProvider).maybeWhen(
          data: (list) => list,
          orElse: () => const <City>[],
        );
    final city = cities.where((c) => c.id == selectedCityId).firstOrNull;
    final label = city?.name ?? 'the selected city';

    return Container(
      width: double.infinity,
      color: const Color(0xFF8C2D19).withValues(alpha: 0.25),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.touch_app, size: 18, color: Color(0xFFE8D3A7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tap the map to place "$label", then press Save.',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

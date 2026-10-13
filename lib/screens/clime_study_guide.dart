import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/clime_model.dart';
import '../providers/map_providers.dart';
import '../providers/search_providers.dart';
import '../theme/clime_palette.dart';
import 'google_map_dialog.dart';

/// A schematic learning aid; these bands are not a projection onto the scan.
class ClimeStudyGuide extends ConsumerStatefulWidget {
  const ClimeStudyGuide({super.key});
  @override
  ConsumerState<ClimeStudyGuide> createState() => _ClimeStudyGuideState();
}

class _ClimeStudyGuideState extends ConsumerState<ClimeStudyGuide> {
  bool _southUp = false;
  late int _selected = ref.read(selectedClimeFilterProvider) ?? 1;

  @override
  Widget build(BuildContext context) {
    final counts = <int, int>{};
    for (final city in ref.watch(citiesProvider).valueOrNull ?? []) {
      counts.update(city.clime, (count) => count + 1, ifAbsent: () => 1);
    }
    final climes = ref.watch(climesProvider);
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: ClimePalette.panel,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: 720,
        height: math.min(MediaQuery.sizeOf(context).height - 24, 850),
        child: Column(children: [
          AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: ClimePalette.panelRaised,
            foregroundColor: ClimePalette.parchment,
            title: const Text('Understand the seven climes',
                style: TextStyle(fontSize: 17),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                  tooltip: 'Close clime guide',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close))
            ],
          ),
          Expanded(
              child: climes.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) =>
                const Center(child: Text('Clime guide could not load.')),
            data: (list) {
              final selected =
                  list.firstWhere((clime) => clime.number == _selected);
              final ordered = _southUp ? list : list.reversed.toList();
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('A world organized into belts',
                        style: TextStyle(
                            color: ClimePalette.parchment,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                        'Medieval geographers divided the inhabited world into seven broad climes. Select a belt to explore its places and connections.',
                        style: TextStyle(color: Colors.white70, height: 1.6)),
                    const SizedBox(height: 16),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      ChoiceChip(
                          label: const Text('North up'),
                          avatar: const Icon(Icons.north, size: 17),
                          selected: !_southUp,
                          onSelected: (_) => setState(() => _southUp = false)),
                      ChoiceChip(
                          label: const Text('Idrisi: south up'),
                          avatar: const Icon(Icons.south, size: 17),
                          selected: _southUp,
                          onSelected: (_) => setState(() => _southUp = true)),
                    ]),
                    const SizedBox(height: 18),
                    Text(
                        _southUp
                            ? 'SOUTH · top of the historical map'
                            : 'NORTH · top of a modern map',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 8),
                    for (final clime in ordered)
                      _ClimeBelt(
                          clime: clime,
                          count: counts[clime.number] ?? 0,
                          selected: clime.number == _selected,
                          onTap: () =>
                              setState(() => _selected = clime.number)),
                    const SizedBox(height: 8),
                    Text(
                        _southUp
                            ? 'NORTH · bottom of the historical map'
                            : 'SOUTH',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 18),
                    const Text(
                        'The belts are schematic. Catalog membership follows the journal; it is not calculated from a location’s present-day latitude.',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 12, height: 1.5)),
                    const SizedBox(height: 22),
                    Text('Clime ${selected.number} · ${selected.shortTitle}',
                        style: const TextStyle(
                            color: ClimePalette.parchment,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(selected.description,
                        style: const TextStyle(
                            color: Colors.white70, height: 1.6)),
                    const SizedBox(height: 10),
                    Text(selected.bounds,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12, height: 1.5)),
                  ],
                ),
              );
            },
          )),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                TextButton.icon(
                    icon: const Icon(Icons.public),
                    label: const Text('Custom modern map'),
                    onPressed: () => showDialog(
                        context: context,
                        builder: (_) => const GoogleMyMapDialog())),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: ClimePalette.of(_selected),
                      foregroundColor: Colors.white),
                  onPressed: (counts[_selected] ?? 0) == 0
                      ? null
                      : () {
                          ref.read(selectedClimeFilterProvider.notifier).state =
                              _selected;
                          Navigator.pop(context);
                        },
                  icon: const Icon(Icons.explore_outlined),
                  label: Text((counts[_selected] ?? 0) == 0
                      ? 'No places cataloged'
                      : 'Explore Clime $_selected'),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _ClimeBelt extends StatelessWidget {
  final ClimeModel clime;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _ClimeBelt(
      {required this.clime,
      required this.count,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = ClimePalette.of(clime.number);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('clime-belt-${clime.number}'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: selected
                        ? Colors.white70
                        : accent.withValues(alpha: 0.25)),
                gradient: LinearGradient(colors: [
                  accent.withValues(alpha: 0.55),
                  accent.withValues(alpha: 0.15)
                ]),
              ),
              child: Row(children: [
                SizedBox(
                    width: 28,
                    child: Text('${clime.number}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold))),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(clime.shortTitle,
                        maxLines: 2,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600))),
                const SizedBox(width: 8),
                Text(count == 0 ? 'Empty' : '$count places',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 11)),
              ]),
            ),
          )),
    );
  }
}

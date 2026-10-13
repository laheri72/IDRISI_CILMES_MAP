import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/city_model.dart';
import '../theme/clime_palette.dart';

/// A reading panel with independent scrolling and a persistent map action.
class CityDetailSheet extends StatelessWidget {
  final City city;
  final VoidCallback onViewModernLocation;
  const CityDetailSheet(
      {super.key, required this.city, required this.onViewModernLocation});

  @override
  Widget build(BuildContext context) {
    final accent = ClimePalette.of(city.clime);
    final hasLegacy = city.legacySections.isNotEmpty;
    final sections = city.historySections.isEmpty
        ? [
            HistorySection(
                title: 'Historical significance', paragraphs: [city.history])
          ]
        : city.historySections;
    return DefaultTabController(
      length: hasLegacy ? 3 : 2,
      child: Container(
        height: math.min(MediaQuery.sizeOf(context).height * 0.9, 840),
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
            color: ClimePalette.panel,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
            decoration: BoxDecoration(
                gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent.withValues(alpha: 0.23), ClimePalette.panel],
            )),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(4)))),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _Badge(label: 'CLIME ${city.clime}', color: accent),
                  _Badge(
                      label: city.pinBasis == 'region'
                          ? 'Regional reference'
                          : city.placeType,
                      color: Colors.white54),
                  if (city.pinBasis == 'estimated')
                    const _Badge(
                        label: 'Approximate historical pin',
                        color: Color(0xFFE8B96C)),
                ]),
                const SizedBox(height: 14),
                Text(city.name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: ClimePalette.parchment,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1.2)),
                const SizedBox(height: 7),
                Text(city.arabicName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 18)),
              ],
            ),
          ),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: accent,
            labelColor: ClimePalette.parchment,
            unselectedLabelColor: Colors.white54,
            tabs: [
              const Tab(text: 'History'),
              if (hasLegacy) const Tab(text: 'Legacy today'),
              const Tab(text: 'Sources'),
            ],
          ),
          Expanded(
              child: TabBarView(children: [
            _SectionReader(sections: sections, accent: accent),
            if (hasLegacy)
              _SectionReader(sections: city.legacySections, accent: accent),
            _SourcesReader(city: city),
          ])),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                20, 12, 20, MediaQuery.paddingOf(context).bottom + 16),
            decoration: const BoxDecoration(
                color: ClimePalette.panelRaised,
                border: Border(top: BorderSide(color: Colors.white10))),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15)),
              onPressed: onViewModernLocation,
              icon: const Icon(Icons.public),
              label: const Text('View modern location'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.45))),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );
}

class _SectionReader extends StatelessWidget {
  final List<HistorySection> sections;
  final Color accent;
  const _SectionReader({required this.sections, required this.accent});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final section in sections) ...[
              Text(section.title,
                  style: const TextStyle(
                      color: ClimePalette.parchment,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.35)),
              const SizedBox(height: 12),
              for (final paragraph in section.paragraphs) ...[
                SelectableText(paragraph,
                    style: const TextStyle(
                        color: Color(0xFFDDD4D0), fontSize: 15, height: 1.65)),
                const SizedBox(height: 14),
              ],
              if (section != sections.last) ...[
                Divider(color: accent.withValues(alpha: 0.3)),
                const SizedBox(height: 18),
              ],
            ],
          ],
        ),
      );
}

class _SourcesReader extends StatelessWidget {
  final City city;
  const _SourcesReader({required this.city});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Ikhwan al-Safa Climes Journal · V9',
              style: TextStyle(
                  color: ClimePalette.parchment,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SelectableText(
              city.sourceNote.isEmpty
                  ? 'Historical catalog account.'
                  : city.sourceNote,
              style: const TextStyle(color: Colors.white70, height: 1.6)),
          if (city.pinNote.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Historical pin evidence',
                style: TextStyle(
                    color: ClimePalette.parchment,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SelectableText(city.pinNote,
                style: const TextStyle(color: Colors.white70, height: 1.6)),
          ],
          if (city.sources.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('References listed in the journal',
                style: TextStyle(
                    color: ClimePalette.parchment,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            for (final source in city.sources)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: source.url == null
                    ? SelectableText(source.label,
                        style:
                            const TextStyle(color: Colors.white70, height: 1.5))
                    : InkWell(
                        onTap: () => launchUrl(Uri.parse(source.url!),
                            mode: LaunchMode.externalApplication),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [
                            Expanded(
                                child: Text(source.label,
                                    style: const TextStyle(
                                        color: ClimePalette.parchment,
                                        height: 1.5))),
                            const SizedBox(width: 10),
                            const Icon(Icons.open_in_new,
                                size: 16, color: Colors.white54),
                          ]),
                        ),
                      ),
              ),
          ],
        ]),
      );
}

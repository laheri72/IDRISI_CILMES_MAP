import 'package:flutter/material.dart';
import '../models/city_model.dart';

/// A draggable bottom sheet showing the full historical record for a city.
class CityDetailSheet extends StatelessWidget {
  final City city;
  final VoidCallback onViewModernLocation;

  const CityDetailSheet({
    Key? key,
    required this.city,
    required this.onViewModernLocation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2C1A0E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.location_city,
                    color: Color(0xFFE8D3A7), size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        city.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        city.arabicName,
                        textDirection: TextDirection.rtl,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: const Color(0xFFE8D3A7),
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text('Clime ${city.clime}'),
                  backgroundColor: const Color(0xFF8C2D19),
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _SectionTitle(
              icon: Icons.history_edu,
              title: 'Historical Significance',
            ),
            const SizedBox(height: 6),
            Text(
              city.history,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8C2D19),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.map),
                label: const Text('View modern location'),
                onPressed: onViewModernLocation,
              ),
            ),
            SizedBox(height: mediaQuery.padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFE8D3A7)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFE8D3A7),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

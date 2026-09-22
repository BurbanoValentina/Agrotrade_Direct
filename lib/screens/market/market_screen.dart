import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/market_provider.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/role_toggle.dart';
import '../../widgets/stat_chip.dart';
import '../../widgets/theme_toggle_button.dart';
import 'widgets/counter_offer_sheet.dart';
import 'widgets/offer_card.dart';

/// Pantalla "Live Market" — REQ-06 a REQ-13.
class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarketProvider>().loadOffers();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketProvider>();
    final user = context.watch<AuthProvider>().currentUser;
    final colors = context.colors;

    return SafeArea(
      child: ResponsiveContainer(
        maxWidth: 1000,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            if (user != null) RoleToggle(selected: user.role),
            const SizedBox(height: 16),

            // Header: Title & Live pulse & Theme toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Live Market', style: Theme.of(context).textTheme.headlineLarge),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: colors.statusActive.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.statusActive.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: colors.statusActive,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'EN VIVO',
                                style: TextStyle(
                                  color: colors.statusActive,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${market.visibleOffers.length} ofertas activas de Colombia hacia la Unión Europea',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                const ThemeToggleButton(compact: true),
              ],
            ),
            const SizedBox(height: 14),

            // Search Bar
            TextField(
              controller: _searchCtrl,
              onChanged: market.setQuery,
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar variedad, origen o exportador...',
                prefixIcon: Icon(Icons.search_rounded, color: colors.textMuted, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded, color: colors.textMuted, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          market.setQuery('');
                          setState(() {});
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // Filter Chips
            Row(
              children: [
                _FilterChip(
                  label: 'Todos',
                  selected: market.filter == MarketFilter.all,
                  onTap: () => market.setFilter(MarketFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: '☕ Café',
                  selected: market.filter == MarketFilter.cafe,
                  onTap: () => market.setFilter(MarketFilter.cafe),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: '🍫 Cacao',
                  selected: market.filter == MarketFilter.cacao,
                  onTap: () => market.setFilter(MarketFilter.cacao),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Commodity Ticker
            const SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  StatChip(
                    label: 'Arabica ICE',
                    value: '\$4,210',
                    changePercent: 1.2,
                  ),
                  SizedBox(width: 8),
                  StatChip(
                    label: 'Cacao LME',
                    value: '\$6,870',
                    changePercent: 0.8,
                  ),
                  SizedBox(width: 8),
                  StatChip(
                    label: 'USD/EUR',
                    value: '\$0.921',
                    changePercent: -0.1,
                  ),
                  SizedBox(width: 8),
                  StatChip(
                    label: 'Robusta',
                    value: '\$2,340',
                    changePercent: 2.1,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Offers List
            Expanded(
              child: market.isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: colors.gold),
                    )
                  : market.visibleOffers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded, size: 48, color: colors.textMuted),
                              const SizedBox(height: 14),
                              Text(
                                'Sin resultados para tu búsqueda',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Prueba cambiando las palabras clave o los filtros.',
                                style: TextStyle(color: colors.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: colors.gold,
                          onRefresh: market.loadOffers,
                          child: ListView.builder(
                            itemCount: market.visibleOffers.length,
                            itemBuilder: (context, index) {
                              final offer = market.visibleOffers[index];
                              return OfferCard(
                                offer: offer,
                                onMakeOffer: () async {
                                  final price = await showCounterOfferSheet(
                                    context,
                                    offer: offer,
                                  );
                                  if (price == null || !context.mounted) return;
                                  final ok = await market.sendCounterOffer(offer.id, price);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? 'Contraoferta de \$${price.toStringAsFixed(0)}/MT enviada'
                                            : 'No se pudo enviar la contraoferta',
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? colors.gold.withValues(alpha: 0.15) : colors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? colors.gold : colors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected ? colors.gold : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/market_provider.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/role_toggle.dart';
import '../../widgets/stat_chip.dart';
import '../../widgets/theme_toggle_button.dart';
import 'widgets/counter_offer_sheet.dart';
import 'widgets/create_offer_sheet.dart';
import 'widgets/filter_sheet.dart';
import 'widgets/offer_card.dart';

/// Pantalla "Live Market" — REQ-06 a REQ-13 & REQ-31 (Traducción Dinámica).
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
    final localeProvider = context.watch<LocaleProvider>();
    final colors = context.colors;
    final isExporter = user?.role == UserRole.exportador;

    // Helper de traducción dinámico (REQ-31)
    final loc = AppLocalizations.of(context);

    return Scaffold(
      // Fondo transparente para respetar el fondo del shell padre
      backgroundColor: Colors.transparent,

      // Botón para publicar ofertas (solo exportadores)
      floatingActionButton: isExporter
          ? FloatingActionButton.extended(
              onPressed: () async {
                final newOffer = await showCreateOfferSheet(context);
                if (newOffer == null || !context.mounted) return;

                final ok =
                    await context.read<MarketProvider>().addOffer(newOffer);
                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'Oferta publicada exitosamente'
                        : 'Error al publicar la oferta'),
                    backgroundColor:
                        ok ? Colors.green.shade800 : Colors.redAccent,
                  ),
                );
              },
              backgroundColor: colors.gold,
              icon: Icon(
                Icons.add,
                color: colors.isDark ? Colors.black : Colors.white,
              ),
              label: Text(
                loc.translate('publish_offer'),
                style: TextStyle(
                  color: colors.isDark ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 1000,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              if (user != null) RoleToggle(selected: user.role),
              const SizedBox(height: 16),

              // Cabecera: Título traducido, indicador en vivo, idioma y tema
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                loc.translate('live_market'),
                                style:
                                    Theme.of(context).textTheme.headlineLarge,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color:
                                    colors.statusActive.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: colors.statusActive
                                      .withValues(alpha: 0.4),
                                ),
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
                          '${market.visibleOffers.length} ${loc.translate('active_offers')}',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // REQ-31: Selector de idioma
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: colors.surfaceAlt,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      context.read<LocaleProvider>().toggleLanguage();
                    },
                    child: Text(
                      localeProvider.isSpanish ? 'ES' : 'EN',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colors.gold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // REQ-26: Selector de tema
                  const ThemeToggleButton(compact: true),
                ],
              ),
              const SizedBox(height: 14),

              // Caja de Búsqueda + botón de filtros avanzados
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: market.setQuery,
                      style: TextStyle(color: colors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: loc.translate('search_placeholder'),
                        prefixIcon: Icon(Icons.search_rounded,
                            color: colors.textMuted, size: 20),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.close_rounded,
                                    color: colors.textMuted, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  market.setQuery('');
                                  setState(() {});
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: colors.surfaceAlt,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(Icons.tune, color: colors.gold),
                    onPressed: () async {
                      final options = await showFilterSheet(
                        context,
                        initialOptions: market.filterOptions,
                      );
                      if (options != null && context.mounted) {
                        context
                            .read<MarketProvider>()
                            .setAdvancedFilterOptions(options);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Chips de Filtro Rápido
              Row(
                children: [
                  _FilterChip(
                    label: loc.translate('all'),
                    selected: market.filter == MarketFilter.all,
                    onTap: () => market.setFilter(MarketFilter.all),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: '☕ ${loc.translate('coffee')}',
                    selected: market.filter == MarketFilter.cafe,
                    onTap: () => market.setFilter(MarketFilter.cafe),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: '🍫 ${loc.translate('cacao')}',
                    selected: market.filter == MarketFilter.cacao,
                    onTap: () => market.setFilter(MarketFilter.cacao),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Indicadores estadísticos de commodities
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

              // Lista de ofertas
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
                                Icon(Icons.search_off_rounded,
                                    size: 48, color: colors.textMuted),
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
                                  style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 13),
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
                                    if (price == null || !context.mounted) {
                                      return;
                                    }
                                    final ok = await market.sendCounterOffer(
                                        offer.id, price);
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
          color: selected
              ? colors.gold.withValues(alpha: 0.15)
              : colors.surfaceAlt,
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
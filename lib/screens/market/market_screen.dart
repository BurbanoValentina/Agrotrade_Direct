import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/market_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/role_toggle.dart';
import '../../widgets/stat_chip.dart';

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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarketProvider>().loadOffers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketProvider>();
    final user = context.watch<AuthProvider>().currentUser;
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final isExporter = user?.role == UserRole.exportador;

    // Helper de traducción dinámico (REQ-31)
    final loc = AppLocalizations.of(context);

    return Scaffold(
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
              backgroundColor: AppColors.gold,
              icon: const Icon(Icons.add, color: Colors.black),
              label: Text(
                loc.translate('publish_offer'),
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              if (user != null) RoleToggle(selected: user.role),
              const SizedBox(height: 20),

              // Cabecera con Título traducido, Selector de Idioma y Tema
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    loc.translate('live_market'),
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  Row(
                    children: [
                      // REQ-31: Selector de idioma
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: themeProvider.isDarkMode
                              ? AppColors.surfaceAlt
                              : AppColors.lightSurfaceAlt,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          context.read<LocaleProvider>().toggleLanguage();
                        },
                        child: Text(
                          localeProvider.isSpanish ? 'ES' : 'EN',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // REQ-26: Selector de tema
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: themeProvider.isDarkMode
                              ? AppColors.surfaceAlt
                              : AppColors.lightSurfaceAlt,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(
                          themeProvider.isDarkMode
                              ? Icons.wb_sunny_outlined
                              : Icons.nightlight_round,
                          color: AppColors.gold,
                        ),
                        onPressed: () {
                          context
                              .read<ThemeProvider>()
                              .toggleTheme(!themeProvider.isDarkMode);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${market.visibleOffers.length} ${loc.translate('active_offers')}',
                style: TextStyle(
                  color: themeProvider.isDarkMode
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),

              // Caja de Búsqueda
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: market.setQuery,
                      style: TextStyle(
                        color: themeProvider.isDarkMode
                            ? AppColors.textPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: loc.translate('search_placeholder'),
                        prefixIcon: const Icon(Icons.search,
                            color: AppColors.textMuted),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: themeProvider.isDarkMode
                          ? AppColors.surfaceAlt
                          : AppColors.lightSurfaceAlt,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.tune, color: AppColors.gold),
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
                    label: loc.translate('coffee'),
                    selected: market.filter == MarketFilter.cafe,
                    onTap: () => market.setFilter(MarketFilter.cafe),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: loc.translate('cacao'),
                    selected: market.filter == MarketFilter.cacao,
                    onTap: () => market.setFilter(MarketFilter.cacao),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Indicadores estadísticos
              const SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    StatChip(
                        label: 'Arabica ICE',
                        value: '\$4,210',
                        changePercent: 1.2),
                    SizedBox(width: 8),
                    StatChip(
                        label: 'Cacao LME',
                        value: '\$6,870',
                        changePercent: 0.8),
                    SizedBox(width: 8),
                    StatChip(
                        label: 'USD/EUR',
                        value: '\$0.921',
                        changePercent: -0.1),
                    SizedBox(width: 8),
                    StatChip(
                        label: 'Robusta', value: '\$2,340', changePercent: 2.1),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Lista de ofertas
              Expanded(
                child: market.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
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
                                final ok = await market.sendCounterOffer(
                                    offer.id, price);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(ok
                                        ? 'Contraoferta de \$${price.toStringAsFixed(0)}/MT enviada'
                                        : 'No se pudo enviar la contraoferta'),
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
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold
              : (isDark ? AppColors.surface : AppColors.lightSurface),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.gold
                : (isDark ? AppColors.border : AppColors.lightBorder),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.black
                : (isDark
                    ? AppColors.textSecondary
                    : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/market_provider.dart';
import '../../widgets/role_toggle.dart';
import '../../widgets/stat_chip.dart';
import '../../widgets/theme_toggle_button.dart';
import 'widgets/counter_offer_sheet.dart';
import 'widgets/create_offer_sheet.dart';
import 'widgets/filter_sheet.dart';
import 'widgets/offer_card.dart';

/// Pantalla "Live Market" con Layout Dividido Profesional (Split-Layout).
/// - En pantallas amplias (Desktop/Web): Panel Izquierdo con Controles, Filtros y Herramientas del Rol
///   y Panel Derecho con el catálogo completo de Live Market.
/// - En pantallas móviles: Flujo apilado vertical con márgenes amplios y diseño adaptativo.
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
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isExporter
          ? FloatingActionButton.extended(
              onPressed: () async {
                final newOffer = await showCreateOfferSheet(context);
                if (newOffer == null || !context.mounted) return;

                final ok = await context.read<MarketProvider>().addOffer(newOffer);
                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'Oferta publicada exitosamente'
                        : 'Error al publicar la oferta'),
                    backgroundColor: ok ? Colors.green.shade800 : Colors.redAccent,
                  ),
                );
              },
              backgroundColor: colors.gold,
              icon: Icon(
                Icons.add_rounded,
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 980;

            if (isDesktop) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── PANEL IZQUIERDO: Filtros, Rol y Herramientas ──
                    SizedBox(
                      width: 360,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (user != null) RoleToggle(selected: user.role),
                            const SizedBox(height: 16),

                            // Banner contextual interactivo del Rol
                            _buildRoleBanner(colors, isExporter),
                            const SizedBox(height: 16),

                            // Ticker Bursátil en vivo
                            _buildMarketTicker(colors),
                            const SizedBox(height: 16),

                            // Caja de Búsqueda y Filtros
                            _buildSearchAndFilters(context, colors, market, loc),
                            const SizedBox(height: 16),

                            // Panel de Acceso Rápido y Métricas de Rol
                            _buildRoleActionCard(context, colors, isExporter),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),

                    // ── PANEL DERECHO: Live Market Feed ──
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeaderBar(context, colors, market, localeProvider, loc),
                          const SizedBox(height: 14),
                          Expanded(
                            child: _buildOffersList(context, colors, market, loc),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            // ── VISTA MÓVIL/TABLET: Flujo vertical con márgenes confortables ──
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (user != null) RoleToggle(selected: user.role),
                  const SizedBox(height: 12),
                  _buildRoleBanner(colors, isExporter),
                  const SizedBox(height: 14),
                  _buildHeaderBar(context, colors, market, localeProvider, loc),
                  const SizedBox(height: 12),
                  _buildSearchAndFilters(context, colors, market, loc),
                  const SizedBox(height: 10),
                  _buildMarketTicker(colors),
                  const SizedBox(height: 14),
                  Expanded(
                    child: _buildOffersList(context, colors, market, loc),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRoleBanner(AppThemeColors colors, bool isExporter) {
    final bannerColor = isExporter ? colors.gold : const Color(0xFF3B82F6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            bannerColor.withValues(alpha: colors.isDark ? 0.22 : 0.12),
            colors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: bannerColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: bannerColor.withValues(alpha: colors.isDark ? 0.15 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: bannerColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isExporter ? Icons.agriculture_rounded : Icons.public_rounded,
              color: bannerColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExporter
                      ? '🇨🇴 Exportador · Colombia'
                      : '🇪🇺 Importador · Unión Europea',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isExporter
                      ? 'Publica lotes de café de especialidad y cacao fino con trazabilidad certificada hacia Europa.'
                      : 'Cierra acuerdos bilaterales directos con cooperativas y productores sin sobrecostos de intermediación.',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleActionCard(BuildContext context, AppThemeColors colors, bool isExporter) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isExporter ? Icons.verified_rounded : Icons.gavel_rounded,
                size: 16,
                color: colors.gold,
              ),
              const SizedBox(width: 8),
              Text(
                isExporter ? 'Regulaciones y Calidad' : 'Garantías UE & Aduana',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isExporter
                ? 'Todas tus ofertas incluyen sello de origen Huila, Nariño o Sierra Nevada conforme a normativas de no deforestación EUTR.'
                : 'Tus compras cuentan con custodia segura de fondos y verificación fitosanitaria previa al embarque.',
            style: TextStyle(color: colors.textMuted, fontSize: 11, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(
    BuildContext context,
    AppThemeColors colors,
    MarketProvider market,
    LocaleProvider localeProvider,
    AppLocalizations loc,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              loc.translate('live_market'),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colors.statusActive.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colors.statusActive.withValues(alpha: 0.4),
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
        Row(
          children: [
            Text(
              '${market.visibleOffers.length} ofertas',
              style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 12),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: colors.surfaceAlt,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () => context.read<LocaleProvider>().toggleLanguage(),
              child: Text(
                localeProvider.isSpanish ? 'ES' : 'EN',
                style: TextStyle(fontWeight: FontWeight.bold, color: colors.gold, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            const ThemeToggleButton(compact: true),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters(
    BuildContext context,
    AppThemeColors colors,
    MarketProvider market,
    AppLocalizations loc,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: market.setQuery,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: loc.translate('search_placeholder'),
                    prefixIcon: Icon(Icons.search_rounded, color: colors.textMuted, size: 18),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close_rounded, color: colors.textMuted, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              market.setQuery('');
                              setState(() {});
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: colors.surfaceAlt,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(Icons.tune_rounded, color: colors.gold, size: 20),
                onPressed: () async {
                  final options = await showFilterSheet(
                    context,
                    initialOptions: market.filterOptions,
                  );
                  if (options != null && context.mounted) {
                    context.read<MarketProvider>().setAdvancedFilterOptions(options);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _FilterChip(
                label: loc.translate('all'),
                selected: market.filter == MarketFilter.all,
                onTap: () => market.setFilter(MarketFilter.all),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: '☕ ${loc.translate('coffee')}',
                selected: market.filter == MarketFilter.cafe,
                onTap: () => market.setFilter(MarketFilter.cafe),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: '🍫 ${loc.translate('cacao')}',
                selected: market.filter == MarketFilter.cacao,
                onTap: () => market.setFilter(MarketFilter.cacao),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMarketTicker(AppThemeColors colors) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: const Row(
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
    );
  }

  Widget _buildOffersList(
    BuildContext context,
    AppThemeColors colors,
    MarketProvider market,
    AppLocalizations loc,
  ) {
    if (market.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: colors.gold),
      );
    }

    if (market.visibleOffers.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
        ),
      );
    }

    return RefreshIndicator(
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? colors.gold : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
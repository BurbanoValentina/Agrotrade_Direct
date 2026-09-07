import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/market_provider.dart';
import '../../widgets/role_toggle.dart';
import '../../widgets/stat_chip.dart';
import 'widgets/counter_offer_sheet.dart';
import 'widgets/offer_card.dart';

/// Pantalla "Live Market" — REQ-06 a REQ-13.
class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  @override
  void initState() {
    super.initState();
    // Carga inicial de ofertas (mock hoy, Supabase mañana).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarketProvider>().loadOffers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketProvider>();
    final user = context.watch<AuthProvider>().currentUser;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            if (user != null) RoleToggle(selected: user.role),
            const SizedBox(height: 20),
            Text('Live Market', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 4),
            Text(
              '${market.visibleOffers.length} ofertas activas de Colombia',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: market.setQuery,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Buscar variedad, origen...',
                prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: market.filter == MarketFilter.all,
                  onTap: () => market.setFilter(MarketFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Coffee',
                  selected: market.filter == MarketFilter.cafe,
                  onTap: () => market.setFilter(MarketFilter.cafe),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Cacao',
                  selected: market.filter == MarketFilter.cacao,
                  onTap: () => market.setFilter(MarketFilter.cacao),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                StatChip(label: 'Arabica ICE', value: '\$4,210', changePercent: 1.2),
                SizedBox(width: 8),
                StatChip(label: 'Cacao LME', value: '\$6,870', changePercent: 0.8),
                SizedBox(width: 8),
                StatChip(label: 'USD/EUR', value: '\$0.921', changePercent: -0.1),
                SizedBox(width: 8),
                StatChip(label: 'Robusta', value: '\$2,340', changePercent: 2.1),
              ],
            ),
            const SizedBox(height: 16),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.black : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

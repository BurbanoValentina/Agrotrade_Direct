import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/crop_offer.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/responsive_layout.dart';

class AdminOffersScreen extends StatefulWidget {
  const AdminOffersScreen({super.key});

  @override
  State<AdminOffersScreen> createState() => _AdminOffersScreenState();
}

class _AdminOffersScreenState extends State<AdminOffersScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'Todas'; // Todas, Café, Cacao
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final admin = context.watch<AdminProvider>();
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);

    final filteredOffers = admin.offers.where((offer) {
      final q = _searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty ||
          offer.variety.toLowerCase().contains(q) ||
          offer.sellerName.toLowerCase().contains(q) ||
          offer.originCountry.toLowerCase().contains(q);

      final matchesFilter = _selectedFilter == 'Todas' ||
          (_selectedFilter == 'Café' && offer.cropType.name == 'cafe') ||
          (_selectedFilter == 'Cacao' && offer.cropType.name == 'cacao');

      return matchesSearch && matchesFilter;
    }).toList();

    return ResponsiveContainer(
      maxWidth: 1000,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          // Search & Filter Header
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: TextStyle(color: colors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Buscar por variedad, origen o vendedor...',
                    prefixIcon: Icon(Icons.search_rounded, color: colors.textMuted, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close_rounded, color: colors.textMuted, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Filters Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Todas', 'Todas', colors),
                const SizedBox(width: 8),
                _buildFilterChip('Café', '☕ Café', colors),
                const SizedBox(width: 8),
                _buildFilterChip('Cacao', '🍫 Cacao', colors),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Offers List
          Expanded(
            child: filteredOffers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: colors.textMuted),
                        const SizedBox(height: 14),
                        Text(
                          'No se encontraron ofertas',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Prueba cambiando los filtros o la búsqueda.',
                          style: TextStyle(color: colors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: filteredOffers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final offer = filteredOffers[index];
                      final isCoffee = offer.cropType == CropType.cafe;

                      return Container(
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: colors.isDark ? 0.2 : 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top line: crop badge + status chip
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isCoffee
                                          ? const Color(0xFF8D6E63).withValues(alpha: 0.15)
                                          : const Color(0xFF5D4037).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isCoffee
                                            ? const Color(0xFF8D6E63).withValues(alpha: 0.4)
                                            : const Color(0xFF5D4037).withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(isCoffee ? '☕' : '🍫', style: const TextStyle(fontSize: 12)),
                                        const SizedBox(width: 6),
                                        Text(
                                          offer.cropType.label,
                                          style: TextStyle(
                                            color: isCoffee ? const Color(0xFFBCAAA4) : const Color(0xFFA1887F),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    offer.variety,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: colors.surfaceAlt,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: colors.border),
                                    ),
                                    child: Text(
                                      offer.status.label,
                                      style: TextStyle(
                                        color: colors.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Details: origin and seller
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined, size: 15, color: colors.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${offer.originRegion}, ${offer.originCountry}',
                                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(Icons.storefront_outlined, size: 15, color: colors.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    offer.sellerName,
                                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Price & Volume row
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: colors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: colors.border),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'VOLUMEN',
                                          style: TextStyle(
                                            color: colors.textMuted,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${offer.volumeMt} MT',
                                          style: TextStyle(
                                            color: colors.textPrimary,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'PRECIO POR TONELADA',
                                          style: TextStyle(
                                            color: colors.textMuted,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${currencyFormat.format(offer.askPricePerMt)} / MT',
                                          style: TextStyle(
                                            color: colors.gold,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Actions row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor: colors.textPrimary,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    icon: Icon(Icons.visibility_outlined, color: colors.gold, size: 17),
                                    label: Text(
                                      'Ver Detalle',
                                      style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    onPressed: () => _showOfferDetail(context, offer),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.redAccent,
                                      side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                    label: const Text('Eliminar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                    onPressed: () => _confirmDelete(context, admin, offer.id),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, AppThemeColors colors) {
    final isSelected = _selectedFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? colors.gold.withValues(alpha: 0.15) : colors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? colors.gold : colors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? colors.gold : colors.textSecondary,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _showOfferDetail(BuildContext context, CropOffer offer) {
    final colors = context.colors;
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.border),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.storefront_rounded, color: colors.gold, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detalle de Oferta',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    '${offer.cropType.label} · ${offer.variety}',
                    style: TextStyle(color: colors.gold, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow(colors, 'ID Operación', offer.id),
                _detailRow(colors, 'Tipo de Cultivo', offer.cropType.label),
                _detailRow(colors, 'Variedad', offer.variety),
                _detailRow(colors, 'Origen', '${offer.originRegion}, ${offer.originCountry}'),
                _detailRow(colors, 'Destino Autorizado', offer.destinationCountry),
                _detailRow(colors, 'Volumen Total', '${offer.volumeMt} MT'),
                _detailRow(colors, 'Precio Solicitado', '${currencyFormat.format(offer.askPricePerMt)} / MT'),
                _detailRow(colors, 'Total Estimado', currencyFormat.format(offer.estimatedTotalUsd)),
                _detailRow(colors, 'Vendedor / Exportador', offer.sellerName),
                _detailRow(colors, 'Reputación Vendedor', '${offer.sellerRating} ⭐ (${offer.sellerTrades} operaciones)'),
                _detailRow(colors, 'Certificaciones', offer.certifications.isNotEmpty ? offer.certifications.join(', ') : 'Ninguna'),
                _detailRow(colors, 'Estado de Oferta', offer.status.label),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.gold,
              foregroundColor: colors.isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(AppThemeColors colors, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, AdminProvider admin, String offerId) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.border),
        ),
        title: Text('Eliminar Oferta', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800)),
        content: Text(
          '¿Está seguro de que desea eliminar esta oferta? Esta acción no se puede deshacer.',
          style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              admin.deleteOffer(offerId);
              Navigator.pop(context);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/negotiation.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/responsive_layout.dart';

class AdminNegotiationsScreen extends StatefulWidget {
  const AdminNegotiationsScreen({super.key});

  @override
  State<AdminNegotiationsScreen> createState() => _AdminNegotiationsScreenState();
}

class _AdminNegotiationsScreenState extends State<AdminNegotiationsScreen> {
  String _selectedFilter = 'Todas';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final admin = context.watch<AdminProvider>();
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);

    final filters = ['Todas', 'Pendientes', 'Aceptadas', 'Rechazadas', 'Completadas'];

    final filteredNegotiations = admin.negotiations.where((neg) {
      if (_selectedFilter == 'Todas') return true;
      if (_selectedFilter == 'Pendientes' && neg.status == NegotiationStatus.pendiente) return true;
      if (_selectedFilter == 'Aceptadas' && neg.status == NegotiationStatus.aceptada) return true;
      if (_selectedFilter == 'Rechazadas' && neg.status == NegotiationStatus.rechazada) return true;
      if (_selectedFilter == 'Completadas' && neg.status == NegotiationStatus.completada) return true;
      return false;
    }).toList();

    return ResponsiveContainer(
      maxWidth: 1000,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedFilter = filter),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? colors.gold.withValues(alpha: 0.15) : colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? colors.gold : colors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        filter,
                        style: TextStyle(
                          color: isSelected ? colors.gold : colors.textSecondary,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Negotiations List
          Expanded(
            child: filteredNegotiations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.handshake_outlined, size: 48, color: colors.textMuted),
                        const SizedBox(height: 14),
                        Text(
                          'No hay negociaciones',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'No hay registros para este filtro seleccionado.',
                          style: TextStyle(color: colors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: filteredNegotiations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final neg = filteredNegotiations[index];
                      final priceDiff = neg.proposedPrice - neg.originalPrice;
                      final diffString = priceDiff > 0
                          ? '+${currencyFormat.format(priceDiff)}/MT'
                          : '${currencyFormat.format(priceDiff)}/MT';
                      final diffColor = priceDiff >= 0 ? colors.priceUp : colors.priceDown;

                      final (badgeColor, statusIcon) = switch (neg.status) {
                        NegotiationStatus.pendiente => (colors.gold, Icons.schedule_rounded),
                        NegotiationStatus.aceptada => (colors.statusActive, Icons.check_circle_rounded),
                        NegotiationStatus.rechazada => (Colors.redAccent, Icons.cancel_rounded),
                        NegotiationStatus.completada => (const Color(0xFF3B82F6), Icons.task_alt_rounded),
                      };

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
                              // Top Bar: Variety & Status Badge
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: colors.gold.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.handshake_rounded, color: colors.gold, size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      neg.offerVariety,
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(statusIcon, size: 13, color: badgeColor),
                                        const SizedBox(width: 5),
                                        Text(
                                          neg.status.label,
                                          style: TextStyle(
                                            color: badgeColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Buyer & Seller info
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: colors.surfaceAlt,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'COMPRADOR',
                                            style: TextStyle(
                                              color: colors.textMuted,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            neg.buyerName,
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: colors.surfaceAlt,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'VENDEDOR',
                                            style: TextStyle(
                                              color: colors.textMuted,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            neg.sellerName,
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              const Divider(height: 1),
                              const SizedBox(height: 12),

                              // Price Difference Comparison
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Precio Original',
                                        style: TextStyle(color: colors.textMuted, fontSize: 11),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        currencyFormat.format(neg.originalPrice),
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.lineThrough,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Precio Contraoferta',
                                            style: TextStyle(color: colors.textMuted, fontSize: 11),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            currencyFormat.format(neg.proposedPrice),
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: diffColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          diffString,
                                          style: TextStyle(
                                            color: diffColor,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
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
}

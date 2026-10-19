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

    final filters = ['Todas', 'Pendientes', 'Aceptadas', 'Rechazadas', 'Completadas'];

    final filteredNegotiations = admin.negotiations.where((neg) {
      if (_selectedFilter == 'Todas') return true;
      if (_selectedFilter == 'Pendientes' && neg.status == NegotiationStatus.pendiente) return true;
      if (_selectedFilter == 'Aceptadas' && neg.status == NegotiationStatus.aceptada) return true;
      if (_selectedFilter == 'Rechazadas' && neg.status == NegotiationStatus.rechazada) return true;
      if (_selectedFilter == 'Completadas' && neg.status == NegotiationStatus.completada) return true;
      return false;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;

        if (!isWide) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              children: [
                _buildFilterChips(filters, colors),
                _buildPrivacyNotice(colors),
                const SizedBox(height: 8),
                Expanded(
                  child: filteredNegotiations.isEmpty
                      ? _buildEmptyState(colors)
                      : _buildNegotiationsList(filteredNegotiations, colors),
                ),
              ],
            ),
          );
        }

        // Split-Layout Panorámico de pantalla completa en Desktop
        final pendientesCount = admin.negotiations.where((n) => n.status == NegotiationStatus.pendiente).length;
        final aceptadasCount = admin.negotiations.where((n) => n.status == NegotiationStatus.aceptada).length;
        final completadasCount = admin.negotiations.where((n) => n.status == NegotiationStatus.completada).length;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Panel Lateral Izquierdo (360px): Filtros, Auditoría de Flujos y REQ-47
              SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FILTRAR ESTADO DEL TRATO',
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildVerticalFilterList(filters, colors),
                      const SizedBox(height: 18),
                      _buildPrivacyNotice(colors),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(18),
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
                                Icon(Icons.handshake_rounded, size: 18, color: colors.gold),
                                const SizedBox(width: 8),
                                Text(
                                  'Mesa Comercial Activa',
                                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('En Negociación', style: TextStyle(color: colors.textMuted, fontSize: 11)),
                                      const SizedBox(height: 2),
                                      Text('$pendientesCount tratos', style: TextStyle(color: colors.gold, fontWeight: FontWeight.w800, fontSize: 15)),
                                    ],
                                  ),
                                ),
                                Container(width: 1, height: 30, color: colors.border),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Cerrados / Listos', style: TextStyle(color: colors.textMuted, fontSize: 11)),
                                      const SizedBox(height: 2),
                                      Text('${aceptadasCount + completadasCount}', style: TextStyle(color: colors.statusActive, fontWeight: FontWeight.w800, fontSize: 15)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 26),

              // Panel Principal Derecho: Tratos y Contraofertas en Vivo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.handshake_rounded, size: 20, color: colors.gold),
                              const SizedBox(width: 10),
                              Text(
                                'Auditoría de Acuerdos Comerciales',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors.surfaceAlt,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: colors.border),
                            ),
                            child: Text(
                              '${filteredNegotiations.length} acuerdos registrados',
                              style: TextStyle(
                                color: colors.gold,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: filteredNegotiations.isEmpty
                          ? _buildEmptyState(colors)
                          : _buildNegotiationsList(filteredNegotiations, colors),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChips(List<String> filters, dynamic colors) {
    return SingleChildScrollView(
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
    );
  }

  Widget _buildVerticalFilterList(List<String> filters, dynamic colors) {
    return Column(
      children: filters.map((filter) {
        final isSelected = _selectedFilter == filter;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: InkWell(
            onTap: () => setState(() => _selectedFilter = filter),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? colors.gold.withValues(alpha: 0.15) : colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? colors.gold : colors.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: isSelected ? colors.gold : colors.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    filter,
                    style: TextStyle(
                      color: isSelected ? colors.gold : colors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPrivacyNotice(dynamic colors) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.privacy_tip_outlined, color: Colors.blueAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Privacidad Comercial (REQ-47): Las condiciones económicas individuales (precios acordados y contraofertas) están protegidas y enmascaradas. Solo se auditan estados y flujos agregados.',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(dynamic colors) {
    return Center(
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
    );
  }

  Widget _buildNegotiationsList(List<Negotiation> negotiations, dynamic colors) {
    return ListView.separated(
      itemCount: negotiations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final neg = negotiations[index];

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

                              // Commercial Privacy: Individual terms are masked (REQ-47)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: colors.surfaceAlt,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: colors.border),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.lock_rounded, size: 14, color: colors.textMuted),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Términos Comerciales: ••••••••',
                                              style: TextStyle(
                                                color: colors.textMuted,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      '🔒 Confidencial (REQ-47)',
                                      style: TextStyle(
                                        color: Colors.blueAccent,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
  }
}

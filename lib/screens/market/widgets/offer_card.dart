import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/crop_offer.dart';

final _currencyFmt = NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);

/// Tarjeta de oferta con estética fintech de lujo para "Live Market":
/// variedad + estado, origen, precio/volumen/destino, certificaciones,
/// vendedor con rating, y botón de negociación.
class OfferCard extends StatelessWidget {
  const OfferCard({
    super.key,
    required this.offer,
    required this.onMakeOffer,
  });

  final CropOffer offer;
  final VoidCallback onMakeOffer;

  Color _getStatusColor(AppThemeColors colors) {
    switch (offer.status) {
      case OfferStatus.activa:
        return colors.statusActive;
      case OfferStatus.negociando:
        return colors.statusNegotiating;
      case OfferStatus.confirmada:
        return colors.statusActive;
      case OfferStatus.enTransito:
        return colors.statusTransit;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final statusColor = _getStatusColor(colors);
    final isCoffee = offer.cropType == CropType.cafe;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon + Variety/Origin + Status Chip
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isCoffee
                        ? const Color(0xFF8D6E63).withValues(alpha: 0.15)
                        : const Color(0xFF5D4037).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCoffee
                          ? const Color(0xFF8D6E63).withValues(alpha: 0.4)
                          : const Color(0xFF5D4037).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      isCoffee ? '☕' : '🍫',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.variety,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 13, color: colors.textMuted),
                          const SizedBox(width: 3),
                          Text(
                            '${offer.originRegion} · ${offer.originCountry}',
                            style: TextStyle(color: colors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    offer.status.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Metrics Row (Ask Price, Volume, Destination)
            Row(
              children: [
                _InfoBlock(
                  label: 'ASK PRICE',
                  value: '${_currencyFmt.format(offer.askPricePerMt)}/MT',
                  valueColor: colors.gold,
                ),
                const SizedBox(width: 8),
                _InfoBlock(
                  label: 'VOLUME',
                  value: '${offer.volumeMt.toStringAsFixed(0)} MT',
                  caption: '≈ ${_currencyFmt.format(offer.estimatedTotalUsd)} total',
                ),
                const SizedBox(width: 8),
                _InfoBlock(
                  label: 'DESTINO',
                  value: offer.destinationCountry,
                ),
              ],
            ),

            // Certifications
            if (offer.certifications.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: offer.certifications.map((c) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_outlined, size: 12, color: colors.gold),
                        const SizedBox(width: 4),
                        Text(
                          c,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Seller Row
            Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: colors.gold.withValues(alpha: 0.15),
                  child: Text(
                    offer.sellerName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    offer.sellerName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
                const SizedBox(width: 2),
                Text(
                  '${offer.sellerRating}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${offer.sellerTrades} trades',
                  style: TextStyle(fontSize: 11, color: colors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: onMakeOffer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.gold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 1,
                ),
                icon: Icon(
                  Icons.handshake_rounded,
                  size: 18,
                  color: colors.isDark ? Colors.black : Colors.white,
                ),
                label: Text(
                  'Make an Offer / Counter-Offer',
                  style: TextStyle(
                    color: colors.isDark ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.label,
    required this.value,
    this.caption,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? caption;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: valueColor ?? colors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (caption != null) ...[
              const SizedBox(height: 1),
              Text(
                caption!,
                style: TextStyle(fontSize: 9, color: colors.textMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

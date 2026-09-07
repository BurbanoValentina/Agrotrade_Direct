import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/crop_offer.dart';

final _currencyFmt = NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);

/// Tarjeta de oferta como en el mockup de "Live Market":
/// variedad + estado, origen, precio/volumen/destino, certificaciones,
/// vendedor con rating, y botón de oferta/contraoferta.
class OfferCard extends StatelessWidget {
  const OfferCard({
    super.key,
    required this.offer,
    required this.onMakeOffer,
  });

  final CropOffer offer;
  final VoidCallback onMakeOffer;

  Color get _statusColor {
    switch (offer.status) {
      case OfferStatus.activa:
        return AppColors.statusActive;
      case OfferStatus.negociando:
        return AppColors.statusNegotiating;
      case OfferStatus.confirmada:
        return AppColors.statusActive;
      case OfferStatus.enTransito:
        return AppColors.statusTransit;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.surfaceAlt,
                  child: Icon(
                    offer.cropType == CropType.cafe
                        ? Icons.coffee
                        : Icons.eco,
                    size: 18,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(offer.variety,
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(
                        '${offer.originRegion} · ${offer.originCountry}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusColor),
                  ),
                  child: Text(
                    offer.status.label,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _InfoBlock(
                  label: 'ASK PRICE',
                  value: '${_currencyFmt.format(offer.askPricePerMt)}/MT',
                  valueColor: AppColors.gold,
                ),
                const SizedBox(width: 10),
                _InfoBlock(
                  label: 'VOLUME',
                  value: '${offer.volumeMt.toStringAsFixed(0)} MT',
                  caption: '≈ ${_currencyFmt.format(offer.estimatedTotalUsd)} total',
                ),
                const SizedBox(width: 10),
                _InfoBlock(label: 'DESTINO', value: offer.destinationCountry),
              ],
            ),
            if (offer.certifications.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: offer.certifications
                    .map((c) => Chip(
                          label: Text(c, style: const TextStyle(fontSize: 10)),
                          backgroundColor: AppColors.surfaceAlt,
                          side: const BorderSide(color: AppColors.border),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.gold,
                  child: Text(
                    offer.sellerName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(offer.sellerName,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ),
                Icon(Icons.star, size: 14, color: AppColors.gold),
                const SizedBox(width: 2),
                Text('${offer.sellerRating}',
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                Text('${offer.sellerTrades} trades',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onMakeOffer,
                child: const Text('Make an Offer / Counter-Offer'),
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 9, color: AppColors.textMuted)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: valueColor ?? AppColors.textPrimary)),
            if (caption != null)
              Text(caption!,
                  style: const TextStyle(
                      fontSize: 9, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

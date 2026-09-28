import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/market_provider.dart';

/// REQ-12: Modal interactivo para filtros avanzados (Precio, Volumen y Destino)
Future<MarketFilterOptions?> showFilterSheet(
  BuildContext context, {
  required MarketFilterOptions initialOptions,
}) {
  return showModalBottomSheet<MarketFilterOptions>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _FilterSheetContent(initialOptions: initialOptions),
  );
}

class _FilterSheetContent extends StatefulWidget {
  const _FilterSheetContent({required this.initialOptions});

  final MarketFilterOptions initialOptions;

  @override
  State<_FilterSheetContent> createState() => _FilterSheetContentState();
}

class _FilterSheetContentState extends State<_FilterSheetContent> {
  late MarketFilter _category;
  late RangeValues _priceRange;
  late double _minVolume;
  late TextEditingController _destinationCtrl;

  @override
  void initState() {
    super.initState();
    _category = widget.initialOptions.category;
    _priceRange = RangeValues(
      widget.initialOptions.minPrice ?? 1000,
      widget.initialOptions.maxPrice ?? 10000,
    );
    _minVolume = widget.initialOptions.minVolume ?? 0;
    _destinationCtrl = TextEditingController(
      text: widget.initialOptions.destinationCountry ?? '',
    );
  }

  @override
  void dispose() {
    _destinationCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final updated = MarketFilterOptions(
      category: _category,
      minPrice: _priceRange.start,
      maxPrice: _priceRange.end,
      minVolume: _minVolume > 0 ? _minVolume : null,
      destinationCountry: _destinationCtrl.text.trim().isEmpty
          ? null
          : _destinationCtrl.text.trim(),
    );
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filtros del Mercado',
                    style: Theme.of(context).textTheme.headlineMedium),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _category = MarketFilter.all;
                      _priceRange = const RangeValues(1000, 10000);
                      _minVolume = 0;
                      _destinationCtrl.clear();
                    });
                  },
                  child: const Text('Limpiar',
                      style: TextStyle(color: AppColors.gold)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Producto
            const Text('Producto',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: _category == MarketFilter.all,
                  selectedColor: AppColors.gold,
                  onSelected: (s) =>
                      setState(() => _category = MarketFilter.all),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Café'),
                  selected: _category == MarketFilter.cafe,
                  selectedColor: AppColors.gold,
                  onSelected: (s) =>
                      setState(() => _category = MarketFilter.cafe),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Cacao'),
                  selected: _category == MarketFilter.cacao,
                  selectedColor: AppColors.gold,
                  onSelected: (s) =>
                      setState(() => _category = MarketFilter.cacao),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Rango de Precio (USD / MT)
            Text(
              'Precio por Tonelada: \$${_priceRange.start.round()} - \$${_priceRange.end.round()} USD',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            RangeSlider(
              values: _priceRange,
              min: 500,
              max: 15000,
              divisions: 29,
              activeColor: AppColors.gold,
              labels: RangeLabels(
                '\$${_priceRange.start.round()}',
                '\$${_priceRange.end.round()}',
              ),
              onChanged: (values) => setState(() => _priceRange = values),
            ),
            const SizedBox(height: 16),

            // Volumen Mínimo (MT)
            Text(
              'Volumen Mínimo: ${_minVolume.round()} MT',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Slider(
              value: _minVolume,
              min: 0,
              max: 100,
              divisions: 20,
              activeColor: AppColors.gold,
              label: '${_minVolume.round()} MT',
              onChanged: (val) => setState(() => _minVolume = val),
            ),
            const SizedBox(height: 16),

            // País de Destino UE
            TextFormField(
              controller: _destinationCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Filtrar por País Destino (ej. Alemania, España)',
                prefixIcon: Icon(Icons.flight_land, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _apply,
                child: const Text('Aplicar Filtros'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../models/crop_offer.dart';

/// REQ-06 a REQ-10: Formulario para publicar una nueva oferta de café o cacao.
Future<CropOffer?> showCreateOfferSheet(BuildContext context) {
  return showModalBottomSheet<CropOffer>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _CreateOfferSheetContent(),
  );
}

class _CreateOfferSheetContent extends StatefulWidget {
  const _CreateOfferSheetContent();

  @override
  State<_CreateOfferSheetContent> createState() =>
      __CreateOfferSheetContentState();
}

class __CreateOfferSheetContentState extends State<_CreateOfferSheetContent> {
  final _formKey = GlobalKey<FormState>();

  // REQ-06: Selección del commodity (Café o Cacao)
  CropType _cropType = CropType.cafe;

  // Controladores para los datos de la oferta (REQ-07, REQ-08, REQ-09, REQ-10)
  final _varietyCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _volumeCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController(text: 'Alemania');

  @override
  void dispose() {
    _varietyCtrl.dispose();
    _regionCtrl.dispose();
    _priceCtrl.dispose();
    _volumeCtrl.dispose();
    _destinationCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    // Crea la instancia del modelo de la nueva oferta
    final newOffer = CropOffer(
      id: 'offer_${DateTime.now().millisecondsSinceEpoch}',
      cropType: _cropType,
      variety: _varietyCtrl.text.trim(),
      originRegion: _regionCtrl.text.trim(),
      originCountry: 'Colombia',
      askPricePerMt: double.parse(_priceCtrl.text.trim()),
      volumeMt: double.parse(_volumeCtrl.text.trim()),
      destinationCountry: _destinationCtrl.text.trim(),
      certifications: const ['Organic', 'Fairtrade'],
      sellerName: 'Mi Finca / Empresa',
      sellerRating: 5.0,
      sellerTrades: 1,
      status: OfferStatus.activa,
      postedAt: DateTime.now(),
    );

    Navigator.of(context).pop(newOffer);
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
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: minCrossAxisSize,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Publicar Oferta de Exportación',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),

              // REQ-06: Selector Café / Cacao
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Café')),
                      selected: _cropType == CropType.cafe,
                      selectedColor: AppColors.gold,
                      onSelected: (selected) {
                        if (selected) setState(() => _cropType = CropType.cafe);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Cacao')),
                      selected: _cropType == CropType.cacao,
                      selectedColor: AppColors.gold,
                      onSelected: (selected) {
                        if (selected)
                          setState(() => _cropType = CropType.cacao);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // REQ-07: Variedad y Región
              TextFormField(
                controller: _varietyCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Variedad (ej. Castillo, Geisha, Trinitario)',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _regionCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Región de origen (ej. Huila, Nariño)',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),

              // REQ-08 y REQ-09: Precio y Cantidad
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Precio (USD/MT)',
                      ),
                      validator: (v) =>
                          (v == null || double.tryParse(v) == null)
                              ? 'Inválido'
                              : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _volumeCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Cantidad (MT)',
                      ),
                      validator: (v) =>
                          (v == null || double.tryParse(v) == null)
                              ? 'Inválido'
                              : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // REQ-10: País de destino
              TextFormField(
                controller: _destinationCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'País de destino UE (ej. Alemania, España)',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _submit,
                child: const Text('Publicar Oferta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Extracción rápida para minCrossAxisSize en Column
const MainAxisSize minCrossAxisSize = MainAxisSize.min;

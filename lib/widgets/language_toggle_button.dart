import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/localization/app_localizations.dart';
import '../providers/locale_provider.dart';

/// Reusable language switch. Screens added later can use the same control and
/// read translated strings through `context.l10n`.
class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider?>(context);
    if (localeProvider == null) return const SizedBox.shrink();

    final nextLanguage = localeProvider.isSpanish
        ? context.l10n.translate('language_switch_to_english')
        : context.l10n.translate('language_switch_to_spanish');

    return Tooltip(
      message: nextLanguage,
      child: TextButton.icon(
        onPressed: localeProvider.toggleLanguage,
        icon: const Icon(Icons.language_rounded),
        label: Text(localeProvider.isSpanish ? 'ES' : 'EN'),
        style: TextButton.styleFrom(
          visualDensity:
              compact ? VisualDensity.compact : VisualDensity.standard,
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 8)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }
}

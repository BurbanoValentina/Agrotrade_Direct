import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agrotrade_direct/app.dart';
import 'package:agrotrade_direct/data/repositories/admin_repository.dart';
import 'package:agrotrade_direct/data/repositories/auth_repository.dart';
import 'package:agrotrade_direct/data/repositories/offer_repository.dart';
import 'package:agrotrade_direct/providers/admin_provider.dart';
import 'package:agrotrade_direct/providers/auth_provider.dart';
import 'package:agrotrade_direct/providers/locale_provider.dart';
import 'package:agrotrade_direct/providers/market_provider.dart';
import 'package:agrotrade_direct/providers/theme_provider.dart';
import 'package:agrotrade_direct/widgets/theme_toggle_button.dart';
import 'package:agrotrade_direct/widgets/language_toggle_button.dart';

void main() {
  testWidgets('Theme toggle smoke test', (WidgetTester tester) async {
    final themeProvider = ThemeProvider();
    final localeProvider = LocaleProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthRepository>(create: (_) => MockAuthRepository()),
          Provider<OfferRepository>(create: (_) => MockOfferRepository()),
          Provider<AdminRepository>(create: (_) => MockAdminRepository()),
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
          ChangeNotifierProvider(
            create: (ctx) => AuthProvider(ctx.read<AuthRepository>()),
          ),
          ChangeNotifierProvider(
            create: (ctx) => MarketProvider(ctx.read<OfferRepository>()),
          ),
          ChangeNotifierProvider(
            create: (ctx) => AdminProvider(ctx.read<AdminRepository>()),
          ),
        ],
        child: const AgroTradeApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Initial state is Dark Mode
    expect(themeProvider.isDarkMode, isTrue);
    expect(find.byType(ThemeToggleButton), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);

    await tester.tap(find.byType(LanguageToggleButton).first);
    await tester.pumpAndSettle();
    expect(localeProvider.locale.languageCode, 'en');
    expect(find.text('Sign in'), findsOneWidget);

    await tester.tap(find.byType(LanguageToggleButton).first);
    await tester.pumpAndSettle();
    expect(localeProvider.locale.languageCode, 'es');

    // Tap theme toggle button
    await tester.tap(find.byType(ThemeToggleButton));
    await tester.pumpAndSettle();

    // Theme should now be Light Mode (pastel colors)
    expect(themeProvider.isDarkMode, isFalse);

    // Tap again to switch back to Dark Mode
    await tester.tap(find.byType(ThemeToggleButton));
    await tester.pumpAndSettle();

    expect(themeProvider.isDarkMode, isTrue);
  });
}

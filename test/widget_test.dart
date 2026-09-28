import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agrotrade_direct/app.dart';
import 'package:agrotrade_direct/data/repositories/admin_repository.dart';
import 'package:agrotrade_direct/data/repositories/auth_repository.dart';
import 'package:agrotrade_direct/data/repositories/offer_repository.dart';
import 'package:agrotrade_direct/providers/admin_provider.dart';
import 'package:agrotrade_direct/providers/auth_provider.dart';
import 'package:agrotrade_direct/providers/market_provider.dart';
import 'package:agrotrade_direct/providers/theme_provider.dart';
import 'package:agrotrade_direct/widgets/theme_toggle_button.dart';

void main() {
  testWidgets('Theme toggle smoke test', (WidgetTester tester) async {
    final themeProvider = ThemeProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthRepository>(create: (_) => MockAuthRepository()),
          Provider<OfferRepository>(create: (_) => MockOfferRepository()),
          Provider<AdminRepository>(create: (_) => MockAdminRepository()),
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
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

    // Initial state is Dark Mode
    expect(themeProvider.isDarkMode, isTrue);
    expect(find.byType(ThemeToggleButton), findsOneWidget);

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

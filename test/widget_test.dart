import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agrotrade_direct/app.dart';
import 'package:agrotrade_direct/data/repositories/auth_repository.dart';
import 'package:agrotrade_direct/data/repositories/offer_repository.dart';
import 'package:agrotrade_direct/providers/auth_provider.dart';
import 'package:agrotrade_direct/providers/market_provider.dart';

void main() {
  testWidgets('AgroTradeApp renders LoginScreen when not logged in', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthRepository>(create: (_) => MockAuthRepository()),
          Provider<OfferRepository>(create: (_) => MockOfferRepository()),
          ChangeNotifierProvider(
            create: (ctx) => AuthProvider(ctx.read<AuthRepository>()),
          ),
          ChangeNotifierProvider(
            create: (ctx) => MarketProvider(ctx.read<OfferRepository>()),
          ),
        ],
        child: const AgroTradeApp(),
      ),
    );

    expect(find.text('Café y cacao, directo de Colombia a la UE'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/offer_repository.dart';
import 'providers/auth_provider.dart';
import 'providers/market_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart'; // REQ-31

void main() {
  runApp(
    MultiProvider(
      providers: [
        // Repositorios
        Provider<AuthRepository>(create: (_) => MockAuthRepository()),
        Provider<OfferRepository>(create: (_) => MockOfferRepository()),

        // Providers
        ChangeNotifierProvider(
          create: (ctx) => AuthProvider(ctx.read<AuthRepository>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => MarketProvider(ctx.read<OfferRepository>()),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
        // REQ-31: Proveedor de Idioma
        ChangeNotifierProvider(
          create: (_) => LocaleProvider(),
        ),
      ],
      child: const AgroTradeApp(),
    ),
  );
}

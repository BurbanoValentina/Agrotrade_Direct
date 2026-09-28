import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/offer_repository.dart';
import 'providers/auth_provider.dart';
import 'providers/market_provider.dart';
import 'providers/theme_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        // ── Repositorios ────────────────────────────────────────────────
        Provider<AuthRepository>(create: (_) => MockAuthRepository()),
        Provider<OfferRepository>(create: (_) => MockOfferRepository()),

        // ── Providers de estado (Provider package) ─────────────────────
        ChangeNotifierProvider(
          create: (ctx) => AuthProvider(ctx.read<AuthRepository>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => MarketProvider(ctx.read<OfferRepository>()),
        ),
        // REQ-26: Proveedor de estado para alternar tema claro / oscuro
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
      ],
      child: const AgroTradeApp(),
    ),
  );
}
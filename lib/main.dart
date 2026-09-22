import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/repositories/admin_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/offer_repository.dart';
import 'providers/admin_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/market_provider.dart';
import 'providers/theme_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        // ── Repositorios ────────────────────────────────────────────────
        // Cuando el backend esté listo, reemplaza estas líneas por
        // las implementaciones reales de Supabase (deben implementar
        // las mismas clases abstractas). Ninguna pantalla necesita cambiar.
        Provider<AuthRepository>(create: (_) => MockAuthRepository()),
        Provider<OfferRepository>(create: (_) => MockOfferRepository()),
        Provider<AdminRepository>(create: (_) => MockAdminRepository()),

        // ── Providers de estado (Provider package) ─────────────────────
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
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
}

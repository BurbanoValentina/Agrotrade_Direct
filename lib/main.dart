import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/constants/supabase_constants.dart';
import 'data/repositories/admin_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/offer_repository.dart';
import 'data/repositories/supabase_auth_repository.dart';
import 'data/repositories/supabase_offer_repository.dart';
import 'providers/admin_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/market_provider.dart';
import 'providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar cliente de Supabase
  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    // ignore: deprecated_member_use
    anonKey: SupabaseConstants.supabaseAnonKey,
  );

  runApp(
    MultiProvider(
      providers: [
        // Repositorios reales de Supabase (PostgreSQL, Auth y RLS)
        Provider<AuthRepository>(create: (_) => SupabaseAuthRepository()),
        Provider<OfferRepository>(create: (_) => SupabaseOfferRepository()),
        // Admin aún sin backend: sigue en mock hasta tener tablas en Supabase.
        Provider<AdminRepository>(create: (_) => MockAdminRepository()),

        // Providers de estado
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


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/constants/supabase_constants.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/offer_repository.dart';
import 'data/repositories/supabase_auth_repository.dart';
import 'data/repositories/supabase_offer_repository.dart';
import 'providers/auth_provider.dart';
import 'providers/market_provider.dart';

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

        // Providers de estado
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
}


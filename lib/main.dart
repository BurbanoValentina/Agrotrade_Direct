import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/constants/supabase_constants.dart';
import 'data/repositories/admin_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/certification_repository.dart';
import 'data/repositories/moderation_repository.dart';
import 'data/repositories/offer_repository.dart';
import 'data/repositories/supabase_auth_repository.dart';
import 'data/repositories/supabase_certification_repository.dart';
import 'data/repositories/supabase_moderation_repository.dart';
import 'data/repositories/supabase_offer_repository.dart';
import 'providers/admin_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/market_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart'; // REQ-31

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar cliente de Supabase
  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    // ignore: deprecated_member_use
    anonKey: SupabaseConstants.supabaseAnonKey,
  );

  // Restaurar la sesión guardada antes de mostrar la app: si el usuario ya
  // había iniciado sesión (y no está bloqueado) entra directo al Home.
  final authRepository = SupabaseAuthRepository();
  final initialUser = await authRepository.restoreSession();

  runApp(
    MultiProvider(
      providers: [
        // Repositorios reales de Supabase (PostgreSQL, Auth y RLS)
        Provider<AuthRepository>.value(value: authRepository),
        Provider<OfferRepository>(create: (_) => SupabaseOfferRepository()),
        Provider<CertificationRepository>(create: (_) => SupabaseCertificationRepository()),
        Provider<ModerationRepository>(create: (_) => SupabaseModerationRepository()),
        // Admin aún sin backend: sigue en mock hasta tener tablas en Supabase.
        Provider<AdminRepository>(create: (_) => MockAdminRepository()),

        // Providers
        // Providers de estado
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider(
          create: (ctx) =>
              AuthProvider(ctx.read<AuthRepository>(), initialUser: initialUser),
        ),
        ChangeNotifierProvider(
          create: (ctx) => MarketProvider(ctx.read<OfferRepository>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => AdminProvider(ctx.read<AdminRepository>()),
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
}


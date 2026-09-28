import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agrotrade_direct/data/mock/mock_admin_data.dart';
import 'package:agrotrade_direct/data/repositories/admin_repository.dart';
import 'package:agrotrade_direct/data/repositories/auth_repository.dart';
import 'package:agrotrade_direct/data/repositories/offer_repository.dart';
import 'package:agrotrade_direct/models/admin_permission.dart';
import 'package:agrotrade_direct/models/blocked_user.dart';
import 'package:agrotrade_direct/models/suspicious_activity.dart';
import 'package:agrotrade_direct/providers/admin_provider.dart';
import 'package:agrotrade_direct/providers/auth_provider.dart';
import 'package:agrotrade_direct/providers/market_provider.dart';
import 'package:agrotrade_direct/providers/theme_provider.dart';
import 'package:agrotrade_direct/screens/admin/admin_login_screen.dart';
import 'package:agrotrade_direct/screens/admin/admin_shell.dart';
import 'package:agrotrade_direct/screens/auth/login_screen.dart';

Widget _buildTestApp({
  required AdminRepository adminRepo,
  required AuthRepository authRepo,
  Widget? home,
}) {
  return MultiProvider(
    providers: [
      Provider<AuthRepository>.value(value: authRepo),
      Provider<OfferRepository>(create: (_) => MockOfferRepository()),
      Provider<AdminRepository>.value(value: adminRepo),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => AuthProvider(authRepo)),
      ChangeNotifierProvider(create: (_) => MarketProvider(MockOfferRepository())),
      ChangeNotifierProvider(create: (_) => AdminProvider(adminRepo)),
    ],
    child: MaterialApp(
      home: home ?? const LoginScreen(),
    ),
  );
}

void main() {
  group('Panel Admin - Tests Unitarios y de Repositorio', () {
    late MockAdminRepository repo;
    late AdminProvider provider;

    setUp(() {
      repo = MockAdminRepository();
      provider = AdminProvider(repo);
    });

    test('Credenciales maestras de Valentina como Super Admin', () async {
      final success = await provider.loginEmployee(adminGateEmail, adminGatePassword);
      expect(success, isTrue);
      expect(provider.isLoggedIn, isTrue);
      expect(provider.isSuperAdmin, isTrue);
      expect(provider.currentEmployee?.name, equals('Valentina Burbano'));
      expect(provider.hasPermission(AdminPermission.security), isTrue);
      expect(provider.hasPermission(AdminPermission.employeeManagement), isTrue);
      expect(provider.hasPermission(AdminPermission.settings), isTrue);
    });

    test('Empleado con permisos limitados', () async {
      // Carlos Mendoza tiene: dashboard, userManagement, security
      final success = await provider.loginEmployee('carlos.mendoza@agrotrade.co', 'Agr0#xK9m2');
      expect(success, isTrue);
      expect(provider.isSuperAdmin, isFalse);
      expect(provider.hasPermission(AdminPermission.dashboard), isTrue);
      expect(provider.hasPermission(AdminPermission.userManagement), isTrue);
      expect(provider.hasPermission(AdminPermission.security), isTrue);
      expect(provider.hasPermission(AdminPermission.employeeManagement), isFalse);
      expect(provider.hasPermission(AdminPermission.settings), isFalse);
    });

    test('Creación de empleado con contraseña autogenerada aleatoria', () async {
      await provider.loginEmployee(adminGateEmail, adminGatePassword);

      final newEmp = await provider.createEmployee('Nuevo Socio', 'socio@agrotrade.co');
      expect(newEmp, isNotNull);
      expect(newEmp!.email, equals('socio@agrotrade.co'));
      expect(newEmp.password.length, greaterThanOrEqualTo(10));
      expect(newEmp.createdBy, equals('Valentina Burbano'));

      // Verificar que se puede iniciar sesión con la credencial creada
      final loginNew = await repo.loginEmployee(newEmp.email, newEmp.password);
      expect(loginNew, isNotNull);
      expect(loginNew?.name, equals('Nuevo Socio'));
    });

    test('Otorgar y revocar Super Admin a un socio', () async {
      await provider.loginEmployee(adminGateEmail, adminGatePassword);

      final newEmp = await provider.createEmployee('Socio Fundador', 'fundador@agrotrade.co');
      expect(newEmp!.isSuperAdmin, isFalse);

      // Activar Super Admin para el socio
      await provider.updateEmployeePermissions(newEmp.id, AdminPermission.values.toList(), true);
      final updated = provider.employees.firstWhere((e) => e.id == newEmp.id);
      expect(updated.isSuperAdmin, isTrue);
      expect(updated.hasPermission(AdminPermission.settings), isTrue);
    });

    test('Bloqueo de usuario con razón detallada', () async {
      await provider.loginEmployee(adminGateEmail, adminGatePassword);

      const targetEmail = 'estafador@test.com';
      expect(provider.isUserBlocked(targetEmail), isFalse);

      await provider.blockUser(
        'user-999',
        'Estafador Ficticio',
        targetEmail,
        'Intento de cobrar por fuera de la plataforma con comprobantes falsos.',
      );

      expect(provider.isUserBlocked(targetEmail), isTrue);
      expect(provider.blockedUsers.any((u) => u.userEmail == targetEmail), isTrue);

      final blocked = provider.blockedUsers.firstWhere((u) => u.userEmail == targetEmail);
      expect(blocked.reason, contains('comprobantes falsos'));
      expect(blocked.blockedBy, equals('Valentina Burbano'));

      // Desbloquear usuario
      await provider.unblockUser('user-999');
      expect(provider.isUserBlocked(targetEmail), isFalse);
    });

    test('Gestión de alertas de actividad sospechosa', () async {
      await provider.loginEmployee(adminGateEmail, adminGatePassword);
      expect(provider.alerts.isNotEmpty, isTrue);

      final firstAlert = provider.alerts.first;
      expect(firstAlert.status, equals(AlertStatus.pendiente));

      await provider.updateAlertStatus(firstAlert.id, AlertStatus.revisada);
      final updated = provider.alerts.firstWhere((a) => a.id == firstAlert.id);
      expect(updated.status, equals(AlertStatus.revisada));
    });
  });

  group('Panel Admin - Tests de Interfaz (Widgets)', () {
    testWidgets('Login con credenciales maestras redirige al panel interno', (tester) async {
      final adminRepo = MockAdminRepository();
      final authRepo = MockAuthRepository();

      await tester.pumpWidget(_buildTestApp(adminRepo: adminRepo, authRepo: authRepo));
      await tester.pumpAndSettle();

      // Encontrar campos de email y contraseña
      final emailField = find.widgetWithText(TextFormField, 'Correo electrónico');
      final passwordField = find.widgetWithText(TextFormField, 'Contraseña');
      final submitBtn = find.text('Iniciar sesión');

      // Ingresar credenciales maestras
      await tester.enterText(emailField, adminGateEmail);
      await tester.enterText(passwordField, adminGatePassword);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Debe aparecer la segunda pantalla: AdminLoginScreen
      expect(find.byType(AdminLoginScreen), findsOneWidget);
      expect(find.text('AgroTrade Direct · Panel Interno'), findsOneWidget);
      expect(find.text('Acceso exclusivo para empleados'), findsOneWidget);
      expect(find.text('Acceder al Panel'), findsOneWidget);
    });

    testWidgets('Usuario bloqueado no puede iniciar sesión', (tester) async {
      final adminRepo = MockAdminRepository();
      final authRepo = MockAuthRepository();

      await adminRepo.blockUser(BlockedUser(
        userId: 'usr-bad',
        userName: 'Usuario Malicioso',
        userEmail: 'malicioso@agrotrade.co',
        reason: 'Violación de términos',
        blockedAt: DateTime.now(),
        blockedBy: 'Valentina Burbano',
      ));

      await tester.pumpWidget(_buildTestApp(adminRepo: adminRepo, authRepo: authRepo));
      await tester.pumpAndSettle();

      final emailField = find.widgetWithText(TextFormField, 'Correo electrónico');
      final passwordField = find.widgetWithText(TextFormField, 'Contraseña');
      final submitBtn = find.text('Iniciar sesión');

      await tester.enterText(emailField, 'malicioso@agrotrade.co');
      await tester.enterText(passwordField, '123456');

      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Debe mostrar mensaje de cuenta bloqueada
      expect(find.textContaining('bloqueada permanentemente'), findsOneWidget);

      ScaffoldMessenger.of(tester.element(submitBtn)).clearSnackBars();
      await tester.pump();
    });

    testWidgets('Login directo de empleado desde LoginScreen lleva a AdminShell', (tester) async {
      final adminRepo = MockAdminRepository();
      final authRepo = MockAuthRepository();

      await tester.pumpWidget(_buildTestApp(adminRepo: adminRepo, authRepo: authRepo));
      await tester.pumpAndSettle();

      final emailField = find.widgetWithText(TextFormField, 'Correo electrónico');
      final passwordField = find.widgetWithText(TextFormField, 'Contraseña');
      final submitBtn = find.text('Iniciar sesión');

      // Carlos Mendoza ingresa directo desde la pantalla principal
      await tester.enterText(emailField, 'carlos.mendoza@agrotrade.co');
      await tester.enterText(passwordField, 'Agr0#xK9m2');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Debe estar en AdminShell con su nombre y barra inferior
      expect(find.byType(AdminShell), findsOneWidget);
      expect(find.text('Carlos Mendoza'), findsOneWidget);
      expect(find.text('Empleado'), findsOneWidget);

      // Carlos solo tiene 3 pestañas en la barra inferior (Dashboard, Usuarios, Seguridad)
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Usuarios'), findsOneWidget);
      expect(find.text('Seguridad'), findsOneWidget);
      expect(find.text('Ajustes'), findsNothing);
      expect(find.text('Mercado'), findsNothing);
    });

    testWidgets('Valentina como Super Admin tiene las 5 pestañas abajo en AdminShell', (tester) async {
      final adminRepo = MockAdminRepository();
      final authRepo = MockAuthRepository();

      await tester.pumpWidget(_buildTestApp(adminRepo: adminRepo, authRepo: authRepo));
      await tester.pumpAndSettle();

      final emailField = find.widgetWithText(TextFormField, 'Correo electrónico');
      final passwordField = find.widgetWithText(TextFormField, 'Contraseña');
      final submitBtn = find.text('Iniciar sesión');

      // Ingresar credenciales maestras de Valentina
      await tester.enterText(emailField, 'valentinaburbano1406@gmail.com');
      await tester.enterText(passwordField, 'admin12345');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // En la pantalla de login interno, pulsar el botón de Valentina
      final valentinaQuickBtn = find.text('Valentina Burbano');
      expect(valentinaQuickBtn, findsOneWidget);
      await tester.ensureVisible(valentinaQuickBtn);
      await tester.tap(valentinaQuickBtn);
      await tester.pumpAndSettle();

      // Valentina tiene acceso total: 5 pestañas abajo
      expect(find.byType(AdminShell), findsOneWidget);
      expect(find.text('Super Admin'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Usuarios'), findsOneWidget);
      expect(find.text('Seguridad'), findsOneWidget);
      expect(find.text('Mercado'), findsOneWidget);
      expect(find.text('Ajustes'), findsOneWidget);
    });

    testWidgets('Enlace visible de panel interno en LoginScreen abre AdminLoginScreen', (tester) async {
      final adminRepo = MockAdminRepository();
      final authRepo = MockAuthRepository();

      await tester.pumpWidget(_buildTestApp(adminRepo: adminRepo, authRepo: authRepo));
      await tester.pumpAndSettle();

      final internalLink = find.text('🔒 Acceso Empleados / Panel Interno');
      expect(internalLink, findsOneWidget);
      await tester.ensureVisible(internalLink);
      await tester.tap(internalLink);
      await tester.pumpAndSettle();

      expect(find.byType(AdminLoginScreen), findsOneWidget);
      expect(find.text('ACCESO RÁPIDO DE PRUEBA'), findsOneWidget);
    });
  });
}

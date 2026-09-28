import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:agrotrade_direct/data/repositories/auth_repository.dart';
import 'package:agrotrade_direct/data/repositories/repository_exception.dart';
import 'package:agrotrade_direct/data/repositories/supabase_error_mapper.dart';
import 'package:agrotrade_direct/models/app_user.dart';
import 'package:agrotrade_direct/models/user_role.dart';
import 'package:agrotrade_direct/providers/auth_provider.dart';

/// Repositorio cuyo login siempre falla con el motivo dado.
class _RejectingAuthRepository extends MockAuthRepository {
  _RejectingAuthRepository(this.message);
  final String message;

  @override
  Future<AppUser> login({required String email, required String password}) async {
    throw RepositoryException(message);
  }
}

void main() {
  group('Modelo de usuario', () {
    test('lee rol staff e is_tester desde profiles', () {
      final user = AppUser.fromProfile({
        'id': 'u1',
        'name': 'Soporte',
        'email': 'soporte@agrotrade.com',
        'role': 'staff',
        'is_tester': true,
      });
      expect(user.role, UserRole.staff);
      expect(user.isStaff, isTrue);
      expect(user.isTester, isTrue);
    });

    test('un rol desconocido o vacío se trata como importador', () {
      expect(parseUserRole('admin'), UserRole.importador);
      expect(parseUserRole(null), UserRole.importador);
      expect(parseUserRole('exportador'), UserRole.exportador);
    });

    test('usa el correo de la sesión si el perfil no lo trae', () {
      final user = AppUser.fromProfile(
        {'id': 'u1', 'role': 'exportador'},
        fallbackEmail: 'e@x.com',
      );
      expect(user.email, 'e@x.com');
      expect(user.isTester, isFalse);
    });
  });

  group('Errores de Supabase Auth en español', () {
    String message(AuthException e) => mapSupabaseError(e).message;

    test('credenciales inválidas', () {
      expect(message(const AuthException('Invalid login credentials',
              statusCode: '400', code: 'invalid_credentials')),
          'Correo o contraseña incorrectos.');
    });

    test('correo sin confirmar', () {
      expect(message(const AuthException('Email not confirmed',
              statusCode: '400', code: 'email_not_confirmed')),
          contains('confirmar tu correo'));
    });

    test('contraseña débil y correo repetido', () {
      expect(message(const AuthException('weak', statusCode: '422', code: 'weak_password')),
          contains('muy débil'));
      expect(message(const AuthException('exists', statusCode: '422', code: 'user_already_exists')),
          'Ya existe una cuenta con ese correo.');
    });

    test('sin respuesta del servidor se reporta como problema de conexión', () {
      expect(message(const AuthException('ClientException: Failed host lookup')),
          contains('conexión'));
    });

    test('un código desconocido no expone el mensaje técnico', () {
      expect(message(const AuthException('Internal server error',
              statusCode: '500', code: 'unexpected_failure')),
          isNot(contains('Internal')));
    });
  });

  group('AuthProvider', () {
    test('arranca con la sesión restaurada', () {
      const user = AppUser(id: 'u1', name: 'Ana', email: 'a@x.com', role: UserRole.importador);
      final auth = AuthProvider(MockAuthRepository(), initialUser: user);
      expect(auth.isLoggedIn, isTrue);
      expect(auth.currentUser, same(user));
    });

    test('muestra el motivo real cuando falla el login', () async {
      final auth = AuthProvider(_RejectingAuthRepository('Correo o contraseña incorrectos.'));

      final ok = await auth.login('a@x.com', 'mala');

      expect(ok, isFalse);
      expect(auth.isLoggedIn, isFalse);
      expect(auth.errorMessage, 'Correo o contraseña incorrectos.');
      expect(auth.isLoading, isFalse);
    });

    test('no permite registrarse como staff ni repetir correo', () async {
      final auth = AuthProvider(MockAuthRepository());

      expect(await auth.register(
          name: 'X', email: 'x@x.com', password: '123456', role: UserRole.staff), isFalse);
      expect(auth.errorMessage, contains('exportador o importador'));

      expect(await auth.register(
          name: 'X', email: 'x@x.com', password: '123456', role: UserRole.importador), isTrue);
      await auth.logout();
      expect(await auth.register(
          name: 'X', email: 'X@x.com', password: '123456', role: UserRole.importador), isFalse);
      expect(auth.errorMessage, 'Ya existe una cuenta con ese correo.');
    });

    test('changePassword exige 6 caracteres y quita mustSetPassword', () async {
      final repo = MockAuthRepository();
      const invited = AppUser(
          id: 's1', name: 'Soporte', email: 's@x.com', role: UserRole.staff, mustSetPassword: true);
      final auth = AuthProvider(repo, initialUser: invited);
      await repo.login(email: 's@x.com', password: 'temporal'); // sesión en el mock

      expect(await auth.changePassword('123'), isFalse);
      expect(auth.errorMessage, contains('al menos 6'));
      expect(auth.currentUser!.mustSetPassword, isTrue);

      expect(await auth.changePassword('NuevaClave2026'), isTrue);
      expect(auth.currentUser!.mustSetPassword, isFalse);
    });

    test('restoreSession recupera la sesión y logout la cierra', () async {
      final repo = MockAuthRepository();
      await AuthProvider(repo).login('a@x.com', '123456');

      final reopened = AuthProvider(repo);
      await reopened.restoreSession();
      expect(reopened.currentUser?.email, 'a@x.com');

      await reopened.logout();
      expect(reopened.isLoggedIn, isFalse);
      expect(await repo.restoreSession(), isNull);
    });
  });
}

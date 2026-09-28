import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:agrotrade_direct/data/repositories/moderation_repository.dart';
import 'package:agrotrade_direct/data/repositories/repository_exception.dart';
import 'package:agrotrade_direct/data/repositories/supabase_error_mapper.dart';
import 'package:agrotrade_direct/models/admin_permission.dart';
import 'package:agrotrade_direct/models/user_warning.dart';

Matcher _rejectedWith(String part) => throwsA(
    isA<RepositoryException>().having((e) => e.message, 'message', contains(part)));

void main() {
  group('Advertencias (REQ-33)', () {
    late MockModerationRepository repo;

    setUp(() => repo = MockModerationRepository(permissions: {AdminPermission.userManagement}));

    test('a la tercera advertencia la cuenta se suspende sola', () async {
      final first = await repo.warnUser('u1', 'Incumplimiento de entrega', reportId: 'r1');
      final second = await repo.warnUser('u1', 'Lenguaje ofensivo en el chat');
      final third = await repo.warnUser('u1', 'Precios falsos en ofertas');

      expect([first.warningsCount, second.warningsCount, third.warningsCount], [1, 2, 3]);
      expect([first.autoBlocked, second.autoBlocked, third.autoBlocked], [false, false, true]);
      expect(repo.blockedUsers, contains('u1'));
      expect(third.warningsCount, maxWarningsBeforeSuspension);

      final fourth = await repo.warnUser('u1', 'Otra falta después del bloqueo');
      expect(fourth.autoBlocked, isFalse, reason: 'ya estaba suspendido');
    });

    test('solo admins con userManagement advierten, con motivo válido', () async {
      repo.permissions = {AdminPermission.offerManagement};
      expect(repo.warnUser('u1', 'Motivo suficiente'), _rejectedWith('userManagement'));

      repo.permissions = {AdminPermission.userManagement};
      expect(repo.warnUser('u1', 'x'), _rejectedWith('mínimo 5'));
      expect(repo.warnUser(repo.currentUserId, 'Motivo suficiente'), _rejectedWith('ti mismo'));
    });

    test('el usuario ve y marca como leídas solo sus advertencias', () async {
      final result = await repo.warnUser('u1', 'Incumplimiento de entrega');

      repo.currentUserId = 'u1';
      final mine = await repo.fetchMyWarnings();
      expect(mine.single.isAcknowledged, isFalse);
      final read = await repo.acknowledgeWarning(result.warningId);
      expect(read.isAcknowledged, isTrue);

      repo.currentUserId = 'u2';
      expect(repo.acknowledgeWarning(result.warningId), _rejectedWith('no existe'));
    });
  });

  group('Empleados y borrado de cuentas (Edge Function)', () {
    test('invitar requiere employeeManagement y respeta los permisos propios', () async {
      final hr = MockModerationRepository(
          permissions: {AdminPermission.employeeManagement, AdminPermission.dashboard});

      final invitation = await hr.inviteStaff(
          email: ' Soporte@AgroTrade.com ', permissions: [AdminPermission.dashboard]);
      expect(invitation.email, 'soporte@agrotrade.com');
      expect(invitation.permissions, ['dashboard']);

      expect(hr.inviteStaff(email: 'a@b.com', permissions: [AdminPermission.security]),
          _rejectedWith('security'));
      expect(hr.inviteStaff(email: 'jefe@b.com', isSuperAdmin: true), _rejectedWith('super admin'));
      expect(hr.inviteStaff(email: 'a@b.com'), _rejectedWith('al menos un permiso'));
      expect(hr.inviteStaff(email: 'soporte@agrotrade.com', permissions: [AdminPermission.dashboard]),
          _rejectedWith('ya tiene una cuenta'));

      final noPermission = MockModerationRepository(permissions: {AdminPermission.userManagement});
      expect(noPermission.inviteStaff(email: 'a@b.com', permissions: [AdminPermission.dashboard]),
          _rejectedWith('employeeManagement'));
    });

    test('no se borran cuentas con tratos confirmados ni la propia', () async {
      final repo = MockModerationRepository(permissions: {AdminPermission.userManagement})
        ..usersWithConfirmedDeals.add('u-con-tratos');

      expect(repo.deleteUser('u-con-tratos'), _rejectedWith('Bloquéalo'));
      expect(repo.deleteUser(repo.currentUserId), _rejectedWith('propia cuenta'));
      await repo.deleteUser('u-sin-tratos');
      expect(repo.warnUser('u-sin-tratos', 'Motivo suficiente'), _rejectedWith('no existe'));
    });
  });

  group('Errores de la Edge Function en español', () {
    test('muestra el mensaje que devuelve la función', () {
      final e = mapSupabaseError(const FunctionException(
        status: 409,
        details: {'error': 'Ese correo ya tiene una cuenta en AgroTrade.'},
      ));
      expect(e.message, 'Ese correo ya tiene una cuenta en AgroTrade.');
    });

    test('avisa si la función no está publicada', () {
      final e = mapSupabaseError(const FunctionException(status: 404, details: 'Not found'));
      expect(e.message, contains('no está publicada'));
    });
  });
}

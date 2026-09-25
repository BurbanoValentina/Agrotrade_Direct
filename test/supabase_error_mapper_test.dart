import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:agrotrade_direct/data/repositories/repository_exception.dart';
import 'package:agrotrade_direct/data/repositories/supabase_error_mapper.dart';

void main() {
  group('mapSupabaseError', () {
    test('muestra tal cual los mensajes de las reglas de negocio (P0001)', () {
      final e = mapSupabaseError(const PostgrestException(
        message: 'Ya tienes una solicitud activa para esta oferta.',
        code: 'P0001',
      ));
      expect(e.message, 'Ya tienes una solicitud activa para esta oferta.');
    });

    test('traduce una violación de RLS a un mensaje de permisos', () {
      final e = mapSupabaseError(const PostgrestException(
        message: 'new row violates row-level security policy for table "negotiations"',
        code: '42501',
      ));
      expect(e.message, contains('No tienes permiso'));
    });

    test('no expone mensajes técnicos de códigos desconocidos', () {
      final e = mapSupabaseError(const PostgrestException(
        message: 'relation "foo" does not exist',
        code: '42P01',
      ));
      expect(e.message, isNot(contains('relation')));
    });

    test('un error de red se reporta como problema de conexión', () {
      final e = mapSupabaseError(Exception('SocketException: Failed host lookup'));
      expect(e.message, contains('conexión'));
    });

    test('un RepositoryException pasa sin cambios', () {
      const original = RepositoryException('Mensaje propio');
      expect(identical(mapSupabaseError(original), original), isTrue);
    });
  });
}

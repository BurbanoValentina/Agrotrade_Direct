import 'package:flutter_test/flutter_test.dart';

import 'package:agrotrade_direct/data/repositories/repository_exception.dart';
import 'package:agrotrade_direct/data/repositories/stats_repository.dart';
import 'package:agrotrade_direct/models/platform_stats.dart';

void main() {
  group('PlatformStats (REQ-47 / REQ-37)', () {
    test('lee conteos, montos por producto y la serie mensual', () async {
      final stats = await MockStatsRepository().fetchDashboardStats();

      expect(stats.minGroupSize, 3);
      expect(stats.usersByRole, {'exportador': 5, 'importador': 7});
      expect(stats.negotiationsByStatus['confirmed'], 5);
      expect(stats.confirmedByMonth, hasLength(6));
      expect(stats.confirmedByMonth.last.month, '2026-10');

      final cafe = stats.confirmedByCrop.firstWhere((c) => c.cropType == 'cafe');
      expect(cafe.hasAmounts, isTrue);
      expect(cafe.avgPricePerMt, 7715.38);
    });

    test('montos ocultos llegan como null (menos de 3 tratos)', () async {
      final stats = await MockStatsRepository().fetchDashboardStats();

      final cacao = stats.confirmedByCrop.firstWhere((c) => c.cropType == 'cacao');
      expect(cacao.deals, 1);
      expect(cacao.hasAmounts, isFalse);
      expect(cacao.valueUsd, isNull);
      // Supresión complementaria: con el cacao oculto, el total general también.
      expect(stats.totalValueUsd, isNull);
      expect(stats.totalVolumeMt, isNull);
    });

    test('sin permiso dashboard lanza RepositoryException', () {
      expect(MockStatsRepository(canViewDashboard: false).fetchDashboardStats(),
          throwsA(isA<RepositoryException>()));
    });

    test('tolera la respuesta antigua sin las claves nuevas', () {
      final stats = PlatformStats.fromJson(const {
        'totalUsers': 3,
        'activeOffers': 2,
        'activeNegotiations': 1,
        'blockedUsers': 0,
        'pendingAlerts': 0,
        'totalVolumeMt': 10,
        'totalValueUsd': 80000,
      });
      expect(stats.minGroupSize, 3);
      expect(stats.confirmedByCrop, isEmpty);
      expect(stats.totalValueUsd, 80000);
    });
  });
}

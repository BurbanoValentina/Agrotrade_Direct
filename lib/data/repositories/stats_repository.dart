import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/platform_stats.dart';
import 'repository_exception.dart';
import 'supabase_error_mapper.dart';

/// REQ-47 / REQ-37: métricas agregadas para el dashboard del panel admin.
/// Requiere el permiso `dashboard`; lanza [RepositoryException] si no.
abstract class StatsRepository {
  Future<PlatformStats> fetchDashboardStats();
}

/// `rpc('admin_dashboard_stats')` (migración 20261019010000_dashboard_stats_v2).
class SupabaseStatsRepository implements StatsRepository {
  SupabaseStatsRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  @override
  Future<PlatformStats> fetchDashboardStats() async {
    try {
      final data = await _supabase.rpc('admin_dashboard_stats');
      return PlatformStats.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      throw mapSupabaseError(e);
    }
  }
}

/// Datos de ejemplo para la UI: café con montos y cacao con pocos tratos
/// (montos ocultos), para ver ambos casos en pantalla.
class MockStatsRepository implements StatsRepository {
  MockStatsRepository({this.canViewDashboard = true});

  bool canViewDashboard;

  @override
  Future<PlatformStats> fetchDashboardStats() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!canViewDashboard) {
      throw const RepositoryException('Requiere el permiso dashboard');
    }
    return PlatformStats.fromJson(const {
      'minGroupSize': 3,
      'totalUsers': 12,
      'activeOffers': 7,
      'activeNegotiations': 4,
      'blockedUsers': 1,
      'pendingAlerts': 2,
      'pendingReports': 1,
      'pendingCertifications': 3,
      'totalVolumeMt': null,
      'totalValueUsd': null,
      'usersByRole': {'exportador': 5, 'importador': 7},
      'offersByStatus': {'activa': 5, 'negociando': 2, 'confirmada': 1, 'enTransito': 0, 'cerrada': 0},
      'negotiationsByStatus': {
        'pending': 2, 'countered': 1, 'accepted': 1, 'confirmed': 5, 'rejected': 2, 'cancelled': 1,
      },
      'confirmedByCrop': [
        {'cropType': 'cafe', 'deals': 4, 'volumeMt': 52, 'valueUsd': 401200, 'avgPricePerMt': 7715.38},
        {'cropType': 'cacao', 'deals': 1, 'volumeMt': null, 'valueUsd': null, 'avgPricePerMt': null},
      ],
      'closeRate': 0.625,
      'avgRoundsToClose': 2.4,
      'avgHoursToConfirm': 31.5,
      'confirmedByMonth': [
        {'month': '2026-05', 'deals': 0},
        {'month': '2026-06', 'deals': 0},
        {'month': '2026-07', 'deals': 0},
        {'month': '2026-08', 'deals': 0},
        {'month': '2026-09', 'deals': 2},
        {'month': '2026-10', 'deals': 3},
      ],
    });
  }
}

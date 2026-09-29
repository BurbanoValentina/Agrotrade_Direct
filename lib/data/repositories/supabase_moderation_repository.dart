import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/admin_permission.dart';
import '../../models/user_warning.dart';
import 'moderation_repository.dart';
import 'repository_exception.dart';
import 'supabase_error_mapper.dart';

/// REQ-33 con Supabase: Edge Function `admin-users` (supabase/functions/) y
/// RPC de advertencias (migración 20260927010000_user_warnings).
class SupabaseModerationRepository implements ModerationRepository {
  SupabaseModerationRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<Map<String, dynamic>> _invokeAdminUsers(Map<String, dynamic> body) async {
    try {
      final response = await _supabase.functions.invoke('admin-users', body: body);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw mapSupabaseError(e);
    }
  }

  @override
  Future<StaffInvitation> inviteStaff({
    required String email,
    String? name,
    List<AdminPermission> permissions = const [],
    bool isSuperAdmin = false,
  }) async {
    final data = await _invokeAdminUsers({
      'action': 'create_staff',
      'email': email.trim(),
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      'permissions': permissions.map((p) => p.name).toList(),
      'is_super_admin': isSuperAdmin,
    });
    return StaffInvitation.fromJson(data);
  }

  @override
  Future<void> deleteUser(String userId) async {
    await _invokeAdminUsers({'action': 'delete_user', 'user_id': userId});
  }

  @override
  Future<WarningResult> warnUser(String userId, String reason, {String? reportId}) async {
    try {
      final data = await _supabase.rpc('warn_user', params: {
        'p_user_id': userId,
        'p_reason': reason.trim(),
        'p_report_id': reportId,
      });
      return WarningResult.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      throw mapSupabaseError(e);
    }
  }

  @override
  Future<List<UserWarning>> fetchUserWarnings(String userId) => _fetchWarnings(userId);

  @override
  Future<List<UserWarning>> fetchMyWarnings() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const RepositoryException('Debes iniciar sesión.');
    }
    return _fetchWarnings(user.id);
  }

  Future<List<UserWarning>> _fetchWarnings(String userId) async {
    try {
      final rows = await _supabase
          .from('user_warnings')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (rows as List<dynamic>)
          .map((r) => UserWarning.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapSupabaseError(e);
    }
  }

  @override
  Future<UserWarning> acknowledgeWarning(String warningId) async {
    try {
      final row = await _supabase.rpc('acknowledge_warning', params: {'p_warning_id': warningId});
      return UserWarning.fromJson(row as Map<String, dynamic>);
    } catch (e) {
      throw mapSupabaseError(e);
    }
  }
}

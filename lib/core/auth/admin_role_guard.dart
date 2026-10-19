import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/admin_permission.dart';
import '../../providers/admin_provider.dart';
import '../utils/admin_role_extension.dart';

enum AdminRole { superAdmin, manager, employee }

class AdminRoleGuard extends StatelessWidget {
  const AdminRoleGuard({
    required this.allowedRoles,
    required this.child,
    this.requiredPermissions = const [],
    super.key,
  });

  final List<AdminRole> allowedRoles;
  final List<AdminPermission> requiredPermissions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final employee = admin.currentEmployee;

    final isAllowed = employee != null &&
        (context.isSuperAdmin
            ? allowedRoles.contains(AdminRole.superAdmin)
            : context.isManager
                ? allowedRoles.contains(AdminRole.manager) &&
                    (requiredPermissions.isEmpty ||
                        requiredPermissions.every(
                          (permission) =>
                              permission == AdminPermission.dashboard ||
                              permission == AdminPermission.reports,
                        ))
                : allowedRoles.contains(AdminRole.employee) &&
                    (requiredPermissions.isEmpty ||
                        requiredPermissions
                            .any(admin.hasPermission)));

    if (isAllowed) return child;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Acceso restringido'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 16),
              Text(
                'No tienes permisos para acceder a esta sección.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tu acceso se limita a las funciones habilitadas para tu rol.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

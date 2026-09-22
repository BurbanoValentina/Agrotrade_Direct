import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/suspicious_activity.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/responsive_layout.dart';

class AdminSecurityScreen extends StatelessWidget {
  const AdminSecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final admin = context.watch<AdminProvider>();
    final pendingAlerts = admin.alerts.where((a) => a.status == AlertStatus.pendiente).length;
    final blockedCount = admin.blockedUsers.length;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(bottom: BorderSide(color: colors.border)),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.gold.withValues(alpha: 0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: colors.isDark ? 0.2 : 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: colors.gold,
                    unselectedLabelColor: colors.textSecondary,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shield_outlined, size: 16),
                            const SizedBox(width: 8),
                            const Text('Alertas'),
                            if (pendingAlerts > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$pendingAlerts',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.block_rounded, size: 16),
                            const SizedBox(width: 8),
                            const Text('Bloqueados'),
                            if (blockedCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colors.border,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$blockedCount',
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _AlertsTab(),
                _BlockedUsersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertsTab extends StatelessWidget {
  const _AlertsTab();

  void _showBlockDialog(BuildContext context, AdminProvider admin, SuspiciousActivity alert) {
    final colors = context.colors;
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.border),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.gavel_rounded, color: Colors.redAccent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bloquear Perfil',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    alert.relatedUserName,
                    style: TextStyle(
                      color: colors.gold,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Esta acción restringirá el acceso inmediato a la plataforma y cancelará todas sus operaciones en curso.',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Motivo del bloqueo (obligatorio)',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: reasonController,
                maxLines: 3,
                style: TextStyle(color: colors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Ej. Intento reiterado de fraude en precios de café...',
                  hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Por favor especifique la razón';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Cancelar',
              style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.block_rounded, size: 18),
            label: const Text(
              'Confirmar Bloqueo',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final matches = admin.users.where((u) => u.id == alert.relatedUserId);
                final userEmail = matches.isNotEmpty ? matches.first.email : 'desconocido@email.com';

                await admin.blockUser(
                  alert.relatedUserId,
                  alert.relatedUserName,
                  userEmail,
                  reasonController.text.trim(),
                );
                await admin.updateAlertStatus(alert.id, AlertStatus.accionTomada);

                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final admin = context.watch<AdminProvider>();
    final dateFormat = DateFormat('dd/MM/yyyy · HH:mm');

    final List<SuspiciousActivity> alerts = List<SuspiciousActivity>.from(admin.alerts)
      ..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));

    if (alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.verified_user_rounded, size: 48, color: colors.gold),
            ),
            const SizedBox(height: 16),
            Text(
              'Sistema Seguro',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No hay alertas pendientes ni sospechas registradas.',
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ResponsiveContainer(
      maxWidth: 900,
      padding: const EdgeInsets.all(16),
      child: ListView.separated(
        itemCount: alerts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final alert = alerts[index];
          final isPending = alert.status == AlertStatus.pendiente;

          final (severityColor, severityBg) = switch (alert.severity) {
            AlertSeverity.baja => (const Color(0xFF3B82F6), const Color(0xFF3B82F6).withValues(alpha: 0.1)),
            AlertSeverity.media => (colors.gold, colors.gold.withValues(alpha: 0.1)),
            AlertSeverity.alta => (const Color(0xFFF97316), const Color(0xFFF97316).withValues(alpha: 0.1)),
            AlertSeverity.critica => (const Color(0xFFEF4444), const Color(0xFFEF4444).withValues(alpha: 0.12)),
          };

          final typeIcon = switch (alert.type) {
            SuspiciousType.precioAnomalo => Icons.trending_down_rounded,
            SuspiciousType.multiplesCuentas => Icons.people_alt_outlined,
            SuspiciousType.patronInusual => Icons.psychology_alt_outlined,
            SuspiciousType.intentoFraude => Icons.gavel_rounded,
          };

          return Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isPending ? severityColor.withValues(alpha: 0.4) : colors.border,
                width: isPending ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isPending
                      ? severityColor.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: colors.isDark ? 0.2 : 0.02),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Banner with Severity & Date
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: severityBg,
                      border: Border(bottom: BorderSide(color: severityColor.withValues(alpha: 0.2))),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: severityColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                alert.severity.label.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(typeIcon, size: 16, color: severityColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            alert.type.label,
                            style: TextStyle(
                              color: severityColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          dateFormat.format(alert.detectedAt),
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content Body
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.description,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // User badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: colors.surfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: colors.gold.withValues(alpha: 0.15),
                                child: Text(
                                  alert.relatedUserName.isNotEmpty ? alert.relatedUserName[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    color: colors.gold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Usuario implicado: ',
                                style: TextStyle(color: colors.textSecondary, fontSize: 12),
                              ),
                              Text(
                                alert.relatedUserName,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 12),

                        // Action buttons or Status indicator
                        if (isPending)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colors.textSecondary,
                                  side: BorderSide(color: colors.border),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.close_rounded, size: 16),
                                label: const Text('Descartar', style: TextStyle(fontSize: 12)),
                                onPressed: () {
                                  admin.updateAlertStatus(alert.id, AlertStatus.descartada);
                                },
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colors.gold,
                                  side: BorderSide(color: colors.gold.withValues(alpha: 0.6)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                                label: const Text('Revisar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                onPressed: () {
                                  admin.updateAlertStatus(alert.id, AlertStatus.revisada);
                                },
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.block_rounded, size: 16),
                                label: const Text('Bloquear Perfil', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                onPressed: () => _showBlockDialog(context, admin, alert),
                              ),
                            ],
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: colors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: colors.border),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      alert.status == AlertStatus.accionTomada
                                          ? Icons.gavel_rounded
                                          : Icons.check_circle_rounded,
                                      size: 14,
                                      color: alert.status == AlertStatus.accionTomada ? Colors.redAccent : colors.gold,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Estado: ${alert.status.label}',
                                      style: TextStyle(
                                        color: alert.status == AlertStatus.accionTomada ? Colors.redAccent : colors.textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BlockedUsersTab extends StatelessWidget {
  const _BlockedUsersTab();

  void _confirmUnblock(BuildContext context, AdminProvider admin, dynamic user) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.border),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.lock_open_rounded, color: colors.gold, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Desbloquear Usuario',
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          '¿Está seguro que desea levantar el bloqueo a ${user.userName}? Podrá volver a acceder al mercado y negociar.',
          style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancelar', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.gold,
              foregroundColor: colors.isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.check_rounded, size: 16),
            onPressed: () {
              admin.unblockUser(user.userId);
              Navigator.pop(dialogCtx);
            },
            label: const Text('Desbloquear', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final admin = context.watch<AdminProvider>();
    final dateFormat = DateFormat('dd/MM/yyyy');

    final blocked = admin.blockedUsers;

    if (blocked.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shield_rounded, size: 48, color: colors.statusActive),
            ),
            const SizedBox(height: 16),
            Text(
              'Sin usuarios bloqueados',
              style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Todos los usuarios activos cumplen las normas de la plataforma.',
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ResponsiveContainer(
      maxWidth: 900,
      padding: const EdgeInsets.all(16),
      child: ListView.separated(
        itemCount: blocked.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final user = blocked[index];
          return Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: ExpansionTile(
              shape: const Border(),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                child: const Icon(Icons.lock_person_rounded, color: Colors.redAccent, size: 20),
              ),
              title: Text(
                user.userName,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                user.userEmail,
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
              iconColor: colors.gold,
              collapsedIconColor: colors.textMuted,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 1),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.report_problem_outlined, color: Colors.redAccent, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Motivo del bloqueo:',
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              user.reason,
                              style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 14, color: colors.textMuted),
                              const SizedBox(width: 6),
                              Text(
                                'Fecha: ${dateFormat.format(user.blockedAt)}',
                                style: TextStyle(color: colors.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(Icons.admin_panel_settings_outlined, size: 14, color: colors.textMuted),
                              const SizedBox(width: 6),
                              Text(
                                'Por: ${user.blockedBy}',
                                style: TextStyle(color: colors.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.gold,
                            side: BorderSide(color: colors.gold),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.lock_open_rounded, size: 16),
                          onPressed: () => _confirmUnblock(context, admin, user),
                          label: const Text('Desbloquear Usuario', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

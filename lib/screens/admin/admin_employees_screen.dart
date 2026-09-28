import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/admin_employee.dart';
import '../../models/admin_permission.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/responsive_layout.dart';

class AdminEmployeesScreen extends StatefulWidget {
  const AdminEmployeesScreen({super.key});

  @override
  State<AdminEmployeesScreen> createState() => _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState extends State<AdminEmployeesScreen> {
  void _showCreateEmployeeDialog(BuildContext context) {
    final colors = context.colors;
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final provider = context.read<AdminProvider>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
                color: colors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.person_add_rounded, color: colors.gold, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Crear Nuevo Empleado',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    'Acceso al panel operativo interno',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
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
                  color: colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: colors.gold, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'El sistema generará una contraseña aleatoria de alta seguridad.',
                        style: TextStyle(color: colors.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: nameController,
                style: TextStyle(color: colors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.badge_outlined, color: colors.textMuted, size: 20),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese el nombre' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: emailController,
                style: TextStyle(color: colors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Correo electrónico corporativo',
                  prefixIcon: Icon(Icons.mail_outline_rounded, color: colors.textMuted, size: 20),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@')) ? 'Ingrese un correo válido' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.gold,
              foregroundColor: colors.isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Crear', style: TextStyle(fontWeight: FontWeight.w800)),
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final newEmp = await provider.createEmployee(
                  nameController.text.trim(),
                  emailController.text.trim(),
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  if (newEmp != null) {
                    _showPasswordDialog(context, newEmp.name, newEmp.email, newEmp.password);
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showPasswordDialog(BuildContext context, String name, String email, String password) {
    final colors = context.colors;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
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
                color: colors.statusActive.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.key_rounded, color: colors.statusActive, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Empleado Creado',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    name,
                    style: TextStyle(color: colors.gold, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Guarda esta contraseña, se genera automáticamente y no se mostrará de nuevo.',
              style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.gold.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      password,
                      style: TextStyle(
                        color: colors.gold,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy_rounded, color: colors.gold, size: 20),
                    tooltip: 'Copiar contraseña',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: password));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Contraseña copiada al portapapeles')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.gold,
              foregroundColor: colors.isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _showPermissionsDialog(BuildContext context, AdminEmployee employee) {
    final colors = context.colors;
    final provider = context.read<AdminProvider>();
    bool isSuperAdmin = employee.isSuperAdmin;
    List<AdminPermission> selectedPerms = List.from(employee.permissions);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
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
                CircleAvatar(
                  radius: 18,
                  backgroundColor: employee.isSuperAdmin
                      ? colors.gold.withValues(alpha: 0.2)
                      : colors.surfaceAlt,
                  child: Text(
                    employee.name.isNotEmpty ? employee.name[0].toUpperCase() : 'E',
                    style: TextStyle(
                      color: employee.isSuperAdmin ? colors.gold : colors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Permisos: ${employee.name}',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        employee.email,
                        style: TextStyle(color: colors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSuperAdmin
                            ? colors.gold.withValues(alpha: 0.12)
                            : colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSuperAdmin ? colors.gold : colors.border,
                        ),
                      ),
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Row(
                          children: [
                            Text(
                              '👑 Super Admin',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          'Control total del sistema sin restricciones de módulos.',
                          style: TextStyle(color: colors.textSecondary, fontSize: 12),
                        ),
                        value: isSuperAdmin,
                        activeTrackColor: colors.gold.withValues(alpha: 0.5),
                        activeThumbColor: colors.gold,
                        onChanged: (val) => setDialogState(() => isSuperAdmin = val),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Módulos y Acciones Específicas',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...AdminPermission.values.map((p) {
                      final isChecked = selectedPerms.contains(p) || isSuperAdmin;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: colors.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isChecked ? colors.gold.withValues(alpha: 0.4) : colors.border,
                          ),
                        ),
                        child: CheckboxListTile(
                          dense: true,
                          title: Text(
                            p.label,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            p.description,
                            style: TextStyle(color: colors.textSecondary, fontSize: 11),
                          ),
                          value: isChecked,
                          activeColor: colors.gold,
                          checkColor: colors.isDark ? Colors.black : Colors.white,
                          onChanged: isSuperAdmin
                              ? null
                              : (val) {
                                  setDialogState(() {
                                    if (val == true) {
                                      selectedPerms.add(p);
                                    } else {
                                      selectedPerms.remove(p);
                                    }
                                  });
                                },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.gold,
                  foregroundColor: colors.isDark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w800)),
                onPressed: () async {
                  await provider.updateEmployeePermissions(employee.id, selectedPerms, isSuperAdmin);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final provider = context.watch<AdminProvider>();
    final currentUserId = provider.currentEmployee?.id;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateEmployeeDialog(context),
        backgroundColor: colors.gold,
        icon: Icon(Icons.person_add_rounded, color: colors.isDark ? Colors.black : Colors.white),
        label: Text(
          'Crear Empleado',
          style: TextStyle(
            color: colors.isDark ? Colors.black : Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ResponsiveContainer(
        maxWidth: 1000,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gestión de Empleados',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${provider.employees.length} colaboradores registrados en AgroTrade',
                      style: TextStyle(color: colors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Employee List
            Expanded(
              child: ListView.separated(
                itemCount: provider.employees.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final emp = provider.employees[index];
                  final isMe = emp.id == currentUserId;

                  return Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isMe ? colors.gold.withValues(alpha: 0.5) : colors.border,
                        width: isMe ? 1.5 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: colors.isDark ? 0.2 : 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      onTap: () => _showPermissionsDialog(context, emp),
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: emp.isSuperAdmin
                                ? colors.gold.withValues(alpha: 0.2)
                                : colors.surfaceAlt,
                            child: Text(
                              emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'E',
                              style: TextStyle(
                                color: emp.isSuperAdmin ? colors.gold : colors.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          if (emp.isSuperAdmin)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: colors.gold,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.star, size: 12, color: Colors.black),
                              ),
                            ),
                        ],
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              emp.name,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colors.gold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: colors.gold.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                'Tú',
                                style: TextStyle(
                                  color: colors.gold,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            emp.email,
                            style: TextStyle(color: colors.textSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: emp.isSuperAdmin
                                      ? colors.gold.withValues(alpha: 0.15)
                                      : colors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: emp.isSuperAdmin ? colors.gold : colors.border,
                                  ),
                                ),
                                child: Text(
                                  emp.isSuperAdmin ? '👑 Super Admin' : '🛡️ Empleado',
                                  style: TextStyle(
                                    color: emp.isSuperAdmin ? colors.gold : colors.textPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: emp.isActive
                                      ? colors.statusActive.withValues(alpha: 0.12)
                                      : Colors.grey.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  emp.isActive ? 'Activo' : 'Inactivo',
                                  style: TextStyle(
                                    color: emp.isActive ? colors.statusActive : colors.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: colors.textSecondary),
                        color: colors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: colors.border),
                        ),
                        onSelected: (val) {
                          if (val == 'permissions') {
                            _showPermissionsDialog(context, emp);
                          }
                          if (val == 'toggle_active') {
                            provider.toggleEmployeeActive(emp.id);
                          }
                          if (val == 'delete' && !isMe) {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: colors.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: BorderSide(color: colors.border),
                                ),
                                title: Text('Eliminar Empleado', style: TextStyle(color: colors.textPrimary)),
                                content: Text(
                                  '¿Está seguro de eliminar a ${emp.name}? Se revocarán todas sus credenciales.',
                                  style: TextStyle(color: colors.textSecondary),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: Text('Cancelar', style: TextStyle(color: colors.textSecondary)),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      await provider.deleteEmployee(emp.id);
                                      if (ctx.mounted) Navigator.pop(ctx);
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                    child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'permissions',
                            child: Row(
                              children: [
                                Icon(Icons.tune_rounded, color: colors.gold, size: 18),
                                const SizedBox(width: 10),
                                Text('Configurar Permisos', style: TextStyle(color: colors.textPrimary)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'toggle_active',
                            child: Row(
                              children: [
                                Icon(
                                  emp.isActive ? Icons.toggle_off_rounded : Icons.toggle_on_rounded,
                                  color: colors.textSecondary,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  emp.isActive ? 'Desactivar' : 'Activar',
                                  style: TextStyle(color: colors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                          if (!isMe)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                  SizedBox(width: 10),
                                  Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

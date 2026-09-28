import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_role.dart';
import '../../providers/admin_provider.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  String _searchQuery = '';
  String _roleFilter = 'Todos';

  void _showBlockDialog(BuildContext context, dynamic user) {
    final colors = context.colors;
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Bloquear Usuario', style: TextStyle(color: colors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('¿Estás seguro de que deseas bloquear a ${user.name}?', style: TextStyle(color: colors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Razón del bloqueo',
                labelStyle: TextStyle(color: colors.textSecondary),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: colors.border)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: colors.gold)),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) return;
              await context.read<AdminProvider>().blockUser(
                user.id,
                user.name,
                user.email,
                reasonController.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Bloquear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, dynamic user) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Eliminar Usuario', style: TextStyle(color: colors.textPrimary)),
        content: Text(
          'Esta acción es irreversible. ¿Deseas eliminar permanentemente a ${user.name}?',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              await context.read<AdminProvider>().deleteUser(user.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final provider = context.watch<AdminProvider>();

    var filteredUsers = provider.users.where((u) {
      final matchesSearch = u.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                            u.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                            (u.companyName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      final matchesRole = _roleFilter == 'Todos' || u.role.label == _roleFilter;
      return matchesSearch && matchesRole;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gestión de Usuarios',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Supervisa exportadores colombianos e importadores europeos registrados',
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                style: TextStyle(color: colors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, empresa o correo...',
                  prefixIcon: Icon(Icons.search_rounded, color: colors.textMuted, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _FilterChip(
                label: 'Todos (${provider.users.length})',
                icon: Icons.people_alt_rounded,
                selected: _roleFilter == 'Todos',
                onTap: () => setState(() => _roleFilter = 'Todos'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Exportador (${provider.users.where((u) => u.role == UserRole.exportador).length})',
                icon: Icons.agriculture_rounded,
                selected: _roleFilter == 'Exportador',
                onTap: () => setState(() => _roleFilter = 'Exportador'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Importador (${provider.users.where((u) => u.role == UserRole.importador).length})',
                icon: Icons.public_rounded,
                selected: _roleFilter == 'Importador',
                onTap: () => setState(() => _roleFilter = 'Importador'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: filteredUsers.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_search_rounded, size: 48, color: colors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'No se encontraron usuarios',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Intenta con otro término de búsqueda o filtro',
                          style: TextStyle(color: colors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    final isExporter = user.role == UserRole.exportador;
                    final roleColor = isExporter ? colors.gold : const Color(0xFF3B82F6);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: colors.isDark ? 0.15 : 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: roleColor.withValues(alpha: 0.15),
                            child: Text(
                              user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                              style: TextStyle(
                                color: roleColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        user.name,
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: roleColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        user.role.label,
                                        style: TextStyle(
                                          color: roleColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (user.companyName != null && user.companyName!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4.0),
                                    child: Row(
                                      children: [
                                        Icon(Icons.business_rounded, size: 14, color: colors.textMuted),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            user.companyName!,
                                            style: TextStyle(
                                              color: colors.textSecondary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Row(
                                  children: [
                                    Icon(Icons.mail_outline_rounded, size: 14, color: colors.textMuted),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        user.email,
                                        style: TextStyle(
                                          color: colors.textMuted,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert_rounded, color: colors.textMuted, size: 20),
                            color: colors.surface,
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: colors.border),
                            ),
                            onSelected: (val) {
                              if (val == 'block') _showBlockDialog(context, user);
                              if (val == 'delete') _showDeleteDialog(context, user);
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'block',
                                child: Row(
                                  children: [
                                    const Icon(Icons.block_rounded, color: Colors.orangeAccent, size: 18),
                                    const SizedBox(width: 10),
                                    Text('Bloquear', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                    SizedBox(width: 10),
                                    Text('Eliminar', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        if (provider.blockedUsers.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: ExpansionTile(
              leading: const Icon(Icons.shield_rounded, color: Colors.redAccent),
              title: Text(
                'Usuarios Bloqueados (${provider.blockedUsers.length})',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              subtitle: const Text(
                'Perfiles suspendidos por actividad irregular',
                style: TextStyle(color: Colors.redAccent, fontSize: 11),
              ),
              children: provider.blockedUsers.map((bUser) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bUser.userName,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: Colors.redAccent,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Motivo: ${bUser.reason}',
                              style: TextStyle(color: colors.textSecondary, fontSize: 12),
                            ),
                            Text(
                              'Bloqueado por: ${bUser.blockedBy}',
                              style: TextStyle(color: colors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => provider.unblockUser(bUser.userId),
                        icon: const Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
                        label: const Text('Desbloquear', style: TextStyle(color: Colors.white, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.gold : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colors.gold : colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? (colors.isDark ? Colors.black : Colors.white) : colors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? (colors.isDark ? Colors.black : Colors.white) : colors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

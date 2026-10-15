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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;

        if (!isWide) {
          // Layout Vertical para móviles o pantallas reducidas
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUserHeader(colors),
                    const SizedBox(height: 16),
                    _buildSearchInput(colors),
                  ],
                ),
              ),
              _buildRoleChips(provider),
              const SizedBox(height: 14),
              Expanded(
                child: filteredUsers.isEmpty
                    ? _buildEmptyState(colors)
                    : _buildUserList(filteredUsers, colors, provider),
              ),
              if (provider.blockedUsers.isNotEmpty) _buildBlockedUsersSection(colors, provider),
            ],
          );
        }

        // Split-Layout Panorámico que ocupa toda la pantalla en Desktop
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Panel Lateral Izquierdo (360px): Filtros, Búsqueda y Vigilancia de Cuentas
              SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUserHeader(colors),
                      const SizedBox(height: 18),
                      _buildSearchInput(colors),
                      const SizedBox(height: 18),
                      Text(
                        'FILTRAR POR ROL OPERATIVO',
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildRoleFilterButtons(provider, colors),
                      const SizedBox(height: 20),
                      _buildCommunityStatsCard(colors, provider),
                      if (provider.blockedUsers.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildBlockedUsersSection(colors, provider),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 26),

              // Panel Principal Derecho: Cuadrícula / Lista Completa de Usuarios
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.people_alt_rounded, size: 20, color: colors.gold),
                              const SizedBox(width: 10),
                              Text(
                                'Directorio de Cuentas Activas',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors.surfaceAlt,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: colors.border),
                            ),
                            child: Text(
                              '${filteredUsers.length} cuentas encontradas',
                              style: TextStyle(
                                color: colors.gold,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: filteredUsers.isEmpty
                          ? _buildEmptyState(colors)
                          : _buildUserList(filteredUsers, colors, provider),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserHeader(dynamic colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.gold.withValues(alpha: 0.3)),
              ),
              child: Icon(Icons.manage_accounts_rounded, color: colors.gold, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gestión de Usuarios',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    'Productores & Compradores UE',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchInput(dynamic colors) {
    return TextField(
      style: TextStyle(color: colors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Buscar por nombre, correo...',
        prefixIcon: Icon(Icons.search_rounded, color: colors.textMuted, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: () => setState(() => _searchQuery = ''),
              )
            : null,
      ),
      onChanged: (val) => setState(() => _searchQuery = val),
    );
  }

  Widget _buildRoleFilterButtons(AdminProvider provider, dynamic colors) {
    final filters = [
      ('Todos', Icons.people_alt_rounded, provider.users.length),
      ('Exportador', Icons.agriculture_rounded, provider.users.where((u) => u.role == UserRole.exportador).length),
      ('Importador', Icons.public_rounded, provider.users.where((u) => u.role == UserRole.importador).length),
    ];

    return Column(
      children: filters.map((f) {
        final isSelected = _roleFilter == f.$1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: InkWell(
            onTap: () => setState(() => _roleFilter = f.$1),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? colors.gold.withValues(alpha: 0.15) : colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? colors.gold : colors.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(f.$2, size: 18, color: isSelected ? colors.gold : colors.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f.$1,
                      style: TextStyle(
                        color: isSelected ? colors.gold : colors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? colors.gold : colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${f.$3}',
                      style: TextStyle(
                        color: isSelected ? (colors.isDark ? Colors.black : Colors.white) : colors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCommunityStatsCard(dynamic colors, AdminProvider provider) {
    final expCount = provider.users.where((u) => u.role == UserRole.exportador).length;
    final impCount = provider.users.where((u) => u.role == UserRole.importador).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_rounded, size: 16, color: colors.gold),
              const SizedBox(width: 8),
              Text(
                'Distribución del Corredor',
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🇨🇴 Colombia', style: TextStyle(color: colors.textMuted, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text('$expCount Exp.', style: TextStyle(color: colors.gold, fontWeight: FontWeight.w800, fontSize: 16)),
                  ],
                ),
              ),
              Container(width: 1, height: 30, color: colors.border),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🇪🇺 Unión Europea', style: TextStyle(color: colors.textMuted, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text('$impCount Imp.', style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w800, fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChips(AdminProvider provider) {
    return SingleChildScrollView(
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
    );
  }

  Widget _buildEmptyState(dynamic colors) {
    return Center(
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
    );
  }

  Widget _buildUserList(List<dynamic> users, dynamic colors, AdminProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
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
              if (!provider.isManager)
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
    );
  }

  Widget _buildBlockedUsersSection(dynamic colors, AdminProvider provider) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
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
                if (!provider.isManager)
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

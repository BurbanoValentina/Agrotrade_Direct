import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../home/home_shell.dart';

/// REQ-02 / REQ-03: registro independiente para exportador e importador.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();

  UserRole _role = UserRole.exportador;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _companyCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      role: _role,
      companyName: _companyCtrl.text.trim().isEmpty
          ? null
          : _companyCtrl.text.trim(),
      country: _countryCtrl.text.trim().isEmpty ? null : _countryCtrl.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Error al registrarte')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isExporter = _role == UserRole.exportador;

    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const Text(
                  '¿Cómo vas a usar AgroTrade Direct?',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 10),
                // Selector de rol — mismo componente visual que el toggle
                // superior del mockup (Exporter Colombia / Importer EU).
                Row(
                  children: [
                    Expanded(
                      child: _RoleCard(
                        title: 'Exportador',
                        subtitle: 'Colombia',
                        icon: Icons.agriculture,
                        selected: isExporter,
                        onTap: () => setState(() => _role = UserRole.exportador),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RoleCard(
                        title: 'Importador',
                        subtitle: 'Unión Europea',
                        icon: Icons.public,
                        selected: !isExporter,
                        onTap: () => setState(() => _role = UserRole.importador),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(hintText: 'Nombre completo'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration:
                      const InputDecoration(hintText: 'Correo electrónico'),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Correo inválido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(hintText: 'Contraseña'),
                  validator: (v) => (v == null || v.length < 4)
                      ? 'Mínimo 4 caracteres'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _companyCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: isExporter
                        ? 'Finca / empresa exportadora (opcional)'
                        : 'Empresa importadora (opcional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _countryCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText:
                        isExporter ? 'Región de origen (opcional)' : 'País (opcional)',
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: auth.isLoading ? null : _submit,
                  child: auth.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Text('Crear cuenta'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold.withValues(alpha: 0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppColors.gold : AppColors.textMuted),
            const SizedBox(height: 8),
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selected ? AppColors.gold : AppColors.textPrimary)),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

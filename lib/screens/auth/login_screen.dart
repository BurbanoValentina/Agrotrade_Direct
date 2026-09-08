import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../home/home_shell.dart';
import 'register_screen.dart';

/// REQ-04: Inicio de sesión.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_emailCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Error al iniciar sesión')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 60),
                _Logo(),
                const SizedBox(height: 8),
                const Text(
                  'Café y cacao, directo de Colombia a la UE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.mail_outline,
                        color: AppColors.textMuted),
                  ),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Correo inválido' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Contraseña',
                    prefixIcon:
                        Icon(Icons.lock_outline, color: AppColors.textMuted),
                  ),
                  validator: (v) => (v == null || v.length < 4)
                      ? 'Mínimo 4 caracteres'
                      : null,
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
                      : const Text('Iniciar sesión'),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const RegisterScreen()),
                      );
                    },
                    child: const Text(
                      '¿No tienes cuenta? Regístrate',
                      style: TextStyle(color: AppColors.gold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.eco, color: Colors.black),
        ),
        const SizedBox(width: 10),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            children: [
              TextSpan(text: 'AgroTrade '),
              TextSpan(text: 'Direct', style: TextStyle(color: AppColors.gold)),
            ],
          ),
        ),
      ],
    );
  }
}

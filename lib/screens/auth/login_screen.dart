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
  // GlobalKey para gestionar y ejecutar las validaciones del Formulario
  final _formKey = GlobalKey<FormState>();

  // Controladores de texto para leer la entrada de los campos
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // Estado local para alternar la visibilidad del campo de contraseña
  bool _obscurePassword = true;

  @override
  void dispose() {
    // Liberación de memoria para prevenir memory leaks
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  /// Maneja la lógica al presionar el botón de inicio de sesión
  Future<void> _submit() async {
    // Valida todos los TextFormField dentro de este Form
    if (!_formKey.currentState!.validate()) return;

    // Obtiene AuthProvider sin suscribirse a cambios de estado (context.read)
    final auth = context.read<AuthProvider>();

    // Ejecuta el método asíncrono de autenticación
    final ok = await auth.login(_emailCtrl.text.trim(), _passwordCtrl.text);

    // Verificación de seguridad async: comprueba que el widget siga montado
    if (!mounted) return;

    if (ok) {
      // Redirección a la pantalla principal si el login fue exitoso
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    } else {
      // Muestra un SnackBar con el mensaje de error capturado
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Error al iniciar sesión'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escucha el AuthProvider para reaccionar a cambios en isLoading (context.watch)
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
                Text(
                  'Café y cacao, directo de Colombia a la UE',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 40),

                // Campo de entrada de Correo Electrónico
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.email],
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Correo electrónico',
                    prefixIcon: Icon(
                      Icons.mail_outline,
                      color: AppColors.textMuted,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Ingresa tu correo';
                    }
                    if (!v.contains('@') || !v.contains('.')) {
                      return 'Correo electrónico inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Campo de entrada de Contraseña
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.password],
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Contraseña',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: AppColors.textMuted,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textMuted,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 4)
                      ? 'Mínimo 4 caracteres'
                      : null,
                ),
                const SizedBox(height: 24),

                // Botón principal de login
                ElevatedButton(
                  onPressed: auth.isLoading ? null : _submit,
                  child: auth.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text('Iniciar sesión'),
                ),
                const SizedBox(height: 16),

                // Botón para ir al Registro (REQ-02 / REQ-03)
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
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

/// Widget privado para renderizar el logo
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
              TextSpan(
                text: 'Direct',
                style: TextStyle(color: AppColors.gold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

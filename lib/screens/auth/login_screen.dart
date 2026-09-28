import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/mock/mock_admin_data.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/theme_toggle_button.dart';
import '../admin/admin_login_screen.dart';
import '../admin/admin_shell.dart';
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

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    // 1. Detectar credenciales maestras para el panel oculto de empleados
    if (email.toLowerCase() == adminGateEmail.toLowerCase() &&
        password == adminGatePassword) {
      _passwordCtrl.clear();
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      );
      return;
    }

    // Obtiene AdminProvider sin suscribirse a cambios de estado (context.read)
    final admin = context.read<AdminProvider>();

    // 2. Verificar si el usuario está bloqueado por el administrador
    if (admin.isUserBlocked(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Esta cuenta ha sido bloqueada permanentemente por actividades sospechosas.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 3. Intentar autenticación directa como empleado interno
    final isEmployee = await admin.loginEmployee(email, password);
    // Verificación de seguridad async: comprueba que el widget siga montado
    if (!mounted) return;
    if (isEmployee) {
      _passwordCtrl.clear();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminShell()),
      );
      return;
    }

    // 4. Autenticación de usuario regular de la plataforma
    // (context.read: no se suscribe a cambios de estado)
    final auth = context.read<AuthProvider>();

    // Ejecuta el método asíncrono de autenticación
    final ok = await auth.login(email, password);

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
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border:
                      Border.all(color: colors.border.withValues(alpha: 0.8)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: colors.isDark ? 0.25 : 0.04),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.topRight,
                        child: ThemeToggleButton(compact: true),
                      ),
                      const SizedBox(height: 8),
                      const _Logo(),
                      const SizedBox(height: 12),
                      Text(
                        'Café y cacao, directo de Colombia a la UE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.gold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: colors.gold.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded,
                                  size: 13, color: colors.gold),
                              const SizedBox(width: 4),
                              Text(
                                'Intercambio B2B Certificado',
                                style: TextStyle(
                                  color: colors.gold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Campo de entrada de Correo Electrónico
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.email],
                        style:
                            TextStyle(color: colors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Correo electrónico',
                          labelText: 'Correo electrónico',
                          prefixIcon: Icon(Icons.mail_outline_rounded,
                              color: colors.textMuted, size: 20),
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
                      const SizedBox(height: 16),

                      // Campo de entrada de Contraseña
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.password],
                        style:
                            TextStyle(color: colors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Contraseña',
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock_outline_rounded,
                              color: colors.textMuted, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: colors.textMuted,
                              size: 18,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        // Se mantiene el mínimo de 4 caracteres de main para no
                        // bloquear credenciales mock de empleados/usuarios
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Mínimo 4 caracteres'
                            : null,
                      ),
                      const SizedBox(height: 24),

                      // Botón principal de login
                      ElevatedButton(
                        onPressed: auth.isLoading ? null : _submit,
                        child: auth.isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.isDark
                                      ? Colors.black
                                      : Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.login_rounded,
                                      size: 18,
                                      color: colors.isDark
                                          ? Colors.black
                                          : Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Iniciar sesión',
                                    style: TextStyle(
                                      color: colors.isDark
                                          ? Colors.black
                                          : Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 20),

                      // Enlace para ir al Registro (REQ-02 / REQ-03)
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '¿No tienes cuenta? ',
                            style: TextStyle(
                                color: colors.textSecondary, fontSize: 13),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const RegisterScreen()),
                              );
                            },
                            child: Text(
                              'Regístrate',
                              style: TextStyle(
                                color: colors.gold,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),

                      // Acceso al panel interno de empleados
                      InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const AdminLoginScreen()),
                          );
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: colors.surfaceAlt,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.admin_panel_settings_rounded,
                                  size: 20, color: colors.gold),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  '🔒 Acceso Empleados / Panel Interno',
                                  style: TextStyle(
                                    color: colors.gold,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget privado para renderizar el logo
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.gold, colors.goldDark],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colors.gold.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.eco_rounded,
            size: 30,
            color: colors.isDark ? Colors.black : Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: colors.textPrimary,
            ),
            children: [
              const TextSpan(text: 'AgroTrade '),
              TextSpan(text: 'Direct', style: TextStyle(color: colors.gold)),
            ],
          ),
        ),
      ],
    );
  }
}

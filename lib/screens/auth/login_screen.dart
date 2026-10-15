import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/mock/mock_admin_data.dart';
import '../../models/user_role.dart';
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

  // Rol seleccionado para inicio con cuenta demo expo/impo
  UserRole _selectedRole = UserRole.exportador;

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

    // 0. Credencial dual demo para Exportador / Importador
    final cleanEmail = email.toLowerCase();
    if ((cleanEmail == 'expo/impo@gmail.com' || cleanEmail == 'expo@gmail.com' || cleanEmail == 'impo@gmail.com') &&
        password == 'admin12345') {
      final auth = context.read<AuthProvider>();
      await auth.login(email, password, preferredRole: _selectedRole);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
      return;
    }

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
    final ok = await auth.login(email, password, preferredRole: _selectedRole);

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
    final auth = context.watch<AuthProvider>();
    final colors = context.colors;
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 900;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // Ambient luxury background shapes
          Positioned(
            top: -120,
            left: -100,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.gold.withValues(alpha: colors.isDark ? 0.18 : 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            right: -120,
            child: Container(
              width: 440,
              height: 440,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF3B82F6).withValues(alpha: colors.isDark ? 0.14 : 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main Responsive Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isWide ? 960 : 460),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: colors.border.withValues(alpha: 0.9)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: colors.isDark ? 0.35 : 0.06),
                          blurRadius: 32,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Left: Branding Showcase (Visible on Wide screens)
                              Expanded(
                                flex: 5,
                                child: Container(
                                  padding: const EdgeInsets.all(40),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        colors.surfaceAlt,
                                        colors.surface,
                                      ],
                                    ),
                                    border: Border(
                                      right: BorderSide(color: colors.border),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _Logo(onAdminSecretTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
                                        );
                                      }),
                                      const SizedBox(height: 28),
                                      Text(
                                        'Conectamos el campo colombiano con los compradores más selectos de la Unión Europea.',
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 15,
                                          height: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 32),
                                      _buildFeatureItem(
                                        colors,
                                        Icons.verified_rounded,
                                        'Certificaciones Internacionales',
                                        'Transparencia total en sellos EU Organic y Rainforest.',
                                      ),
                                      const SizedBox(height: 18),
                                      _buildFeatureItem(
                                        colors,
                                        Icons.currency_exchange_rounded,
                                        'Cotizaciones en Tiempo Real',
                                        'Precios de referencia oficiales ICE / LME actualizados.',
                                      ),
                                      const SizedBox(height: 18),
                                      _buildFeatureItem(
                                        colors,
                                        Icons.shield_outlined,
                                        'Privacidad Comercial Garantizada',
                                        'Términos bilaterales y contratos confidenciales seguros.',
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Right: Login Form
                              Expanded(
                                flex: 5,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 36),
                                  child: _buildLoginForm(auth, colors),
                                ),
                              ),
                            ],
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                            child: _buildLoginForm(auth, colors),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(AppThemeColors colors, IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colors.gold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: colors.gold, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(AuthProvider auth, AppThemeColors colors) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Logo(
                isCompact: true,
                onAdminSecretTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
                  );
                },
              ),
              const ThemeToggleButton(compact: true),
            ],
          ),
          const SizedBox(height: 20),

          Text(
            '¡Bienvenido de vuelta!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ingresa a tu cuenta para gestionar operaciones y mercado.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),

          // Selector de Rol si ingresa como Usuario Comercial (Exportador / Importador)
          Container(
            decoration: BoxDecoration(
              color: colors.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedRole = UserRole.exportador),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _selectedRole == UserRole.exportador ? colors.gold : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _selectedRole == UserRole.exportador
                            ? [
                                BoxShadow(
                                  color: colors.gold.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🇨🇴', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Text(
                            'Exportador',
                            style: TextStyle(
                              color: _selectedRole == UserRole.exportador
                                  ? (colors.isDark ? Colors.black : Colors.white)
                                  : colors.textSecondary,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedRole = UserRole.importador),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _selectedRole == UserRole.importador ? const Color(0xFF3B82F6) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _selectedRole == UserRole.importador
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🇪🇺', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Text(
                            'Importador',
                            style: TextStyle(
                              color: _selectedRole == UserRole.importador
                                  ? Colors.white
                                  : colors.textSecondary,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Campo de entrada de Correo Electrónico
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.email],
            style: TextStyle(color: colors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'correo@ejemplo.com',
              labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.mail_outline_rounded, color: colors.gold, size: 20),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Ingresa tu correo';
              }
              final val = v.trim().toLowerCase();
              if (val == 'expo/impo@gmail.com') return null;
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
            style: TextStyle(color: colors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Tu contraseña',
              labelText: 'Contraseña',
              prefixIcon: Icon(Icons.lock_outline_rounded, color: colors.gold, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: colors.textMuted,
                  size: 18,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) => (v == null || v.length < 4) ? 'Mínimo 4 caracteres' : null,
          ),
          const SizedBox(height: 20),

          // Botón principal de login
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: auth.isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.gold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 3,
              ),
              child: auth.isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.isDark ? Colors.black : Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: colors.isDark ? Colors.black : Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Entrar a la Plataforma',
                          style: TextStyle(
                            color: colors.isDark ? Colors.black : Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Enlace para ir al Registro
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '¿Aún no tienes cuenta? ',
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
                child: Text(
                  'Crear cuenta',
                  style: TextStyle(
                    color: colors.gold,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Widget para renderizar el logo con botón secreto integrado en el título
class _Logo extends StatelessWidget {
  const _Logo({this.isCompact = false, this.onAdminSecretTap});

  final bool isCompact;
  final VoidCallback? onAdminSecretTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (isCompact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onAdminSecretTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.gold, colors.goldDark],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: colors.gold.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                Icons.eco_rounded,
                size: 22,
                color: colors.isDark ? Colors.black : Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: colors.textPrimary,
              ),
              children: [
                const TextSpan(text: 'AgroTrade '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: InkWell(
                    onTap: onAdminSecretTap,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        'Direct',
                        style: TextStyle(
                          color: colors.gold,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onAdminSecretTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.gold, colors.goldDark],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: colors.gold.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              Icons.eco_rounded,
              size: 32,
              color: colors.isDark ? Colors.black : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              color: colors.textPrimary,
            ),
            children: [
              const TextSpan(text: 'AgroTrade '),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: InkWell(
                  onTap: onAdminSecretTap,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      'Direct',
                      style: TextStyle(
                        color: colors.gold,
                        fontWeight: FontWeight.w900,
                        fontSize: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

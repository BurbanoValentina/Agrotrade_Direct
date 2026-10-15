import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/theme_toggle_button.dart';
import '../home/home_shell.dart';

/// REQ-02 / REQ-03: Registro independiente para exportador e importador.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Clave global para validar el formulario de registro
  final _formKey = GlobalKey<FormState>();

  // Controladores de campos de texto
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();

  // Rol predeterminado seleccionado al abrir la pantalla
  UserRole _role = UserRole.exportador;

  // Estado local para ocultar o mostrar la contraseña
  bool _obscurePassword = true;

  @override
  void dispose() {
    // Liberación de recursos de memoria de los controladores
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _companyCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  /// Ejecuta el proceso de registro
  Future<void> _submit() async {
    // Valida todos los campos del formulario
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();

    // Llama al método de registro pasando los datos según el rol seleccionado
    final ok = await auth.register(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      role: _role,
      companyName:
          _companyCtrl.text.trim().isEmpty ? null : _companyCtrl.text.trim(),
      country:
          _countryCtrl.text.trim().isEmpty ? null : _countryCtrl.text.trim(),
    );

    // Verificación de seguridad asíncrona antes de usar context
    if (!mounted) return;

    if (ok) {
      // Limpia la pila de navegación y redirige al HomeShell
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (route) => false,
      );
    } else {
      // Muestra mensaje de error en caso de fallo
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Error al registrarte'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final colors = context.colors;
    final isExporter = _role == UserRole.exportador;
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 900;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // Ambient background glow shapes
          Positioned(
            top: -120,
            right: -100,
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
            left: -120,
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

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isWide ? 960 : 500),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left info column
                              Expanded(
                                flex: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(40),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [colors.surfaceAlt, colors.surface],
                                    ),
                                    border: Border(right: BorderSide(color: colors.border)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      IconButton(
                                        onPressed: () => Navigator.pop(context),
                                        icon: const Icon(Icons.arrow_back_rounded),
                                        style: IconButton.styleFrom(
                                          backgroundColor: colors.surface,
                                          foregroundColor: colors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        'Únete a la Red Comercial',
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.6,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Crea tu cuenta empresarial y comienza a negociar café y cacao con trazabilidad y precios directos.',
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 14,
                                          height: 1.45,
                                        ),
                                      ),
                                      const SizedBox(height: 36),
                                      _buildBenefitItem(
                                        colors,
                                        Icons.handshake_outlined,
                                        'Negociación Bilateral Directa',
                                        'Trato directo entre productor certificado y comprador europeo.',
                                      ),
                                      const SizedBox(height: 20),
                                      _buildBenefitItem(
                                        colors,
                                        Icons.verified_user_outlined,
                                        'Garantía de Origen y Calidad',
                                        'Carga y validación oficial de certificados orgánicos.',
                                      ),
                                      const SizedBox(height: 20),
                                      _buildBenefitItem(
                                        colors,
                                        Icons.security_rounded,
                                        'Cumplimiento y Seguridad',
                                        'Monitoreo continuo contra fraudes e intermediarios no autorizados.',
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Right form column
                              Expanded(
                                flex: 5,
                                child: Padding(
                                  padding: const EdgeInsets.all(36),
                                  child: _buildRegisterForm(auth, colors, isExporter),
                                ),
                              ),
                            ],
                          )
                        : Padding(
                            padding: const EdgeInsets.all(26),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      onPressed: () => Navigator.pop(context),
                                      icon: const Icon(Icons.arrow_back_rounded),
                                    ),
                                    const ThemeToggleButton(compact: true),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _buildRegisterForm(auth, colors, isExporter),
                              ],
                            ),
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

  Widget _buildBenefitItem(AppThemeColors colors, IconData icon, String title, String desc) {
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
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(color: colors.textSecondary, fontSize: 11.5, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm(AuthProvider auth, AppThemeColors colors, bool isExporter) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Crear Cuenta Comercial',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Selecciona tu perfil para personalizar tu entorno de trabajo:',
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 18),

          // Selector visual de Rol
          Row(
            children: [
              Expanded(
                child: _RoleCard(
                  title: 'Exportador',
                  subtitle: '🇨🇴 Colombia',
                  icon: Icons.agriculture_rounded,
                  selected: isExporter,
                  onTap: () => setState(() => _role = UserRole.exportador),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RoleCard(
                  title: 'Importador',
                  subtitle: '🇪🇺 Unión Europea',
                  icon: Icons.public_rounded,
                  selected: !isExporter,
                  onTap: () => setState(() => _role = UserRole.importador),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Campo: Nombre Completo
          TextFormField(
            controller: _nameCtrl,
            style: TextStyle(color: colors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Nombre completo',
              hintText: 'Ej. Juan Pérez / Anna Becker',
              prefixIcon: Icon(Icons.person_outline_rounded, color: colors.gold, size: 20),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
          ),
          const SizedBox(height: 14),

          // Campo: Correo Electrónico
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: TextStyle(color: colors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Correo electrónico',
              hintText: 'contacto@empresa.com',
              prefixIcon: Icon(Icons.mail_outline_rounded, color: colors.gold, size: 20),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
              if (!v.contains('@') || !v.contains('.')) return 'Correo electrónico inválido';
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Campo: Contraseña
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            style: TextStyle(color: colors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Contraseña',
              hintText: 'Mínimo 4 caracteres',
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
          const SizedBox(height: 14),

          // Campo dinámico: Nombre de Finca o Empresa
          TextFormField(
            controller: _companyCtrl,
            style: TextStyle(color: colors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              labelText: isExporter ? 'Finca / Empresa exportadora' : 'Empresa importadora',
              hintText: isExporter ? 'Finca La Esmeralda (opcional)' : 'Hanseatic Coffee GmbH (opcional)',
              prefixIcon: Icon(Icons.business_outlined, color: colors.gold, size: 20),
            ),
          ),
          const SizedBox(height: 14),

          // Campo dinámico: Región o País
          TextFormField(
            controller: _countryCtrl,
            style: TextStyle(color: colors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              labelText: isExporter ? 'Región cafetera / cacaotera' : 'País de destino (UE)',
              hintText: isExporter ? 'Huila, Nariño, Antioquia...' : 'Alemania, Países Bajos, Francia...',
              prefixIcon: Icon(Icons.place_outlined, color: colors.gold, size: 20),
            ),
          ),
          const SizedBox(height: 24),

          // Botón principal de registro
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
                        Icon(Icons.person_add_rounded, size: 18, color: colors.isDark ? Colors.black : Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Completar Registro',
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

          // Volver al login
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                '¿Ya tienes cuenta? Inicia sesión aquí',
                style: TextStyle(
                  color: colors.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget privado para renderizar cada tarjeta de selección de rol
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
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        decoration: BoxDecoration(
          color: selected
              ? colors.gold.withValues(alpha: 0.12)
              : colors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? colors.gold : colors.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colors.gold.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: selected ? colors.gold : colors.textMuted,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: selected ? colors.gold : colors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
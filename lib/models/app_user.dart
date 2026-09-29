import 'user_role.dart';

/// Usuario de la plataforma (exportador, importador o staff).
///
/// Es el "contrato" que devuelve `AuthRepository`; en Supabase se arma desde
/// la tabla `profiles` con [AppUser.fromProfile].
class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? companyName;
  final String? country;

  /// Cuenta de pruebas (REQ-29): al iniciar sesión se muestra el panel de QA.
  /// Solo la activa un admin con `rpc('set_tester')`.
  final bool isTester;

  /// Cuenta creada por invitación (empleados del panel admin) que aún no ha
  /// definido su contraseña: la app debe pedírsela antes de continuar
  /// (`AuthRepository.changePassword`).
  final bool mustSetPassword;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.companyName,
    this.country,
    this.isTester = false,
    this.mustSetPassword = false,
  });

  /// Personal del panel de administración (sus permisos están en
  /// `staff_members`; ver supabase/README.md → Roles y permisos).
  bool get isStaff => role == UserRole.staff;

  /// Fila de `public.profiles` (claves en snake_case).
  factory AppUser.fromProfile(
    Map<String, dynamic> row, {
    String? fallbackEmail,
    bool mustSetPassword = false,
  }) {
    return AppUser(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      email: row['email'] as String? ?? fallbackEmail ?? '',
      role: parseUserRole(row['role'] as String?),
      companyName: row['company_name'] as String?,
      country: row['country'] as String?,
      isTester: row['is_tester'] as bool? ?? false,
      mustSetPassword: mustSetPassword,
    );
  }

  AppUser copyWith({bool? mustSetPassword}) {
    return AppUser(
      id: id,
      name: name,
      email: email,
      role: role,
      companyName: companyName,
      country: country,
      isTester: isTester,
      mustSetPassword: mustSetPassword ?? this.mustSetPassword,
    );
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      role: parseUserRole(map['role'] as String?),
      companyName: map['companyName'] as String?,
      country: map['country'] as String?,
      isTester: map['isTester'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.name,
        'companyName': companyName,
        'country': country,
        'isTester': isTester,
      };
}

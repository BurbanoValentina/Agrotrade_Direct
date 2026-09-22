import 'user_role.dart';

/// Usuario de la plataforma (exportador o importador).
///
/// Este modelo es intencionalmente simple: cuando el/la compañero(a) de
/// backend conecte Supabase, este es el "contrato" que debe seguir
/// devolviendo desde `SupabaseAuthRepository`.
class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? companyName;
  final String? country;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.companyName,
    this.country,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      role: (map['role'] as String) == 'exportador'
          ? UserRole.exportador
          : UserRole.importador,
      companyName: map['companyName'] as String?,
      country: map['country'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.name,
        'companyName': companyName,
        'country': country,
      };
}

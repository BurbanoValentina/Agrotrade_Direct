/// Registro de un usuario bloqueado de la plataforma.
///
/// Cuando un admin bloquea un perfil, se almacena el motivo y la fecha.
/// El usuario bloqueado no podrá volver a iniciar sesión.
class BlockedUser {
  final String userId;
  final String userName;
  final String userEmail;
  final String reason;
  final DateTime blockedAt;
  final String blockedBy;

  const BlockedUser({
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.reason,
    required this.blockedAt,
    required this.blockedBy,
  });
}

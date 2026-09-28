/// Error de un repositorio con un mensaje listo para mostrar al usuario.
///
/// Los repositorios lanzan esta excepción en lugar de devolver `false`, para
/// que la UI pueda explicar el motivo exacto (ej. "Ya tienes una solicitud
/// activa para esta oferta") con `SnackBar(content: Text(e.message))`.
class RepositoryException implements Exception {
  const RepositoryException(this.message);

  final String message;

  @override
  String toString() => 'RepositoryException: $message';
}

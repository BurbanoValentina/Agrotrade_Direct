# Base de datos — Supabase

Responsable: Johan Delgado (Backend & Database Engineer).

## Estructura

```
supabase/
├── migrations/   Cambios de esquema versionados, en orden de aplicación
└── seed.sql      Datos de prueba (exportador demo + 5 ofertas)
```

Cada archivo de `migrations/` se llama `AAAAMMDDHHMMSS_descripcion.sql` (formato de la Supabase CLI). El prefijo de fecha define el orden en que se aplican.

| Migración | Contenido |
| :--- | :--- |
| `20260925000000_base.sql` | Tablas `profiles`, `offers`, `negotiations`, triggers y políticas RLS (REQ-14, REQ-15, REQ-23, REQ-24) |
| `20260925010000_audit_log.sql` | Tabla `audit_log` y triggers que registran cambios de precio, volumen y estado en `offers` y `negotiations` (REQ-32) |
| `20260925020000_rbac_staff.sql` | Empleados admin con permisos (`staff_members`), `blocked_users`, `profiles.is_tester` y políticas de administrador (REQ-24, base de REQ-29 y REQ-33) |
| `20260925030000_ratings_reports_admin.sql` | `ratings`, `user_reports`, `suspicious_activities` (con detección de precios anómalos), `platform_config` y `rpc('admin_dashboard_stats')` (REQ-23, base de REQ-21, REQ-22, REQ-33 y REQ-37) |
| `20260925040000_purchase_request_rules.sql` | Reglas de la solicitud de compra con mensajes claros: volumen ≤ disponible, una solicitud activa por oferta, notas ≤ 500; completa `seller_id` desde la oferta (REQ-14) |

## Roles y permisos

| Rol | Cómo se obtiene | Qué puede hacer |
| :--- | :--- | :--- |
| `exportador` | Registro en la app | Publicar y editar sus ofertas; aceptar/rechazar solicitudes recibidas |
| `importador` | Registro en la app | Enviar solicitudes; cancelar las propias |
| `staff` | Al agregarlo a `staff_members` | Solo lo que otorgan sus permisos (no puede publicar ni negociar) |

Permisos de `staff_members.permissions` (mismos nombres que `AdminPermission` en Flutter):

| Permiso | Habilita |
| :--- | :--- |
| `offerManagement` | Editar y eliminar cualquier oferta |
| `negotiationManagement` | Ver todas las negociaciones |
| `userManagement` | Bloquear / desbloquear usuarios; marcar testers con `rpc('set_tester')` |
| `security` | Ver todo el `audit_log` |
| `employeeManagement` | Agregar, editar y quitar empleados |

Un `is_super_admin` tiene todos los permisos. Nadie puede modificar sus propios permisos, y solo un super admin gestiona a otro super admin.

### Crear el primer super admin (una sola vez)

1. *Authentication → Users → Add user* con el correo del admin (marcar *Auto Confirm User*).
2. En el SQL Editor:
   ```sql
   INSERT INTO public.staff_members (user_id, is_super_admin)
   SELECT id, true FROM auth.users WHERE email = 'correo-del-admin@ejemplo.com';
   ```

## Reglas

1. **Nunca editar una migración que ya se aplicó** en el proyecto compartido. Si hay que cambiar algo, se crea una migración nueva.
2. Una migración por cambio lógico (ej. `..._audit_log.sql`, `..._admin_role.sql`), con el REQ que cubre en el encabezado.
3. Toda tabla nueva debe llevar `ENABLE ROW LEVEL SECURITY` y sus políticas en la misma migración.
4. Actualizar la tabla de arriba al agregar una migración.

## Aplicar las migraciones

### Opción A — SQL Editor del Dashboard

Ejecutar cada archivo de `migrations/` **en orden**, pegándolo en *SQL Editor → New query → Run*. Solo hace falta ejecutar las migraciones que aún no se hayan aplicado.

### Opción B — Supabase CLI

```bash
supabase link --project-ref <ref-del-proyecto>
supabase db push
```

Si la base ya se creó a mano desde el SQL Editor, marcar primero la migración base como aplicada para que la CLI no intente repetirla:

```bash
supabase migration repair --status applied 20260925000000
```

## Backup y restauración (REQ-40)

Rutina manual con los scripts de `scripts/`. Requieren `pg_dump` y `psql` versión 15 o superior (vienen con PostgreSQL; basta la versión portable "binaries").

**Cadena de conexión:** Dashboard → **Connect** → **Session pooler** → copiar la URI y reemplazar `[YOUR-PASSWORD]` por la contraseña de la base. No se guarda en el repositorio: se pega cuando el script la pide o se deja en la variable de entorno `SUPABASE_DB_URL` de la sesión.

### Hacer un backup

```powershell
.\scripts\backup_db.ps1 -PgBin "C:\ruta\a\pgsql\bin"
```

Crea `backups/AAAA-MM-DD_HHMM/` con `data.sql` (datos de public), `auth.sql` (usuarios), `schema.sql` (referencia) y `manifest.txt` (conteo de filas por tabla).

> ⚠️ Los backups contienen correos y datos de usuarios. La carpeta `backups/` está en `.gitignore`: **nunca** subirla al repositorio (es público). Guardarla en un lugar privado.

Frecuencia recomendada: antes de cada entrega/demo y antes de aplicar una migración nueva.

### Restaurar (ej. si se pierde o daña el proyecto)

1. Crear un proyecto de Supabase nuevo (o usar uno vacío).
2. Aplicar **en orden** todas las migraciones de `supabase/migrations/`.
3. Ejecutar:
   ```powershell
   .\scripts\restore_db.ps1 -BackupDir backups\AAAA-MM-DD_HHMM -PgBin "C:\ruta\a\pgsql\bin"
   ```
4. Comparar los conteos que muestra el script con `manifest.txt`.
5. Actualizar `supabase_constants.dart` con la URL y anon key del proyecto nuevo.

El script se niega a restaurar sobre una base que ya tiene usuarios u ofertas, pide escribir el host destino para confirmar y carga todo en una sola transacción (si algo falla, no queda nada a medias).

## Datos de prueba

1. Crear el usuario `exportador.demo@agrotrade.com` / `password123` en *Authentication → Users → Add user* (marcar *Auto Confirm User*).
2. Ejecutar `seed.sql` en el SQL Editor. Se puede repetir sin duplicar ofertas.

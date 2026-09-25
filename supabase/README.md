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

## Datos de prueba

1. Crear el usuario `exportador.demo@agrotrade.com` / `password123` en *Authentication → Users → Add user* (marcar *Auto Confirm User*).
2. Ejecutar `seed.sql` en el SQL Editor. Se puede repetir sin duplicar ofertas.

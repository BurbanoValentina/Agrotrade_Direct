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

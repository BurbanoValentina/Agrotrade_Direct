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
| `20260926000000_negotiation_flow.sql` | Flujo estilo InDrive: `negotiation_rounds`, RPC `counter_offer` / `accept_negotiation` / `reject_negotiation` / `cancel_negotiation` / `confirm_negotiation`, confirmación doble, límite de 10 rondas, descuento de volumen (REQ-15, REQ-16, REQ-17) |
| `20260926010000_operation_history.sql` | RPC `my_operation_history` y `negotiation_timeline` (REQ-19, base de REQ-30); impide borrar ofertas con tratos confirmados; corrige la regla de revisión de alertas/reportes ante borrados en cascada |

## Flujo de negociación (REQ-14 a REQ-17)

```
Importador envía solicitud (INSERT en negotiations) ──► pending   (turno del exportador)
  exportador: counter_offer ──► countered (turno del importador)
  importador: counter_offer ──► pending   (turno del exportador)
  quien tiene el turno: accept_negotiation ──► accepted
                        reject_negotiation ──► rejected
  importador (pending/countered) o cualquiera (accepted): cancel_negotiation ──► cancelled
accepted: cada parte llama confirm_negotiation; con la 2.ª ──► confirmed
```

- **Turno:** `pending` → responde el exportador; `countered` → responde el importador. Nadie acepta su propia propuesta.
- **Rondas:** máximo 10 (la solicitud cuenta como la 1). En la 10 solo se puede aceptar o rechazar. Historial en la tabla `negotiation_rounds`.
- **Confirmación:** el trato se cierra cuando **ambas partes** confirman. Entonces se descuenta el volumen de la oferta (si llega a 0 → `confirmada`), se suma `completed_trades` a los dos y se rechazan solas las solicitudes vivas que ya no caben. Las calificaciones solo se permiten sobre tratos `confirmed`.
- **Estado de la oferta:** pasa sola a `negociando` con la primera solicitud y vuelve a `activa` cuando no quedan negociaciones vivas.
- La app **no puede** hacer `UPDATE` directo a `negotiations`: todo cambio va por estas funciones. Cada una devuelve la negociación actualizada o un error con el motivo (código `P0001`).

| RPC | Parámetros | Quién |
| :--- | :--- | :--- |
| `counter_offer` | `p_negotiation_id`, `p_price_per_mt`, `p_volume_mt` (opcional), `p_message` (opcional) | Quien tiene el turno |
| `accept_negotiation` | `p_negotiation_id` | Quien tiene el turno |
| `reject_negotiation` | `p_negotiation_id`, `p_reason` (opcional) | Quien tiene el turno |
| `cancel_negotiation` | `p_negotiation_id`, `p_reason` (opcional) | Importador (en curso) o cualquiera (aceptada) |
| `confirm_negotiation` | `p_negotiation_id` | Cada parte, una vez |

En Flutter ya están envueltas en `OfferRepository` (`counterOffer`, `acceptPurchaseRequest`, `rejectPurchaseRequest`, `cancelNegotiation`, `confirmNegotiation`, `fetchNegotiationRounds`) y `PurchaseRequest` trae los ayudantes `isTurnOf`, `canCounter`, `needsConfirmationFrom` para decidir qué botones mostrar.

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

## Historial de operaciones (REQ-19 / REQ-30)

| RPC | Parámetros (todos opcionales salvo el id) | Devuelve |
| :--- | :--- | :--- |
| `my_operation_history` | `p_from`, `p_to` (fechas), `p_status` (`confirmed` / `rejected` / `cancelled`), `p_all_users` (solo con `negotiationManagement`) | Operaciones cerradas del usuario: producto, contraparte, precio, volumen, total, rondas, fechas, motivo, `my_role` |
| `negotiation_timeline` | `p_negotiation_id` | Eventos en orden: `propuesta`, `aceptada`, `confirmacion`, `confirmada`, `rechazada`, `cancelada` |

En Flutter: `OfferRepository.fetchOperationHistory()` / `fetchNegotiationTimeline()` y, para exportar, `OperationHistoryExporter` (`lib/services/`) con `toCsv()` y `toPdf()`.

Una oferta con tratos confirmados **no se puede eliminar** (se perdería el historial): se debe cambiar a estado `cerrada`.

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

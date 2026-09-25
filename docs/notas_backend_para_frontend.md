# Notas de backend para frontend

Pendientes de UI que dependen de cambios ya hechos en el backend. Autor: Johan Delgado (Backend). Para: Omar Acosta (Flutter) y Valentina Burbano (UI/QA).

Cada punto indica el archivo a tocar y el código de backend que ya está listo para usar.

---

## REQ-14 — Solicitud de compra (Market)

El backend ya acepta **volumen y notas** y devuelve **el motivo exacto** cuando rechaza una solicitud.

### 1. Mostrar el motivo del error en vez del mensaje genérico
`lib/screens/market/market_screen.dart` (`onMakeOffer`). Hoy muestra *"No se pudo enviar la contraoferta"*. El motivo real está en `market.lastError`:

```dart
final ok = await market.sendCounterOffer(offer.id, price);
if (!context.mounted) return;
ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  content: Text(ok
      ? 'Solicitud de \$${price.toStringAsFixed(0)}/MT enviada'
      : market.lastError ?? 'No se pudo enviar la solicitud'),
));
```

Mensajes posibles (vienen de la BD): *"Ya tienes una solicitud activa para esta oferta."*, *"El volumen solicitado (30 MT) supera el disponible (22 MT)."*, *"Esta oferta ya no recibe solicitudes (estado: confirmada)."*, *"Tu cuenta está bloqueada..."*, *"Solo los importadores pueden enviar solicitudes de compra."*

### 2. Campos de volumen y notas en el modal
`lib/screens/market/widgets/counter_offer_sheet.dart`. Hoy solo pide precio y el backend asume el volumen completo de la oferta. Agregar:
- **Volumen (MT)**: opcional, entre 0 y `offer.volumeMt`. Si se deja vacío se pide todo.
- **Notas**: opcional, máximo 500 caracteres (constante `maxPurchaseRequestNotesLength` en `offer_repository.dart`).

El modal debería devolver los tres valores y llamar:
```dart
market.sendCounterOffer(offer.id, price, volumeMt: volume, notes: notes);
```

### 3. Validar el precio antes de cerrar el modal
Si el texto no es un número válido, hoy `double.tryParse` devuelve `null` y el modal se cierra sin avisar. Mostrar un error en el campo si está vacío, no es numérico o es ≤ 0.

### 4. Botón "Make an Offer" solo para importadores
`offer_card.dart` / `market_screen.dart`: la BD rechaza solicitudes de exportadores y staff. Mostrar el botón solo si `user.role == UserRole.importador`.

---

## Carga de ofertas (Market)

`MarketProvider.loadOffers()` ya no se queda cargando para siempre si falla. Ahora expone `market.loadError`. Falta mostrarlo en `market_screen.dart` (mensaje + botón "Reintentar" que llame a `market.loadOffers()`), en lugar de la lista vacía.

---

## Panel de administración (REQ-24 / REQ-33)

El backend de roles y permisos ya existe (ver `supabase/README.md` → *Roles y permisos*). Para conectarlo:

1. **Quitar la contraseña maestra.** `lib/data/mock/mock_admin_data.dart` tiene `adminGateEmail` / `adminGatePassword` (`admin12345`) y un correo real, y el repo es público. Con Supabase, los empleados inician sesión con el login normal.
2. **Detectar si el usuario es staff después del login:**
   ```dart
   final isStaff = await supabase.rpc('is_staff') as bool;
   final row = await supabase.from('staff_members')
       .select().eq('user_id', supabase.auth.currentUser!.id).single();
   // row['is_super_admin'], row['permissions'] (mismos nombres que AdminPermission)
   ```
3. **Rol `staff` en `AppUser`.** Hoy todo rol distinto de `exportador` se convierte en `importador` (`supabase_auth_repository.dart` y `app_user.dart`). Agregar el caso `staff`.
4. **Datos del panel ya disponibles en Supabase:** `blocked_users`, `user_reports`, `suspicious_activities`, `platform_config`, `rpc('admin_dashboard_stats')` (JSON con los campos de `DashboardStats`) y `rpc('set_tester', ...)`.
5. **Crear empleados desde la app** requiere una Edge Function (crear usuarios de Auth necesita la clave `service_role`, que nunca va en la app). Queda pendiente en backend; por ahora el primer admin se crea a mano (ver `supabase/README.md`).

---

## Otros detalles detectados

- `offer_card.dart`: `offer.sellerName.substring(0, 1)` falla si el nombre llega vacío. Usar `sellerName.isNotEmpty ? sellerName[0] : '?'`.
- `market_screen.dart`: los precios del ticker (Arabica ICE, Cacao, USD/EUR) están fijos en el código. Pueden leerse de la tabla `platform_config` (lectura permitida a todos los usuarios autenticados).

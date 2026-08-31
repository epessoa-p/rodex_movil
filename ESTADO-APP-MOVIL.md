# Estado de la app móvil — Rodex (rodex_movil)

App Flutter para el **personal** de negocios de moto (tiendas de repuestos y talleres).
Consume la API de `rodex_web` (Laravel/Sanctum). Online, solo login, Android primero.
Enfoque: **POS + Taller** en el teléfono.

> Leyenda: ✅ hecho · 🟡 parcial · ⬜ falta

_Última actualización: 2026-08-25_

---

## Base / arquitectura ✅

- ✅ Stack: `dio`, `flutter_riverpod`, `go_router`, `flutter_secure_storage`, `intl`, `mobile_scanner`, `share_plus`.
- ✅ Cliente API con token (`Authorization: Bearer`) + header **`X-Company-Id`** (multi-empresa).
- ✅ Manejo de errores JSON (401 → logout, 402/403 → mensaje de plan/permiso, 409 → elegir empresa).
- ✅ Almacenamiento seguro del token + empresa (`flutter_secure_storage`).
- ✅ Ciclo de sesión: bootstrap (token guardado), login, **selección de empresa**, logout.
- ✅ **Moneda por empresa** (símbolo desde `/me`, aplicado al formateo).
- ✅ Tema con colores de la empresa (`theme_primary`/`theme_accent`) — white-label.
- ✅ `MeContext`: permisos + features del plan (`can()`, `planAllows()`) — para mostrar/ocultar.

---

## Módulos / pantallas

### Autenticación ✅
- ✅ Login (email o usuario + contraseña).
- ✅ Selección de empresa (si el usuario tiene varias).
- ✅ **Ajustes / Perfil**: datos del usuario, **cambiar de empresa**, **cerrar sesión** (con
  confirmación) y versión de la app. Accesible desde el ícono de ajustes en el inicio.

### Inicio (Home) ✅ / 🟡
- ✅ Accesos: Nueva venta, Productos, Clientes, Taller, Caja.
- ✅ **Navigation Drawer** (botón hamburguesa): menú lateral con todos los accesos (Ventas, Productos, Clientes, Taller, Caja, Recepción, Proveedores, Cajas admin, Ajustes, Cerrar sesión), gateados por permiso/plan.
- ✅ Estado de caja (abierta/cerrada).
- ✅ Ocultar accesos según permisos/plan (`me.can()/planAllows()`).
- ✅ **Resumen del día** (ventas/monto de hoy) en el inicio. Endpoint `GET /sales/summary`; respeta "solo las mías" salvo `sales.view-all-records`.

### POS / Ventas 🟡
- ✅ Carrito (agregar, +/− cantidad, vaciar, total). El acceso **"Nueva venta"** ya no está en el drawer: es un **botón dentro del listado de Ventas** (y el tile del Inicio).
- ✅ Agregar producto por **búsqueda** (nombre/código).
- ✅ Agregar por **escáner de código de barras** (mobile_scanner, escaneo continuo + linterna).
- ✅ Cliente opcional (elegir / alta rápida).
- ✅ Cobro **contado** → crea la venta → **recibo**.
- ⬜ **Venta a crédito / cuotas** (hoy solo contado).
- ✅ **Descuento por producto** (por línea): botón/etiqueta en cada ítem del carrito → monto de descuento (acotado al bruto de la línea); se muestra en el ítem, en el resumen ("Desc. productos") y en el **recibo**. Se envía como `items[].discount` (el backend ya lo soportaba).
- ✅ **Descuento general** de la venta (campo antes de cobrar, aparte del de producto; el total resta ambos).
- ✅ **Historial de ventas** (lista paginada con búsqueda + scroll infinito; abre el recibo). Endpoint `GET /sales`. Respeta "solo las mías" salvo permiso `sales.view-all-records`.
- ✅ **Compartir recibo** de venta como **PDF** (ticket 80 mm con empresa, código, fecha, cliente, ítems/descuentos y totales) vía `pdf` + `printing`; opción alterna de **texto** (WhatsApp, etc.). Disponible en el recibo tras cobrar y desde el historial de ventas.
- ⬜ Ver **stock/precio** del producto al escanear/seleccionar.

### Caja ✅ / 🟡
- ✅ Ver sesión actual, **abrir** (elegir caja + monto) y **cerrar** (monto contado).
- ✅ Ver **movimientos** de la sesión (ingresos/gastos) y registrar **gasto** simple (operativo/servicio/transporte) desde caja. Endpoints `GET /cash/movements`, `POST /cash/expense`.
- ✅ **Resumen de cierre**: esperado vs contado con **diferencia en vivo** al cerrar; el resumen (inicial, ingresos, gastos, esperado) se ve en la pantalla.
- ✅ **Crear caja y asignarla a un personal** (Ajustes → Administración → Cajas): listar/crear/editar cajas con sucursal + personal asignado. Requisito para que ese personal pueda abrir caja. Endpoints `GET/POST /cash-registers`, `GET /cash-registers/form-data`, `PUT /cash-registers/{id}`. Gateado por `plan:cash` + `cash-registers.view/create/edit`.
- ⬜ Gastos con integración (pago a proveedor/CxP, pago a personal) — se manejan en el web.

### Clientes ✅
- ✅ Listar/buscar clientes.
- ✅ Alta rápida (nombre, documento, teléfono).
- ⬜ Editar cliente / ver detalle (historial de compras).

### Inventario / Productos 🟡
- ✅ Listar/buscar productos (lectura) para el POS — `GET /products` (nombre/código/barcode).
- ✅ **Ficha del producto**: precio, stock total, **stock por almacén**, categoría, marca, **origen** y **modelos** compatibles. Se abre al **seleccionar** un producto en la lista; en el POS trae botón "Agregar al carrito". Endpoint `GET /products/{id}`.
- ⬜ Ver la ficha también al **escanear** (hoy el escáner agrega directo, por velocidad).
- ✅ **Ajuste rápido de stock** desde la ficha (**entrada / salida / fijar** en un almacén, con motivo). Gateado por permiso `products.edit`. Endpoint `POST /products/{id}/stock-adjust`.
- ⬜ Alertas de **stock bajo**.
- ✅ **Alta rápida de producto** (nombre, precio, costo, código de barras, unidad, categoría/marca opcionales y **stock inicial** en un almacén). SKU autogenerado por empresa. Desde **Productos → "Nuevo"** (gateado por `products.create`); si se abre desde el POS, el producto creado se agrega al carrito. Endpoints `POST /products`, `GET /product-form-data`.
- ⬜ Editar productos y gestión completa (kardex, almacenes, importar) → se hace en el **web**.

### Compras 🟡  (plan:purchases)
- ✅ **Recepción de mercadería**: lista de OC por recibir (enviadas/parciales) → recibir cantidades por línea en un almacén. Suma stock, avanza la OC y **genera la compra (cuenta por pagar)**. Endpoints `GET /purchase-orders`, `GET /purchase-orders/{id}`, `POST /purchase-orders/{id}/receive`. Gateado por `plan:purchases` + `goods-receipts.create`.
- ✅ **Proveedores**: directorio (listar/buscar) y **alta rápida** (nombre, NIT, contacto, teléfono, email). Endpoints `GET /suppliers`, `POST /suppliers`. Gateado por `plan:purchases` + `suppliers.view/create`.
- ✅ **Órdenes de compra**: crear una OC desde el móvil (proveedor + productos con cantidad y costo). Queda en estado *enviada* (lista para recibir). Desde Recepción → "Nueva OC". Endpoint `POST /purchase-orders`. Gateado por `purchase-orders.create`.
- ✅ **Compra directa** (contado, un paso): proveedor + almacén + productos → registra la **compra**, **suma stock** y **paga el gasto**. **Origen del pago elegible: Caja** (requiere caja abierta) **o una cuenta de Tesorería** (valida saldo; registra el movimiento y descuenta el saldo de la cuenta). El selector Caja/Tesorería aparece si el usuario tiene `treasury.view`. Tile en el Inicio + drawer. Endpoint `POST /purchases/direct` (`payment_source` = cash|treasury, `treasury_account_id`). Gateado por `purchases.create`.
- ⬜ **Cuentas por pagar**: ver saldos a proveedores y registrar un pago (más administrativo).

### Dashboard / Análisis ✅  (móvil)
- ✅ **Dashboard con tabs** (Ventas, Taller, Compras — según plan + permiso `*-dashboard.view`). Una sola vista con `TabBar`. Orden de los tabs configurable en **Mi empresa**.
- ✅ Cada tab: selector **Monto / Cantidad**, **KPI** (semana y mes vs. periodo anterior con variación %) y **gráficos de barras** de comparativa **semanal (últimas 8)** y **mensual (últimos 6)** con `fl_chart`.
- Endpoints `GET /dashboard/sales|workshop|purchases` (series {label, amount, count}), gateados por plan + `*-dashboard.view`. Drawer → *Dashboard*.
- La **web** ya tenía dashboards (Ventas/Taller/Compras) gateados por permiso y en el menú (sin cambios).

### Mi empresa ✅  (administrativo)
- ✅ **Módulo "Mi empresa"** (web + móvil): la empresa activa edita **teléfono, dirección, foto/logo** y la **vigencia del enlace de seguimiento** (días tras entregar; **0 = sin caducidad**, default 1). Gateado por `company-profile.view/edit`. Endpoints `GET /company-profile`, `POST /company-profile` (multipart logo). Web: Administración → *Mi empresa*. Móvil: drawer → *Mi empresa*.
- ✅ **Caducidad del enlace de seguimiento**: el link `/ot/{token}` deja de servir `tracking_link_days` días después de `delivered_at` (muestra "enlace expirado"). **DB:** columna `companies.tracking_link_days` (script `20260831c_company_profile.sql`).

### Mecánicos (administración) ✅  (plan:workshop)
- ✅ **Pantalla de Mecánicos** en el menú: listado (activos e inactivos) y **alta/edición con todos los campos** (nombre, especialidad, teléfono, **% de comisión**, activo). Gateado por `mechanics.view/create/edit`. Endpoints `GET /mechanics/all`, `POST /mechanics`, `PUT /mechanics/{id}`.
- ✅ **Mecánico en la recepción** (dropdown "Mecánico", opcional) — alimenta la comisión.

### Pago a mecánicos ✅  (plan:workshop) — módulo nuevo (web + móvil)
- ✅ **Liquidación por OT**: por mecánico se listan sus **OTs entregadas** con comisión (% × mano de obra). **Pendientes** (seleccionables) y **Pagos realizados** agrupados (cada pago se despliega mostrando sus OTs). Se sabe exactamente qué OT se pagó y cuál no.
- ✅ **Comprobante de pago en PDF**: cada pago tiene **Compartir comprobante** (empresa, mecánico, fecha, método/origen, OTs con comisión, total, notas y firma). Móvil: PDF nativo (`printing`). Web: página imprimible (`workshop.mechanic-payments.receipt`).
- ✅ **Pagar seleccionando OTs**: eliges las OTs pendientes (o todas); el **Total a pagar** es un **campo editable** prellenado con la Σ de comisiones (se puede ajustar). Esas OTs quedan **pagadas y vinculadas al pago** (comisión congelada) sin importar el monto exacto pagado. **Origen Caja o Tesorería** (caja requiere sesión abierta, tesorería valida saldo). Registra el gasto (`expense_payroll` caja / `payroll` tesorería).
- Permisos: `mechanic-payments.view` / `mechanic-payments.pay`. En el drawer. Endpoints `GET /mechanic-payments`, `GET /mechanic-payments/{id}` (detalle OTs), `POST /mechanic-payments` (`work_order_ids[]` + `bonus`). **También en la web** (Taller → *Pago a mecánicos* → detalle del mecánico). **DB:** scripts `20260831_mechanic_payments.sql` **y** `20260831b_mechanic_commission_by_ot.sql`.

### Finanzas — Tesorería ✅  (plan:purchases)
- ✅ **Cuentas** (efectivo/banco): listar con saldo + **saldo total**; crear cuenta (nombre, tipo, banco/N° cuenta, **saldo de apertura** opcional). Tile en el Inicio + drawer. Endpoints `GET/POST /treasury/accounts`. Gateado por `treasury.view` (ver) / `treasury.manage` (crear).
- ✅ **Ingresos/gastos** por cuenta: detalle con saldo, botones **Ingreso** (aporte de capital / ajuste +) y **Gasto** (gasto / ajuste −), e historial de movimientos. Valida que el gasto no supere el saldo. Endpoints `GET /treasury/accounts/{id}`, `POST /treasury/accounts/{id}/movements`. Gateado por `treasury.manage`.

### Taller (Órdenes de trabajo) ✅ / 🟡
- ✅ Listar órdenes (incluye **entregadas**; oculta solo las anuladas).
- ✅ **Recepción** de vehículo (crea la OT) con los campos del web: cliente, **mecánico** (opcional), vehículo (existente o nuevo con marca/modelo/placa/**año/color**), **kilometraje**, **combustible**, **falla reportada**, **objetos/accesorios recibidos** y **notas**. (El `mechanic_id` es la base de la comisión.) Asigna la **sucursal** del personal (para el descuento de stock en la entrega). Se muestran en el detalle de la OT.
- ✅ Detalle de la OT: agregar/quitar **servicios** y **repuestos**, cambiar **estado**, **entregar**, y **diagnóstico** editable (estados recibida/diagnosticada/en_proceso/terminada; recibida→diagnosticada al guardar). Endpoint `POST /work-orders/{id}/diagnosis`.
- ✅ **Cobro/pago** de la OT al **contado** (entrega + cobro + descuento de stock, endpoint `deliver`). ⬜ Falta cobro a **crédito/cuotas** desde el móvil.
- ✅ **Compartir recibo de la OT en PDF** (ticket 80 mm: empresa, código, fecha, cliente/vehículo/mecánico, diagnóstico, servicios, repuestos, subtotales, descuento, total/pagado/saldo y estado de pago). En el menú **Compartir** del detalle, junto al enlace de seguimiento. Usa `pdf` + `printing`.
- ✅ **Asignar/cambiar mecánico desde el detalle** de la OT (botón en el encabezado → elige mecánico o "Sin asignar"). Endpoint `POST /work-orders/{id}/mechanic`. Solo si la OT no está entregada/anulada.
- ✅ **Contactar al cliente desde la OT**: botones **WhatsApp** y **Llamar** en el encabezado (junto a "Cliente"). El detalle ahora incluye `client_phone`. Si no hay teléfono, avisa.
- ✅ **Fotos de la OT**: en el detalle, galería de fotos con **agregar** (cámara o galería, varias a la vez), **ver** a pantalla completa, **eliminar** y **comentar cada foto** (ej. "cambiar esta pieza gastada"): el comentario se ve bajo la miniatura y se edita al tocarlo o desde el visor. También en la web (galería de la OT + lightbox). Endpoint `PUT /work-orders/{id}/photos/{photo}`. **DB:** columna `work_order_photos.caption` (script `20260831e_work_order_photo_caption.sql`). Usa la tabla existente `work_order_photos` (misma que la recepción web). Endpoints `GET/POST /work-orders/{id}/photos`, `DELETE /work-orders/{id}/photos/{photo}`. Se muestran también las fotos cargadas desde la recepción del web.
- ✅ **Enlace de seguimiento para el cliente**: botón "Compartir seguimiento" en el detalle de la OT → genera/entrega una URL pública (`/ot/{token}`, token único) y la comparte (`share_plus`). El cliente abre el enlace **sin login** y ve una **página web de seguimiento** (estado con línea de avance, vehículo, fechas, mecánico, falla, diagnóstico, detalle y total). Endpoint `GET /work-orders/{id}/share`. **DB:** script `20260829_work_order_public_token.sql` (columna `public_token`).

### Agenda / Citas ✅  (plan:workshop) — módulo nuevo (web + móvil)
- ✅ **Vistas Día / Semana / Mes** (conmutador). **Día**: tira de semana + línea de tiempo + resumen (total/programadas/confirmadas/completadas). **Semana**: 7 columnas (lun-dom) con las citas de cada día. **Mes**: calendario con conteo por día; al tocar un día abre su vista. Endpoint de rango `GET /appointments/range?from=&to=`.
- ✅ **Agendar cita**: cliente **registrado** (con su vehículo) o **rápido** (nombre+teléfono), servicio, mecánico, fecha/hora, duración (30 min–4 h), motivo y notas.
- ✅ **Editar/reprogramar**, **cambiar estado** (programada/confirmada/completada/cancelada/no asistió) y **eliminar**.
- ✅ **Contactar al cliente** desde la cita: **WhatsApp** (abre `wa.me` con mensaje de confirmación prellenado) y **Llamar** (`tel:`). Si no hay teléfono, avisa. (`url_launcher`).
- ✅ **Convertir a OT**: crea la Orden de Trabajo desde la cita (requiere cliente registrado + vehículo); marca la cita como completada y enlaza la OT. Gateado por `workshop.create`.
- Permisos: `appointments.view/create/edit/delete` (feature de plan: `workshop`). Tile en el Inicio + drawer.
- **En la web**: nueva sección *Taller → Agenda* con vista de día bonita (tira de semana, línea de tiempo, modal de alta/edición, acciones y convertir a OT).
- **DB**: tabla `appointments` → script `rodex_web/database/sql/20260829_agenda_v1.sql` (incluye permisos y asignación a roles admin/gerente).

---

## Otros módulos de la web aún NO en el móvil

Existen en la web pero todavía no tienen pantallas en el móvil. Se evalúan según la necesidad del piso:

- ⬜ **Motos / concesionaria** (`motos`): venta de motos, unidades, entregas, garantías.
- ⬜ **Alquileres** (`rentals`): contratos, calendario, entregas/devoluciones, cobros.
- ⬜ **Fidelización** (`loyalty`): puntos y canje (el **canje en el POS** sí es evaluable para móvil).
- ⬜ **Estadísticas** (`statistics`): dashboards (el móvil ya tiene el "resumen del día").
- ⬜ **Créditos / Cuentas por cobrar** (`sales`): cobro de cuotas de clientes (ligado a "venta a crédito").
- ⬜ **Administración**: usuarios, personal, sucursales, roles, cargos, planes, suscripciones → escritorio.
- ⬜ **Catálogos**: categorías, marcas, unidades, orígenes, marcas/modelos de moto, servicios de gasto → escritorio (algunos vía alta rápida en el flujo).

---

## Endpoints de la API ya disponibles (rodex_web `routes/api.php`)

- **Auth:** `POST /login`, `POST /logout`, `GET /me`.
- **POS / Ventas (plan:sales):** `GET /products`, `GET /products/{id}` (ficha), `GET/POST /clients`,
  `POST /sales`, `GET /sales` (historial), `GET /sales/summary` (resumen del día), `GET /sales/{id}`.
- **Caja — operación (plan:sales + cash.operate):** `GET /cash/current-session`, `GET /cash/registers`,
  `POST /cash/open`, `POST /cash/close`, `GET /cash/movements`, `POST /cash/expense`.
- **Caja — gestión (plan:cash):** `GET/POST /cash-registers`, `GET /cash-registers/form-data`,
  `PUT /cash-registers/{id}` (crear/asignar cajas a personal).
- **Inventario (plan:inventory):** `POST /products/{id}/stock-adjust` (ajuste de stock, `products.edit`), `POST /products` + `GET /product-form-data` (alta rápida, `products.create`).
- **Compras (plan:purchases):** `GET/POST /suppliers`, `GET/POST /purchase-orders`, `GET /purchase-orders/{id}`, `POST /purchase-orders/{id}/receive` (recepción → stock + CxP), `POST /purchases/direct` (compra directa → stock + gasto de caja).
- **Tesorería (plan:purchases):** `GET/POST /treasury/accounts`, `GET /treasury/accounts/{id}`, `POST /treasury/accounts/{id}/movements` (ingreso/gasto).
- **Taller (plan:workshop):** `GET /mechanics`, `GET /vehicles`, `GET /work-orders`, `GET /work-orders/summary` (resumen del día para el inicio),
  `GET /work-orders/{id}`, `POST /work-orders`, servicios/repuestos (add/remove),
  `POST /work-orders/{id}/diagnosis`, `POST /work-orders/{id}/status`, `POST /work-orders/{id}/deliver`,
  `GET/POST /work-orders/{id}/photos`, `DELETE /work-orders/{id}/photos/{photo}` (fotos de la OT),
  `GET /work-orders/{id}/share` (enlace público de seguimiento). Vista pública sin auth: `GET /ot/{token}`.
- **Agenda / Citas (plan:workshop):** `GET /appointments` (día, `?date=`), `GET /appointments/range` (semana/mes, `?from=&to=`), `GET /appointments/meta` (servicios+mecánicos), `POST /appointments`, `PUT /appointments/{id}`, `POST /appointments/{id}/status`, `POST /appointments/{id}/convert` (→ OT), `DELETE /appointments/{id}`.

> Para lo que aún falta (venta a crédito, descuento por línea, reimprimir recibo, ficha de producto
> con stock/origen/modelos, cobro de OT a crédito, y los módulos ⬜ del mapa de cobertura) habrá que
> **agregar endpoints** en la API además de las pantallas.

---

## Pendientes técnicos / calidad

- ⬜ Probar el **escáner en Android físico** (cámara real; el emulador no sirve).
- 🟡 Branding: **nombre "Rodex"** ✅ y **applicationId `net.sczsoft.rodex`** ✅. Íconos/splash: config lista (`flutter_launcher_icons`/`flutter_native_splash`), **falta el logo** en `assets/branding/icon.png` y correr los generadores.
- ⬜ Manejo de **sin conexión** (hoy es online; el plan lo dejó fuera por ahora).
- ✅ Pantalla de **ajustes/perfil** (empresa activa, cambiar empresa, cerrar sesión, versión).
- ⬜ Tests de widget (login, carrito) y `flutter analyze` en CI.
- 🟡 Build de release firmado: **config de firma lista** (`build.gradle.kts` lee `android/key.properties`, con fallback a debug; plantilla en `key.properties.example`). **Falta** crear el keystore y el `key.properties` con las contraseñas, y correr `flutter build apk --release`.

---

## Sugerencia de próximos pasos (orden por valor)

Enfoque: **primera entrega** con flujo completo sin web (el setup empresa/almacén/sucursal/cargos
queda en web con super_admin; la **creación de cajas + asignación a personal** ya está en el móvil).

1. **Empaque**: ícono/splash/nombre + **APK de release firmado** (keystore) — necesario para entregar.
2. Compartir recibo de **OT** (taller) y/o versión **PDF** imprimible.
3. Venta a **crédito/cuotas** (POS) y cobro de OT a crédito.
4. Descuento **por línea** · ficha de producto también al **escanear** · probar escáner en físico.
5. Editar producto desde el móvil (hoy solo alta + ajuste de stock).

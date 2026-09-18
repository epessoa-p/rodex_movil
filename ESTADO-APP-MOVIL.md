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
- ✅ **Mayúsculas automáticas** en los campos de texto (nombres, descripciones, direcciones, notas…) como en la web: `lib/core/upper_case.dart` (`UpperCaseTextFormatter` + `upperCaseFormatters`) aplicado en todos los formularios; no aplica a email/usuario/contraseña, buscadores, teléfonos ni números.

---

## Módulos / pantallas

### Autenticación ✅
- ✅ Login (email o usuario + contraseña).
- ✅ Selección de empresa (si el usuario tiene varias).
- ✅ **Perfil** (avatar con la inicial, arriba a la derecha del inicio → `/profile`): datos del
  usuario (nombre, email, **teléfono**), **cambiar de empresa**, **cambiar contraseña**,
  **cerrar sesión** (con confirmación) y versión de la app.
- ✅ **Cambiar contraseña** desde la app: `POST /change-password` (`current_password`, `password`,
  `password_confirmation`; mín. 8 caracteres). Va en el grupo `auth:sanctum` **fuera** del tenant
  (es acción de cuenta, no de empresa) y **revoca las demás sesiones** del usuario. Sin SQL.
- ✅ **Caducidad de sesión** (2026-09-17): el token del móvil vence a los **30 días** (absoluto, `SANCTUM_EXPIRATION`) y a los **7 días sin usar la app** (ventana deslizante en `expires_at`, renovada en cada petición por el middleware `EnsureTokenFresh`); un **usuario desactivado** queda fuera en su siguiente petición (401 `user_inactive`). La app cierra sesión sola ante cualquier 401 (`ApiClient.onUnauthorized`), vuelve al login con el motivo en un toast ("Sesión cerrada") y, al volver del segundo plano tras >30 min, re-valida `/me` en silencio. Quien la usa a diario solo ve el login una vez al mes.

### Inicio (Home) ✅ / 🟡
- ✅ Accesos: Nueva venta, Productos, Clientes, Taller, Caja.
- ✅ **Navigation Drawer** (botón hamburguesa): menú lateral con los accesos (Dashboard, Ventas, Productos, Clientes, **Taller**, Pagos, Compras, Tesorería, Reportes, Ajustes, Cerrar sesión), gateados por permiso/plan.
- ✅ **Hub "Taller"** (`/workshop`, 2026-09-16): **OTs · Agenda · Mecánicos** en tabs inferiores (mismo patrón que Compras/Pagos: `NavigationBar` + `IndexedStack`, cada tab gateado por `workshop.view` / `appointments.view` / `mechanics.view`; un solo tab → sin barra). Las rutas `/agenda` y `/mechanics` abren el hub en su tab. Las pantallas se reutilizan en modo `embedded` (sin AppBar propio; la Agenda lleva Día/Semana/Mes + "Hoy" arriba del cuerpo). "Mecánicos" salió del drawer; el tile del Inicio pasa a llamarse **"Órdenes de trabajo"** (Taller engloba todo).
- ✅ El botón de **Perfil** (arriba a la derecha) usa un ícono de persona en vez de la inicial.
- ✅ **Ajustes** (drawer → *Ajustes*, `/settings`): hub con **recuadros** — *Mi empresa* y *Cajas* —
  cada uno abre su pantalla. Preparado para crecer. Se quitaron del drawer **"Caja"** (ya está la
  tarjeta de caja en el inicio), **"Cajas (admin)"** y **"Mi empresa"** (ahora viven en Ajustes).
- ✅ Estado de caja (abierta/cerrada).
- ✅ Ocultar accesos según permisos/plan (`me.can()/planAllows()`).
- ✅ **Resumen del día** (ventas/monto de hoy) en el inicio. Endpoint `GET /sales/summary`; respeta "solo las mías" salvo `sales.view-all-records`.
- ✅ **Ventas hoy + OTs hoy + Citas hoy en la misma fila** (tarjetas compactas `_MiniStat`, 2026-09-15): Ventas (monto · N ventas, tap → Ventas), OTs (recibidas · activas, tap → Taller) y **Citas** (total · pendientes, tap → Agenda; reutiliza `agendaDayProvider(hoy)`, sin endpoint nuevo). Gate de Citas: plan `workshop` + `appointments.view`; las que apliquen se reparten el ancho por igual (el monto se encoge con `FittedBox` si no cabe). Pull-to-refresh recarga las tres.

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
- ✅ **Una caja por sucursal POR PERSONAL** (2026-09-16; reemplaza a "una por sucursal"): un personal puede tener varias cajas, pero en sucursales distintas. Al elegir el personal, el formulario solo ofrece las sucursales donde aún no tiene caja. Validado en backend (422 `personal_already_has_register_in_branch`). `GET /cash-registers/form-data` devuelve `taken[]` (pares sucursal+personal ocupados). **Una caja con sesiones o movimientos ya no se edita** (candado en la lista, aviso al tocarla; backend 422 `register_has_records`).
- ✅ **Sucursales** (Ajustes → *Sucursales*): listar y editar **solo nombre, dirección y teléfono** (el alta/baja y el resto de campos quedan en la web). Endpoints `GET /branches`, `PUT /branches/{id}`. Gateado por `branches.view` / `branches.edit`.
- ✅ **Crear caja y asignarla a un personal** (Ajustes → *Cajas*): listar/crear/editar cajas con sucursal + personal asignado. Requisito para que ese personal pueda abrir caja. Endpoints `GET/POST /cash-registers`, `GET /cash-registers/form-data`, `PUT /cash-registers/{id}`. Gateado por `plan:cash` + `cash-registers.view/create/edit`.
- ✅ Gastos con integración (pago a proveedor/CxP, pago a personal, servicios recurrentes) → ver **Pagos**.

### Clientes ✅
- ✅ Listar/buscar clientes.
- ✅ Alta rápida (nombre, documento, teléfono).
- ✅ **Ficha del cliente** (2026-09-17, tocar en el listado): datos de contacto con **Llamar / WhatsApp** y **tabs de actividad** como en la web — Ventas, OTs (abre el detalle), Vehículos, Citas, Alquileres — cada tab solo si el plan/permiso lo habilita (`null` en la API). Endpoint `GET /clients/{id}` (máx. 50 filas por tab). Barra de tabs desplazable (a 360 dp no caben repartidos).
- ✅ **Editar cliente** (lápiz en la ficha, `clients.edit`): nombre, documento, teléfono (obligatorio), email, dirección, notas, activo. Endpoint `PUT /clients/{id}`.

### Inventario / Productos 🟡
- ✅ Listar/buscar productos (lectura) para el POS — `GET /products` (nombre/código/barcode).
- ✅ **Ficha del producto**: precio, stock total, **stock por almacén**, categoría, marca, **origen** y **modelos** compatibles. Se abre al **seleccionar** un producto en la lista; en el POS trae botón "Agregar al carrito". Endpoint `GET /products/{id}`.
- ⬜ Ver la ficha también al **escanear** (hoy el escáner agrega directo, por velocidad).
- ✅ **Ajuste rápido de stock** desde la ficha (**entrada / salida / fijar** en un almacén, con motivo). Gateado por permiso `products.edit`. Endpoint `POST /products/{id}/stock-adjust`.
- ⬜ Alertas de **stock bajo**.
- ✅ **Alta rápida de producto** (nombre, precio, costo, código de barras, unidad, categoría/marca opcionales y **stock inicial** en un almacén). SKU autogenerado por empresa. Desde **Productos → "Nuevo"** (gateado por `products.create`); si se abre desde el POS, el producto creado se agrega al carrito. Endpoints `POST /products`, `GET /product-form-data`.
- ✅ **Editar producto** (2026-09-17, lápiz en la ficha, `products.edit`): nombre, precio, costo, código de barras, unidad, categoría, marca, stock mínimo, descripción y activo. El stock sigue yendo por "Ajustar stock" (kardex). Endpoint `PUT /products/{id}`; `GET /products/{id}` trae ahora `category_id`, `brand_id`, `cost`, `min_stock`, `description`, `active`.
- ⬜ Gestión completa (kardex, almacenes, importar, fotos adicionales) → se hace en el **web**.

### Compras 🟡  (plan:purchases)
- ✅ **Compras**: una pantalla con **tres tabs inferiores** — **Compras** (directas), **OCs** y **Proveedores** — cada uno gateado por su permiso (`purchases.view` / `purchase-orders.view` o `goods-receipts.view` / `suppliers.view`); si solo queda un tab visible se muestra sin barra. Cada tab tiene su botón de acción arriba (**Compra directa** / **Nueva OC** / **Nuevo proveedor**).
  - **Tab OCs**: lista **todas** las órdenes (enviada / parcial / recibida / anulada) con chip de estado, y filtro **Todas | Pendientes**. Tocar una pendiente → recibir; tocar una **recibida o anulada** → detalle en **solo lectura** (banner de estado, sin formulario ni botón). Endpoint `GET /purchase-orders?scope=all` (sin `scope` sigue devolviendo solo las por recibir, compatible con APKs viejas); las filas traen `status_label`.
  - **Tab Compras**: **todas** las compras — directas **y las generadas al recibir una OC** (distintivo azul "De OC OC-xxxxx"; nacen como cuenta por pagar). Filtro **Todas | Por pagar | Pagadas** arriba; FAB **+ Compra directa** abajo. Las no pagadas muestran su saldo. Tocar → detalle con ítems, totales, **saldo pendiente** e **historial de pagos** (`GET /purchases`, `GET /purchases/{id}`).
  - ✅ **Pagar una compra desde la app** (parcial o total): botón **"Registrar pago"** en el detalle (permiso `accounts-payable.pay`) → monto (por defecto el saldo, botón "Todo"), origen **Caja** (caja abierta, valida saldo) o **Tesorería** (cuenta, valida saldo; visible con `treasury.view`), referencia opcional. Endpoint `POST /purchases/{id}/pay` — misma lógica que Cuentas por Pagar de la web: `SupplierPayment` + `CashMovement`/`TreasuryMovement`, `recalcPaymentStatus()`. Devuelve el detalle actualizado; la lista recarga al volver. Sin SQL.
  - **Tab Proveedores**: directorio (listar/buscar) y **alta rápida** (nombre, NIT, contacto, teléfono, email). `GET /suppliers`, `POST /suppliers` (`suppliers.create`). **Ya no está en el drawer** como entrada aparte.
- ✅ **Órdenes de compra**: crear una OC desde el móvil (proveedor + productos con cantidad y costo). Queda en estado *enviada* (lista para recibir). Desde Recepción → "Nueva OC". Endpoint `POST /purchase-orders`. Gateado por `purchase-orders.create`.
- ✅ **Compra directa** (contado, un paso): proveedor + almacén + productos → registra la **compra**, **suma stock** y **paga el gasto**. **Origen del pago elegible: Caja** (requiere caja abierta) **o una cuenta de Tesorería** (valida saldo; registra el movimiento y descuenta el saldo de la cuenta). El selector Caja/Tesorería aparece si el usuario tiene `treasury.view`. Tile en el Inicio + drawer. Endpoint `POST /purchases/direct` (`payment_source` = cash|treasury, `treasury_account_id`). Gateado por `purchases.create`.
- ⬜ **Cuentas por pagar**: ver saldos a proveedores y registrar un pago (más administrativo).

### Dashboard operativo ✅  (móvil, drawer → *Dashboard*)
- ✅ Vista **operativa del día, de toda la empresa** (a diferencia de los resúmenes "míos" de Home): KPIs **Ventas hoy**, **OTs hoy** (+ activas), **Motos en taller** (vehículos con OT sin entregar), **Citas hoy** (+ pendientes), **Repuestos en stock** (+ alerta de stock bajo); **OTs por estado**; **Próxima cita**; **Ventas por servicio** (ranking top 5 del mes, con barras); **OTs recientes** (tap → detalle). Pull-to-refresh.
- Endpoint único `GET /dashboard/overview` (ruta fuera de los grupos de plan, `api.permission` OR de los tres `*-dashboard.view`); cada sección (`sales` / `workshop` / `stock`) viene en `null` si el plan no tiene el módulo o el usuario no tiene ese permiso, y el móvil no pinta la tarjeta. Las OTs recientes usan las mismas claves que `WorkOrderController::summary()` (`WorkOrder.fromJson`).

### Reportes ✅  (móvil, drawer → *Reportes*)
- ✅ **Hub de recuadros** (mismo patrón que Ajustes) con **Análisis** y **Estado de resultados**. Se muestra si el usuario tiene algún `*-dashboard.view` (con su plan) o `income-statement.view`. *Estado de resultados* **ya no** cuelga suelto del drawer.
- ✅ **Análisis** (`/reports/analytics`, antes era "Dashboard"): tabs Ventas/Taller/Compras según plan + `*-dashboard.view`, orden configurable en **Mi empresa**; selector **Monto / Cantidad**, **KPI** (semana y mes vs. periodo anterior) y **gráficos de barras** semanal (8) y mensual (6) con `fl_chart`. Endpoints `GET /dashboard/sales|workshop|purchases` (sin cambios).
- ✅ **Análisis → tab "Top"** (siempre el último tab; aparece si hay algún dashboard habilitado): selector de período (**Este mes / Mes ant. / 3 meses / Año**) + toggle **Monto / Cantidad**; **Ingresos por origen** en **donut** (`PieChart`) con leyenda y **%** — el *versus* Ventas vs. Taller (vs. Alquileres si el plan/permiso lo permite); rankings **Top repuestos** (POS + repuestos de OTs), **Top servicios**, **Top compras** y **Top clientes** (ventas + OTs), con barra proporcional y el valor secundario en pequeño (`RankingCard`, compartido con el dashboard operativo). Endpoint `GET /dashboard/top?period=month|last_month|quarter|year&by=amount|qty` (misma gate que `overview`; `by` decide el orden y el corte top 8 en el servidor; secciones sin plan/permiso vienen `null` y no se pintan).
- La **web** ya tenía dashboards (Ventas/Taller/Compras) gateados por permiso y en el menú (sin cambios).

### Mi empresa ✅  (administrativo)
- ✅ **Módulo "Mi empresa"** (web + móvil): la empresa activa edita **teléfono, dirección, foto/logo** y la **vigencia del enlace de seguimiento** (días tras entregar; **0 = sin caducidad**, default 1). Gateado por `company-profile.view/edit`. Endpoints `GET /company-profile`, `POST /company-profile` (multipart logo). Web: Administración → *Mi empresa*. Móvil: **Ajustes → *Mi empresa***.
- ✅ **Caducidad del enlace de seguimiento**: el link `/ot/{token}` deja de servir `tracking_link_days` días después de `delivered_at` (muestra "enlace expirado"). **DB:** columna `companies.tracking_link_days` (script `20260831c_company_profile.sql`).

### Estado de resultados (P&L) ✅  (administrativo — Reportes)
- ✅ **Estado de resultados por movimientos** (web + móvil): ingresos y egresos reales de **caja + tesorería** (base efectivo, agrupados por categoría, sin doble conteo) en un período seleccionable; **Resultado = Ingresos − Egresos** (verde si ≥0, rojo si <0). Móvil: **Reportes → *Estado de resultados***, presets **Este mes / Mes anterior / Todo / Rango** ("Todo" = desde el **primer movimiento** registrado hasta hoy; la cabecera muestra "Desde dd/mm/yyyy — hoy" con la fecha real que devuelve el backend y la tarjeta dice "Resultado acumulado"). Web: sección **Reportes** del menú. Gateado por `income-statement.view`. Endpoint `GET /income-statement?from=&to=` o `?all=1`. **DB:** permiso `income-statement.view` (módulo `reports`) — script `20260903_income_statement_permission.sql`.

### Mecánicos (administración) ✅  (plan:workshop)
- ✅ **Pantalla de Mecánicos** en el menú: listado (activos e inactivos) y **alta/edición con todos los campos** (nombre, especialidad, teléfono, **% de comisión**, activo). Gateado por `mechanics.view/create/edit`. Endpoints `GET /mechanics/all`, `POST /mechanics`, `PUT /mechanics/{id}`.
- ✅ **Mecánico en la recepción** (dropdown "Mecánico", opcional) — alimenta la comisión.

### Pagos ✅  (móvil, drawer → *Pagos*)
Una pantalla con **cuatro tabs inferiores**, cada uno gateado por su permiso (<2 visibles → sin barra). Reemplaza a la entrada suelta "Pago a mecánicos". Todo registra **igual que la web** (misma categoría, descripción y referencia), así cae idéntico en Caja, Tesorería y el Estado de resultados. **Sin SQL.**
- **Mecánicos** (`mechanic-payments.view` + plan workshop): la vista de liquidación por OT de abajo, sin cambios.
- **Proveedores** (`accounts-payable.view` + plan purchases): **cuentas por pagar agrupadas por proveedor** — total por pagar, N facturas, la más antigua hace N días (rojo si >30), subtotal por proveedor, cada factura con saldo y antigüedad. Tocar → detalle de la compra, que ya permite **pagar parcial o total**. Endpoint `GET /purchases?unpaid=1` (solo con saldo, sin límite, más antigua primero, `days_old`).
- **Personal** (`cash.operate`): personal activo con cargo y **último pago** (monto, período, fecha). Tocar → hoja: monto (sugiere el último), **período como selección** igual que la web — Día / Semana / Quincena / Mes / Otro (preselecciona el del último pago; "Otro" pide el concepto, p. ej. Bono) — Caja/Tesorería, notas. Header "Pagado al personal este mes". Registra `expense_payroll` / `payroll` con referencia a `Personal`.
- **Gastos** (`cash.operate` o `expense-services.view`): **servicios recurrentes** del catálogo `expense_services` (luz, agua, internet…) con **estado del mes** — ✓ "Pagado 05/09 · Bs 350" / ⚠ "Sin pagar este mes" — y pago en un toque con el **monto habitual precargado** y período; header "Gastos del mes"; FAB **+ Otro gasto** (operativo/transporte, concepto libre); **Nuevo servicio** (`expense-services.manage`); **Últimos gastos** (caja + tesorería). Endpoints `GET /expenses/overview`, `POST /expenses` (`kind` service|other|transport|payroll, `payment_source` cash|treasury), `POST /expense-services`.
- Widget compartido `PaymentSourceField` (Caja/Tesorería + cuenta) para las hojas nuevas.

### Pago a mecánicos ✅  (plan:workshop) — módulo nuevo (web + móvil) — ahora es el tab *Mecánicos* de Pagos
- ✅ **Liquidación por OT**: por mecánico se listan sus **OTs entregadas** con comisión (% × mano de obra). **Pendientes** (seleccionables) y **Pagos realizados** agrupados (cada pago se despliega mostrando sus OTs). Se sabe exactamente qué OT se pagó y cuál no.
- ✅ **Comprobante de pago en PDF**: cada pago tiene **Compartir comprobante** (empresa, mecánico, fecha, método/origen, OTs con comisión, total, notas y firma). Móvil: PDF nativo (`printing`). Web: página imprimible (`workshop.mechanic-payments.receipt`).
- ✅ **Pagar seleccionando OTs**: eliges las OTs pendientes (o todas); el **Total a pagar** es un **campo editable** prellenado con la Σ de comisiones (se puede ajustar). Esas OTs quedan **pagadas y vinculadas al pago** (comisión congelada) sin importar el monto exacto pagado. **Origen Caja o Tesorería** (caja requiere sesión abierta, tesorería valida saldo). Registra el gasto (`expense_payroll` caja / `payroll` tesorería).
- Permisos: `mechanic-payments.view` / `mechanic-payments.pay`. En el drawer. Endpoints `GET /mechanic-payments`, `GET /mechanic-payments/{id}` (detalle OTs), `POST /mechanic-payments` (`work_order_ids[]` + `bonus`). **También en la web** (Taller → *Pago a mecánicos* → detalle del mecánico). **DB:** scripts `20260831_mechanic_payments.sql` **y** `20260831b_mechanic_commission_by_ot.sql`.

### Finanzas — Tesorería ✅  (plan:purchases)
- ✅ **Cuentas** (efectivo/banco): listar con saldo + **saldo total**; crear cuenta (nombre, tipo, banco/N° cuenta, **saldo de apertura** opcional). Tile en el Inicio + drawer. Endpoints `GET/POST /treasury/accounts`. Gateado por `treasury.view` (ver) / `treasury.manage` (crear).
- ✅ **Ingresos/gastos** por cuenta: detalle con saldo, botones **Ingreso** (aporte de capital / ajuste +) y **Gasto** (gasto / ajuste −), e historial de movimientos. Valida que el gasto no supere el saldo. Endpoints `GET /treasury/accounts/{id}`, `POST /treasury/accounts/{id}/movements`. Gateado por `treasury.manage`.

### Taller (Órdenes de trabajo) ✅ / 🟡
- ✅ **Agregar servicio en la OT desde el catálogo** (2026-09-16): hoja grande (como la de Nueva cita) con buscador sobre el catálogo (`appointments/meta` trae `price`), precarga el precio al elegir y avisa cuando lo escrito se creará como servicio nuevo; precio y cantidad abajo. Los botones **Agregar** de Servicios y Repuestos van en la cabecera de su tarjeta, y cada línea tiene **×** para quitarla (con confirmación; endpoints `DELETE work-orders/{id}/services/{line}` y `/parts/{line}` ya existentes). Antes el diálogo era texto libre (creaba duplicados) y no se podía quitar nada.
- ✅ **Recuadros del detalle de OT con color distintivo** (2026-09-16): franja izquierda de 4 px + ícono teñido por sección (`_AccentCard`): Detalle = color del estado de la OT, Fotos índigo, Diagnóstico azul, Servicios morado (Taller), Repuestos marrón, Totales verde. Así se identifica cada recuadro al deslizar aunque esté vacío.
- ✅ Listar órdenes (incluye **entregadas**; oculta solo las anuladas).
- ✅ **Recepción** de vehículo (crea la OT) con los campos del web: cliente, **mecánico** (opcional), vehículo (existente o nuevo con marca/modelo/placa/**año/color**), **kilometraje**, **combustible**, **falla reportada**, **objetos/accesorios recibidos** y **notas**. (El `mechanic_id` es la base de la comisión.) Asigna la **sucursal** del personal (para el descuento de stock en la entrega). Se muestran en el detalle de la OT.
- ✅ Detalle de la OT: agregar/quitar **servicios** y **repuestos**, cambiar **estado**, **entregar**, y **diagnóstico** editable (estados recibida/diagnosticada/en_proceso/terminada; recibida→diagnosticada al guardar). Endpoint `POST /work-orders/{id}/diagnosis`.
- ✅ **Cobro/pago** de la OT al **contado** (entrega + cobro + descuento de stock, endpoint `deliver`). ⬜ Falta cobro a **crédito/cuotas** desde el móvil.
- ✅ **Compartir recibo de la OT en PDF** (ticket 80 mm: empresa, código, fecha, cliente/vehículo/mecánico, diagnóstico, servicios, repuestos, subtotales, descuento, total/pagado/saldo y estado de pago). En el menú **Compartir** del detalle, junto al enlace de seguimiento. Usa `pdf` + `printing`.
- ✅ **Asignar/cambiar mecánico desde el detalle** de la OT (botón en el encabezado → elige mecánico o "Sin asignar"). Endpoint `POST /work-orders/{id}/mechanic`. Solo si la OT no está entregada/anulada.
- ✅ **Hub Inventario + paginación + catálogos** (2026-09-18): el menú "Productos" pasa a **Inventario** (`/products` → `InventoryHubScreen`) con tabs Productos · Categorías · Marcas · Modelos · Orígenes (cada uno gateado por `*.view`). Los tabs se construyen **al abrirlos por primera vez** (IndexedStack con placeholders): entrar solo carga productos. **Productos paginado**: `GET /products?page=&per_page=30` devuelve `data` + `meta`; la lista carga la siguiente página al llegar al final ("30 de 512 productos"), búsqueda con espera de 450 ms (`PosRepository.productsPage`, `ProductPage`). **Catálogos**: API `GET/POST /catalogs/{categories|brands|origins|moto-brands|moto-models}` y `PUT /catalogs/{type}/{id}` (`Api\CatalogController`, permisos `<módulo>.view/create/edit`; el alta también con `products.create|edit`; reutiliza/reactiva si el nombre ya existe, 422 `catalog_name_taken` al editar con nombre duplicado). Móvil: `features/inventory/` (`catalogs_repository.dart`, `catalog_screen.dart` genérico con buscador/alta/edición/activo; modelos con marca de moto, cilindrada, año y precio sugerido, y alta rápida de marca de moto). **Categoría/Marca en el producto** (alta y edición): `CatalogPickerField` abre una hoja con buscador; si lo escrito no existe ofrece **"Crear «X»"** y lo deja seleccionado. Tests `inventory_hub_test.dart` (tabs perezosos, paginación, crear desde el selector).
- ✅ **Logo de la empresa en el menú lateral** (2026-09-18): el círculo del encabezado del drawer muestra el logo (`CompanyLogoAvatar`, misma medida 48 px, imagen adaptada con `contain` sobre fondo blanco; usa la caché de `loadCompanyLogo`); si no hay logo, la inicial del usuario.
- ✅ **"Cuánto hay en caja" al pagar** (2026-09-18): en todas las hojas de pago desde caja (mecánicos, personal, gastos/servicios, proveedores) aparece un recuadro con la caja abierta y su **disponible** (apertura + ingresos − egresos), en rojo si el monto escrito lo supera o si no hay caja abierta (`payments/widgets/cash_available_hint.dart`, sigue el campo de monto en vivo; se refresca al abrir la hoja).
- ✅ **Estado de resultados: Esta semana / Semana anterior** (2026-09-18): presets en chips desplazables (Esta semana · Semana ant. · Este mes · Mes ant. · Todo · Rango); semana de lunes a domingo. La web tiene los mismos presets (`presetRange('this_week'|'last_week')`).
- ✅ **Tab Servicios en Taller** (2026-09-18): el hub queda OTs · Agenda · **Servicios** · Mecánicos. Listado del catálogo con buscador (activos primero, inactivos en gris), alta y edición (nombre, precio, tiempo estimado, descripción, activo). Endpoints `GET /services` (`services.view|create|edit`) y `PUT /services/{id}` (`services.edit`, 422 `service_name_taken` si el nombre ya existe). Al guardar invalida el catálogo de citas/OT. Gateado por `services.view`. Archivos `services_repository.dart`, `services_screen.dart`; test `services_tab_test.dart`.
- ✅ **PDF tamaño carta** (2026-09-17): además del ticket 80 mm, el recibo de venta y la OT se pueden compartir en **carta** (`lib/core/pdf_letter.dart` con `LetterDoc`: cabecera con logo + nombre/dirección/teléfono de la empresa, título y código, barra con el **color primario de la empresa**, tarjetas de información, tablas con cabecera de color y filas alternadas, caja de totales, notas, firmas y pie con numeración). Builders `features/pos/receipt_letter_pdf.dart` y `features/workshop/work_order_letter_pdf.dart`. En el recibo de venta el menú muestra "PDF ticket (80 mm)" y "PDF tamaño carta"; en la OT, al elegir compartir recibo (WhatsApp u otra app) pregunta el formato en una hoja. `/me` ahora incluye `phone` y `address` de la empresa (backend). Test en `pdf_logo_test.dart` (genera muestras en `build/pdf_samples/`).
- ✅ **Logo de la empresa en los PDF** (2026-09-17): recibo de venta, recibo de OT y comprobante de pago a mecánico llevan el logo (`company.logo_url` de `/me`; si la empresa no subió logo, el de Rodex, como en la web) centrado sobre el nombre. `lib/core/company_logo.dart`: se descarga **una sola vez**, se reduce a 300 px (PNG, con el decodificador de Flutter) y se guarda en la caché de la app; después funciona sin red y el PDF crece solo ~20–60 KB. Se precarga al iniciar sesión; si falla, el PDF sale sin logo. Test `pdf_logo_test.dart`.
- ✅ **Recibo y seguimiento directo al WhatsApp del cliente** (2026-09-17): el menú **Compartir** de la OT ofrece primero **"Recibo (PDF) al WhatsApp del cliente"** y **"Seguimiento al WhatsApp del cliente"** (van directo al chat del número de la OT, sin elegir contacto) y debajo las opciones "con otra app" (selector del sistema). El enlace usa `wa.me` con el mensaje escrito; el PDF usa un intent nativo a WhatsApp/WhatsApp Business (`MainActivity.kt`, canal `rodex/whatsapp`, extra `jid`, FileProvider de `share_plus`) y si WhatsApp no está instalado cae al compartir genérico. Helper compartido `lib/core/whatsapp.dart` (`WhatsApp.number/openChat/sendFile`). Opciones deshabilitadas si el cliente no tiene teléfono.
- ✅ **Contactar al cliente desde la OT**: botones **WhatsApp** y **Llamar** en el encabezado (junto a "Cliente"). El detalle ahora incluye `client_phone`. Si no hay teléfono, avisa.
- ✅ **Fotos de la OT**: en el detalle, galería de fotos con **agregar** (cámara o galería, varias a la vez), **ver** a pantalla completa, **eliminar** y **comentar cada foto** (ej. "cambiar esta pieza gastada"): el comentario se ve bajo la miniatura y se edita al tocarlo o desde el visor. También en la web (galería de la OT + lightbox). Endpoint `PUT /work-orders/{id}/photos/{photo}`. **DB:** columna `work_order_photos.caption` (script `20260831e_work_order_photo_caption.sql`). Usa la tabla existente `work_order_photos` (misma que la recepción web). Endpoints `GET/POST /work-orders/{id}/photos`, `DELETE /work-orders/{id}/photos/{photo}`. Se muestran también las fotos cargadas desde la recepción del web.
- ✅ **Enlace de seguimiento para el cliente**: botón "Compartir seguimiento" en el detalle de la OT → genera/entrega una URL pública (`/ot/{token}`, token único) y la comparte (`share_plus`). El cliente abre el enlace **sin login** y ve una **página web de seguimiento** (estado con línea de avance, vehículo, fechas, mecánico, falla, diagnóstico, detalle y total). Endpoint `GET /work-orders/{id}/share`. **DB:** script `20260829_work_order_public_token.sql` (columna `public_token`).

### Agenda / Citas ✅  (plan:workshop) — módulo nuevo (web + móvil)
- ✅ **Vistas Día / Semana / Mes** (conmutador). **Día**: tira de semana (con **numerito de citas por día**, en **rojo** si ese día tiene alguna cita pasada sin completar — 2026-09-16) + línea de tiempo + resumen (total/programadas/confirmadas/completadas). **Semana**: 7 columnas (lun-dom) con las citas de cada día. **Mes**: calendario con conteo por día; al tocar un día abre su vista. Endpoint de rango `GET /appointments/range?from=&to=`.
- ✅ **Agendar cita**: cliente **registrado** (con su vehículo) o **rápido** (nombre+teléfono), servicio, mecánico, fecha/hora, duración (30 min–4 h), motivo y notas.
- ✅ **Varios servicios por cita** (2026-09-15): tarjeta "Servicios" con chips y hoja con buscador y checkboxes; **crear un servicio desde ahí** (botón "Nuevo servicio" o "Crear «lo buscado»" cuando no hay resultados; nombre + precio; gateado por `services.create`; endpoint `POST /services`, que reutiliza uno existente con el mismo nombre en vez de duplicar) y queda marcado; el motivo se autocompleta con los nombres. Se envía `service_ids[]` (el backend conserva `service_id` = primero). **DB:** tabla pivote `appointment_services` → script `20260915_appointment_services.sql` (con backfill).
- ✅ **Al convertir a OT se copian los servicios** como líneas (`work_order_services`, precio del catálogo, cantidad 1, mecánico de la OT) — tanto en "Crear OT" directo como en la recepción con `appointment_id`.
- ✅ **Cliente rápido con nombre + teléfono → se registra como cliente** (el backend lo busca por teléfono o lo crea y deja la cita con `client_id`). Solo nombre → sigue como walk-in.
- ✅ **Nuevo cliente desde la cita**: nombre **y teléfono obligatorios** (también en la API `POST /clients`); validación y confirmación con `AppToast` arriba (antes el SnackBar quedaba detrás del diálogo).
- ✅ **Estándar de avisos**: todos los `SnackBar` de la app pasaron a `AppToast` (éxito verde / error rojo / info azul, arriba, visibles sobre hojas y diálogos), incl. "OT creada desde la cita".
- ✅ **Editar/reprogramar**, **cambiar estado** (programada/confirmada/completada/cancelada/no asistió) y **eliminar**. **Una cita completada (o ya convertida en OT) no se edita ni reprograma** (2026-09-16): la hoja de acciones muestra "Cita completada: ya no se edita" y el backend rechaza el update (422 `appointment_closed`, también en la web).
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
- ✅ Pantalla de **Perfil** (usuario, teléfono, empresa activa, cambiar empresa, cambiar contraseña, cerrar sesión, versión) y **Ajustes** como hub de recuadros.
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

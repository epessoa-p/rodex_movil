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
- ✅ Carrito (agregar, +/− cantidad, vaciar, total).
- ✅ Agregar producto por **búsqueda** (nombre/código).
- ✅ Agregar por **escáner de código de barras** (mobile_scanner, escaneo continuo + linterna).
- ✅ Cliente opcional (elegir / alta rápida).
- ✅ Cobro **contado** → crea la venta → **recibo**.
- ⬜ **Venta a crédito / cuotas** (hoy solo contado).
- ✅ **Descuento global** en la UI del POS (campo antes de cobrar; el total refleja el descuento). ⬜ Descuento por línea.
- ✅ **Historial de ventas** (lista paginada con búsqueda + scroll infinito; abre el recibo). Endpoint `GET /sales`. Respeta "solo las mías" salvo permiso `sales.view-all-records`.
- ✅ **Compartir recibo** de venta (texto formateado con empresa, código, fecha, cliente, ítems y totales) por WhatsApp / cualquier app (`share_plus`). Disponible en el recibo tras cobrar y desde el historial de ventas. ⬜ Compartir recibo de **OT** / versión PDF.
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
- ✅ **Compra directa** (contado, un paso): proveedor + almacén + productos → registra la **compra**, **suma stock** y **paga desde caja** (gasto). Requiere caja abierta. Tile en el Inicio + drawer. Endpoint `POST /purchases/direct`. Gateado por `purchases.create`.
- ⬜ **Cuentas por pagar**: ver saldos a proveedores y registrar un pago (más administrativo).

### Taller (Órdenes de trabajo) ✅ / 🟡
- ✅ Listar órdenes (incluye **entregadas**; oculta solo las anuladas).
- ✅ **Recepción** de vehículo (crea la OT) con los campos del web: cliente, vehículo (existente o nuevo con marca/modelo/placa/**año/color**), **kilometraje**, **combustible**, **falla reportada**, **objetos/accesorios recibidos** y **notas**. Asigna la **sucursal** del personal (para el descuento de stock en la entrega). Se muestran en el detalle de la OT.
- ✅ Detalle de la OT: agregar/quitar **servicios** y **repuestos**, cambiar **estado**, **entregar**, y **diagnóstico** editable (estados recibida/diagnosticada/en_proceso/terminada; recibida→diagnosticada al guardar). Endpoint `POST /work-orders/{id}/diagnosis`.
- ✅ **Cobro/pago** de la OT al **contado** (entrega + cobro + descuento de stock, endpoint `deliver`). ⬜ Falta cobro a **crédito/cuotas** desde el móvil.
- ⬜ Asignar mecánico desde el detalle (existe alta rápida en web).
- ⬜ Fotos de recepción (subir desde el teléfono).

---

## Otros módulos de la web aún NO en el móvil

Existen en la web pero todavía no tienen pantallas en el móvil. Se evalúan según la necesidad del piso:

- ⬜ **Finanzas — Tesorería** (`purchases`): cuentas bancarias, transferencias. Administrativo → escritorio. (La **Caja** es la parte financiera que sí está en el móvil.)
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
- **Compras (plan:purchases):** `GET/POST /suppliers`, `GET/POST /purchase-orders`, `GET /purchase-orders/{id}`, `POST /purchase-orders/{id}/receive` (recepción → stock + CxP).
- **Taller (plan:workshop):** `GET /mechanics`, `GET /vehicles`, `GET /work-orders`,
  `GET /work-orders/{id}`, `POST /work-orders`, servicios/repuestos (add/remove),
  `POST /work-orders/{id}/diagnosis`, `POST /work-orders/{id}/status`, `POST /work-orders/{id}/deliver`.

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

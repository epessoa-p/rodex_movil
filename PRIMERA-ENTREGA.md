# Checklist — Primera entrega (Rodex móvil)

Objetivo: la app instalada en el/los celulares del negocio, conectada a
**producción** (`https://rodex.sczsoft.net`), con el flujo diario funcionando.

---

## 0. Desplegar el backend a PRODUCCIÓN (lo más importante)

La app de release apunta a `https://rodex.sczsoft.net/api`. **Todos** los
endpoints que agregamos deben estar vivos ahí. Si producción no los tiene, las
funciones nuevas darán error.

- [ ] Subir el código de `rodex_web` a producción (todo lo de esta etapa).
- [ ] Correr en la BD de producción los scripts SQL (si no se hizo):
  - `database/sql/20260826_warehouses_code_unique_per_company.sql`
  - `database/sql/20260826_branches_code_unique_per_company.sql`
- [ ] En el servidor: `php artisan config:clear && php artisan view:clear`
  (o `config:cache` + `view:cache`).
- [ ] Verificar: abrir `https://rodex.sczsoft.net` → el login debe mostrar la
  marca **Rodex** (logo + nombre) y cargar por HTTPS.

---

## 1. Datos de arranque (web, como super_admin)

- [ ] Empresa creada, con **suscripción/plan** y los módulos correctos.
- [ ] **Almacén** y **sucursal** creados.
- [ ] **Cargos** (roles) con los permisos que necesita el personal
  (ventas/POS, caja, taller, compras, inventario…).
- [ ] **Personal** con **acceso al sistema** (usuario), asignado a un cargo.
- [ ] Productos iniciales: cargar por **import** en la web, o crearlos luego
  desde el móvil (alta rápida).

---

## 2. Cajas (se puede hacer desde el móvil)

- [ ] Crear una **caja** y **asignarla a un personal**
  (móvil: Ajustes → Administración → Cajas). Sin esto, ese personal no puede
  abrir caja ni vender.

---

## 3. Empaquetar la app (APK firmado)

- [ ] Crear el keystore y `android/key.properties` — ver
  **GUIA-FIRMA-RELEASE.md**.
- [ ] `flutter build apk --release`
  → `build/app/outputs/flutter-apk/app-release.apk`
- [ ] Confirmar que `lib/core/config.dart` apunta a **producción** (así está).

---

## 4. Probar el flujo completo en un celular FÍSICO (contra producción)

Instala el APK y verifica de punta a punta:

- [ ] **Login** con un usuario real → selección de empresa (si aplica).
- [ ] **Abrir caja** (la caja asignada aparece).
- [ ] **POS**: agregar por búsqueda y por **escáner** (cámara real), descuento,
  cliente, **cobrar** → **compartir recibo** (WhatsApp).
- [ ] **Historial de ventas** y **resumen del día** en el inicio.
- [ ] **Taller**: recepción de vehículo → OT (servicios/repuestos) → entregar y
  cobrar.
- [ ] **Compras**: recepción de una OC, alta de proveedor.
- [ ] **Inventario**: crear producto, ajustar stock, ver ficha.
- [ ] **Caja**: registrar un gasto, ver movimientos, **cerrar caja** (diferencia).
- [ ] Cambiar de usuario/empresa y confirmar que NO se mezclan datos (caja).

---

## 5. Instalar / distribuir

- [ ] Pasar `app-release.apk` a los teléfonos del negocio.
- [ ] En cada teléfono, permitir **instalar apps de orígenes desconocidos**.
- [ ] Instalar y **entregar las credenciales** a cada usuario.
- [ ] Explicar lo básico: abrir caja al empezar el día, vender, cerrar caja al
  final.

---

## Pendientes que pueden esperar (post-entrega)

No bloquean la primera entrega; se agregan después según necesidad:

- Venta a **crédito/cuotas** y cobro de cuotas de clientes.
- Cobro de **OT a crédito**.
- **Descuento por línea** en el POS.
- **Recibo en PDF** / recibo de **OT** compartible.
- Fuente **TT Autonomous** real (hoy usa Chakra Petch como sustituto).
- **Modo sin conexión** (hoy es 100% online).
- **Ícono/nombre**: ya listos; falta solo el keystore para el release firmado.
- Publicación en **Play Store** (App Bundle firmado).
- Tests automatizados / CI.

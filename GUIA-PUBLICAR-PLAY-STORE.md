# Guía: publicar Rodex en Google Play

Complemento de `GUIA-FIRMA-RELEASE.md` (esa cubre el keystore y el APK firmado).
Esta cubre el camino completo hasta que la app esté en la tienda y cómo sacar
actualizaciones. Está escrita para este proyecto (rutas, nombres y valores reales).

> Estado del proyecto al escribir esto (2026-09-17): API apuntando a producción
> (`https://rodex.sczsoft.net/api`), `applicationId` `net.sczsoft.rodex`, ícono
> propio, nombre "Rodex", versión `1.1.0+2`, keystore `android/app/rodex-release.jks`
> con `android/key.properties` listos.

---

## 0. Antes de empezar (checklist)

- [ ] **Backend en producción actualizado.** La APK usa endpoints nuevos
      (`dashboard/top`, `POST /services`, `appointment_services`, cajas, pagos…).
      Sube `rodex_web` y corre los `.sql` pendientes; si no, el revisor de Google y
      tus clientes verán errores.
- [ ] **Respaldo del keystore** (`rodex-release.jks`) y de `key.properties` fuera del
      proyecto (nube / USB). Sin ellos no se pueden subir actualizaciones.
- [ ] Una **empresa de prueba** en producción con datos ficticios y un usuario
      (email + contraseña) para dárselo al revisor de Google (lo pide sí o sí porque
      la app exige iniciar sesión).
- [ ] **Política de privacidad publicada** en una URL pública (ver plantilla al final;
      sugerido: `https://rodex.sczsoft.net/privacidad`).

---

## 1. Cuenta de desarrollador (una sola vez)

1. Entra a <https://play.google.com/console> con la cuenta de Google que será dueña
   de la app (mejor una cuenta del negocio, no personal).
2. Paga la inscripción: **US$ 25, único pago**.
3. Tipo de cuenta:
   - **Organización** (recomendado, a nombre de sczsoft): pide un **número D-U-N-S**
     (gratis, se solicita en <https://www.dnb.com/duns-number.html>, tarda días).
     Ventaja: puedes publicar en producción directo.
   - **Personal**: sin D-U-N-S, pero Google exige **una prueba cerrada con 12 testers
     durante 14 días** antes de poder publicar en producción.
4. Verificación de identidad (documento) y de contacto (teléfono/email): 1–3 días.

---

## 2. Generar el archivo para Play: AAB (no APK)

Google Play **no acepta APK**; pide un Android App Bundle (`.aab`).

```bat
cd d:\repository\rodex\rodex_movil
flutter build appbundle --release
```

Sale en `build\app\outputs\bundle\release\app-release.aab`, firmado con tu mismo
`rodex-release.jks` (Gradle usa `key.properties`; no hay que cambiar nada).

Al crear la app en la consola, acepta **Play App Signing** (viene marcado): Google
guarda una clave con la que firma lo que descargan los usuarios y tu `.jks` queda
como **clave de subida**. Es lo recomendado y te protege si algún día pierdes el `.jks`.

---

## 3. Crear la app en la consola

Play Console → **Crear app**:

| Campo | Valor |
|---|---|
| Nombre de la app | Rodex |
| Idioma predeterminado | Español (Latinoamérica) |
| App o juego | Aplicación |
| Gratis o de pago | **Gratis** (no se puede cambiar a pago después) |
| Declaraciones | aceptar políticas y leyes de exportación |

Después, el panel te muestra una lista de tareas ("Configura tu app"). Son estas:

### 3.1 Ficha de la tienda (Store listing)

Ten listo:

- **Nombre**: Rodex
- **Descripción breve** (máx. 80): `Gestión para tiendas de repuestos y talleres de motos.`
- **Descripción completa** (máx. 4000): ver texto sugerido más abajo.
- **Ícono**: PNG 512×512 (usa el mismo del proyecto en alta resolución:
  `assets/icon/` o el original con el que corriste `flutter_launcher_icons`).
- **Gráfico de portada**: PNG/JPG **1024×500** (obligatorio). Puede ser el logo sobre el
  color de la marca con el texto "Rodex · Taller y repuestos".
- **Capturas de teléfono**: mínimo 2, recomendado 4–8 (Inicio, Órdenes de trabajo,
  Agenda, Ventas, Pagos). Mínimo 320 px, máximo 3840 px por lado, relación 16:9 o 9:16.
  Sácalas del celular con la versión release (sin la cinta DEBUG).
- **Categoría**: Aplicación → *Empresa* (Business).
- **Correo de contacto** y, opcional, sitio web.

### 3.2 Contenido de la app (cuestionarios obligatorios)

- **Política de privacidad**: la URL pública.
- **Acceso a la app**: marcar *"Toda la funcionalidad o parte de ella está restringida"*
  y agregar las **credenciales de prueba** (usuario/email y contraseña de la empresa
  demo) con una nota: *"Ingresar con estas credenciales; la app requiere cuenta
  creada por el administrador del negocio."*
- **Anuncios**: No contiene anuncios.
- **Clasificación de contenido**: cuestionario IARC → categoría *Utilidad,
  productividad…* → responder "No" a todo → sale "Todos".
- **Público objetivo**: 18 o más. No dirigida a niños.
- **App de noticias**: No. **App de salud**: No. **App gubernamental**: No.
- **Apps financieras**: No (la caja/ventas son gestión interna, no servicios financieros).
- **Seguridad de los datos** (Data safety): declarar:
  - Recoge: **Nombre, Email, Teléfono** (información personal, para la cuenta),
    **Fotos** (fotos de las órdenes de trabajo, funcionalidad de la app).
  - Los datos se **cifran en tránsito** (HTTPS): Sí.
  - El usuario puede **solicitar la eliminación** de sus datos: Sí (por correo).
  - Se comparten con terceros: **No**.
  - Requeridos vs opcionales: cuenta obligatoria; fotos opcionales.

### 3.3 Países y precio

Países: al menos **Bolivia**; puedes marcar todos los de Latinoamérica. Precio: gratis.

---

## 4. Publicar: primero pruebas internas, luego producción

1. **Pruebas internas** (menú *Lanzamiento → Pruebas → Pruebas internas*):
   - Crear versión → subir `app-release.aab` → notas de la versión → *Iniciar lanzamiento*.
   - Agregar una lista de testers (emails de Google, hasta 100). Google genera un
     **enlace de instalación**; ábrelo en el celular con esa cuenta y se instala desde
     Play en minutos, **sin revisión**. Sirve para comprobar que la versión de Play
     funciona igual que tu APK (en especial el login contra producción).
2. **Producción** (*Lanzamiento → Producción*): crear versión → subir el **mismo AAB**
   → notas de la versión (p. ej. "Primera versión pública") → revisar → *Iniciar
   lanzamiento en producción*.
   - La primera revisión tarda **de 1 a 7 días** (a veces más). Las siguientes suelen
     ser horas.
   - Si rechazan, el correo dice el motivo exacto (lo más común: falta la política de
     privacidad, credenciales de prueba que no funcionan, o Data safety incompleto).

---

## 5. Sacar una actualización (cada vez)

1. Subir la versión en `pubspec.yaml`: `version: 1.1.0+2` → `1.1.1+3`, `1.2.0+4`…
   - El número de la izquierda es el visible; **el `+N` debe ser siempre mayor** que el
     anterior (Google y Android lo usan para saber que es más nueva).
2. Poner el mismo número visible en `lib/core/config.dart` (`appVersion`), que es lo
   que muestra la pantalla de Perfil.
3. `flutter build appbundle --release`.
4. Play Console → Producción → Crear versión → subir el AAB → notas → lanzar.
5. Los usuarios reciben la actualización sola desde Play (o al abrir la tienda).

Consejo: usa **lanzamiento por etapas** (p. ej. 20 % → 100 %) cuando el cambio sea
grande, así detectas problemas antes de que llegue a todos.

---

## 6. Requisitos técnicos (ya cumplidos, por si Google los pide)

| Requisito | Estado |
|---|---|
| `targetSdk` ≥ 35 | 36 ✔ |
| Compatibilidad 64 bits | Flutter la incluye ✔ |
| Firma de release | `rodex-release.jks` ✔ |
| `applicationId` definitivo | `net.sczsoft.rodex` ✔ (no se puede cambiar después de publicar) |
| Permisos declarados | Internet, Cámara (para fotos de OT y escáner) ✔ |
| Política de privacidad | pendiente de publicar la URL |

---

## Anexo A — Descripción completa sugerida (pegar en la ficha)

```
Rodex es la app de gestión para tiendas de repuestos y talleres de motos.
Diseñada para el personal del negocio: vende, recibe motos, agenda citas y
controla la caja desde el celular, con los mismos datos que la versión web.

VENTAS Y CAJA
• Punto de venta con búsqueda y escáner de códigos.
• Apertura y cierre de caja, gastos y pagos a personal y proveedores.
• Recibos en PDF para compartir por WhatsApp.

TALLER
• Órdenes de trabajo: recepción, diagnóstico, servicios, repuestos, fotos y entrega.
• Agenda de citas por día, semana y mes; convierte la cita en orden de trabajo.
• Enlace de seguimiento para que el cliente vea el estado de su moto.

COMPRAS Y REPORTES
• Compras directas, órdenes de compra y cuentas por pagar.
• Dashboard del día, análisis por período y estado de resultados.

Rodex requiere una cuenta creada por el administrador del negocio. Si tu taller o
tienda aún no usa Rodex, escríbenos.
```

## Anexo B — Plantilla de política de privacidad (publicar en una URL pública)

```
POLÍTICA DE PRIVACIDAD — RODEX
Última actualización: <fecha>

Rodex es una aplicación de gestión para negocios de repuestos y talleres de
motos, operada por sczsoft (<correo de contacto>).

1. Datos que recopilamos
- Datos de la cuenta: nombre, correo electrónico y teléfono del usuario, creados
  por el administrador del negocio.
- Datos del negocio que el usuario registra al usar la app: clientes, vehículos,
  ventas, órdenes de trabajo, citas, compras y movimientos de caja.
- Fotos: solo las que el usuario toma o elige para adjuntar a una orden de trabajo.
  La app pide permiso de cámara únicamente para ese fin y para escanear códigos.

2. Uso de los datos
Los datos se usan exclusivamente para prestar el servicio de gestión al negocio
que los registra. No se venden ni se comparten con terceros, salvo obligación legal.

3. Almacenamiento y seguridad
Los datos se envían cifrados (HTTPS) y se almacenan en los servidores del servicio.
Cada negocio solo accede a su propia información.

4. Eliminación de datos
El usuario o el administrador del negocio puede solicitar la eliminación de su
cuenta y datos escribiendo a <correo de contacto>. Se atenderá en un plazo máximo
de 30 días.

5. Menores
La app no está dirigida a menores de 18 años.

6. Cambios
Publicaremos aquí cualquier cambio a esta política.

Contacto: <correo de contacto>
```

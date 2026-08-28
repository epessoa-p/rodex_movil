# Guía: firmar y generar el APK de release (Rodex móvil)

Guía paso a paso, en simple, de los puntos 1 y 2 del empaque. Léela con calma;
está pensada para hacerla **una sola vez**.

---

## ¿Qué es esto y por qué es necesario?

Android **no instala** una app si no está "firmada" digitalmente. La firma es
como la **cédula de identidad de tu app**: garantiza que todas las versiones
(la de hoy y las actualizaciones futuras) vienen del mismo autor (tú).

- En **desarrollo**, Flutter usa una firma "debug" automática (por eso
  `flutter run` funciona sin que hagas nada). Pero esa firma es genérica, la
  tiene todo el mundo, y **no sirve para distribuir** la app de verdad.
- Para **entregar/publicar**, necesitas tu **propia** firma: eso es el
  **keystore** (un archivo `.jks` protegido con contraseña).

### ⚠️ Lo más importante de todo
El **keystore y sus contraseñas son para siempre**. Si actualizas la app en el
futuro, DEBES firmarla con el **mismo** keystore. Si lo **pierdes** (o pierdes
la contraseña):
- No podrás publicar **actualizaciones** de la app (Android las rechaza por
  tener otra firma).
- Tendrías que publicar una app **nueva** (otro paquete) y los usuarios
  perderían la continuidad.

Por eso: **haz respaldo del `.jks` y guarda las contraseñas** en un lugar
seguro (gestor de contraseñas, USB, nube privada). No lo subas al repositorio
(ya está ignorado por git).

---

## ¿Qué es `key.properties`?

Es un archivo de texto que le dice a Gradle (el compilador de Android)
**dónde está tu keystore y cuáles son las contraseñas**, para que firme el APK
automáticamente al compilar. Así no se ponen las contraseñas dentro del código.

- El proyecto **ya está configurado** para leerlo:
  `android/app/build.gradle.kts` busca `android/key.properties`. Si existe,
  firma con tu keystore de release; si no existe, usa la firma debug (para no
  romper `flutter run --release`).
- Este archivo **no se sube** al repo (está en `.gitignore`), porque contiene
  contraseñas.

---

## Paso 1 — Crear el keystore (una sola vez)

Necesitas `keytool`, que viene con el **JDK de Java** (ya lo tienes instalado si
usas Android Studio / Flutter).

1. Abre una terminal en la carpeta `android/app` del proyecto móvil:
   ```
   cd d:\repository\rodex\rodex_movil\android\app
   ```

2. Ejecuta (esto crea el archivo `rodex-release.jks`):
   ```
   keytool -genkey -v -keystore rodex-release.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias rodex
   ```
   - Si `keytool` "no se reconoce", usa la ruta completa del JDK, por ejemplo:
     `"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"` (o busca
     `keytool.exe` en tu JDK) y ponla al inicio del comando.

3. Te va a preguntar, en orden:
   - **Contraseña del keystore** (invéntala y anótala) → la escribes dos veces.
   - Nombre, organización, ciudad, país, etc. (puedes poner tu nombre/negocio;
     no es crítico). Al final te pide confirmar con `si`/`yes`.
   - **Contraseña de la clave (key)**: puedes usar la **misma** que la del
     keystore (presiona Enter para reutilizarla) o poner otra.

4. Al terminar tendrás el archivo **`rodex-release.jks`** dentro de
   `android/app/`. **Respáldalo** y guarda las 2 contraseñas y el alias
   (`rodex`).

> El alias `rodex` es el "nombre" de la clave dentro del keystore. Debe
> coincidir con el que pongas en `key.properties`.

---

## Paso 2 — Crear `android/key.properties`

1. Copia la plantilla `android/key.properties.example` a `android/key.properties`
   (mismo directorio `android/`, **no** dentro de `android/app/`).

2. Ábrelo y completa con tus datos reales:
   ```
   storePassword=LA_CONTRASEÑA_DEL_KEYSTORE
   keyPassword=LA_CONTRASEÑA_DE_LA_CLAVE
   keyAlias=rodex
   storeFile=rodex-release.jks
   ```
   - `storeFile=rodex-release.jks` funciona porque el `.jks` quedó en
     `android/app/`. Si lo guardaste en otro lado, pon la **ruta completa**,
     por ejemplo `storeFile=C:/Users/Eric/llaves/rodex-release.jks` (usa `/`).

3. Guarda. Listo: ya no toques más este archivo.

---

## Paso 3 — Compilar el APK firmado

Desde la carpeta del proyecto móvil (`rodex_movil`):
```
flutter build apk --release
```
- El APK sale en:
  `build/app/outputs/flutter-apk/app-release.apk`
- Ese APK está **firmado con tu keystore** y apunta a **producción**
  (`https://rodex.sczsoft.net/api`). Es el que instalas en los celulares o
  compartes.

Para **Play Store** (más adelante) se usa un App Bundle:
```
flutter build appbundle --release
```
(sale en `build/app/outputs/bundle/release/app-release.aab`).

---

## Cómo saber que quedó bien firmado

Al compilar, si Gradle encontró tu `key.properties`, usa tu firma de release.
Si no lo encuentra, usa la debug (y verás la app igual, pero **no** sirve para
distribuir). Para confirmar la firma del APK generado:
```
keytool -printcert -jarfile build\app\outputs\flutter-apk\app-release.apk
```
Debe mostrar los datos que pusiste al crear el keystore (no "Android Debug").

---

## Resumen de checklist

- [ ] Crear `rodex-release.jks` con `keytool` (Paso 1) y **respaldarlo**.
- [ ] Anotar y guardar: contraseña del keystore, contraseña de la clave, alias.
- [ ] Crear `android/key.properties` desde el `.example` con esos datos (Paso 2).
- [ ] `flutter build apk --release` (Paso 3) → instalar el `app-release.apk`.

> Si algo no queda claro, avísame y lo revisamos juntos cuando lo hagas.

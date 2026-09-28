# Proyecto Senderos

Aplicación móvil desarrollada en Flutter para explorar, registrar, guardar y compartir rutas de senderismo. La app combina navegación GPS, mapas interactivos, autenticación con Supabase y gestión de comunidad para que el usuario pueda documentar recorridos y seguir rutas de otros usuarios.

## Descripción general

Proyecto Senderos es una app orientada a senderistas que permite:

- Explorar senderos publicados y buscar rutas por nombre o tipo.
- Guardar rutas como favoritas o en almacenamiento local.
- Registrar recorridos en tiempo real con GPS.
- Importar y previsualizar archivos GPX.
- Consultar información del sendero, clima y métricas de la ruta.
- Gestionar amigos y compartir ubicación.
- Mantener un perfil con logros y estadísticas de actividad.

## Stack tecnológico

- Flutter + Dart
- Supabase para autenticación, almacenamiento y datos de usuario
- Flutter Map para renderización de mapas
- Geolocator + Permission Handler para localización y permisos
- App Links para abrir archivos GPX externos
- File Picker y Image Picker para importar y adjuntar contenido
- Shared Preferences para persistencia local
- XML para lectura de archivos GPX

## Requisitos previos

Antes de ejecutar el proyecto necesitas:

- Flutter SDK 3.12.2 o superior
- Android Studio o VS Code con herramientas de Flutter
- Emulador Android o dispositivo físico
- Cuenta de Supabase activa

## Instalación

1. Clona el repositorio:

```bash
git clone <url-del-repositorio>
cd APP
```

2. Instala las dependencias:

```bash
flutter pub get
```

3. Configura Supabase en el archivo principal:

Abre `lib/main.dart` y revisa la inicialización de Supabase. Actualmente la app usa la URL y la clave pública directamente en código.

```dart
await Supabase.initialize(
  url: 'https://tu-proyecto.supabase.co',
  publishableKey: 'tu-clave-publica',
);
```

4. Ejecuta la aplicación:

```bash
flutter run
```

## Comandos útiles

```bash
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk --release
flutter build appbundle --release
```

## Estructura del proyecto

```text
APP/
├── android/                  # Configuración nativa Android
├── assets/                   # Recursos visuales del proyecto
├── lib/
│   ├── main.dart             # Punto de entrada de la aplicación
│   ├── models/               # Modelos de datos
│   ├── screen/               # Pantallas principales
│   ├── services/             # Servicios, Supabase, GPS, GPX, clima
│   ├── utils/                # Utilidades y cálculos
│   └── widgets/              # Componentes reutilizables
├── test/                     # Pruebas unitarias y de widgets
├── analysis_options.yaml     # Reglas de lintado
├── pubspec.yaml              # Dependencias y configuración Flutter
├── supabase_logros.sql        # Script SQL para logros/funcionalidades de Supabase
├── BACKGROUND_LOCATION_SETUP.md
├── README.md
└── ...
```

## Funcionalidades principales

### 1. Autenticación y perfil
La aplicación inicializa Supabase y gestiona la sesión del usuario desde la pantalla de login. El flujo principal se mueve por la autenticación, el perfil y la gestión de comunidad.

### 2. Exploración de senderos
La carpeta `lib/screen` incluye pantallas como `explorar.dart`, `detalle_sendero.dart` y `inicio.dart` para navegar por rutas, filtrar contenido y consultar información de cada recorrido.

### 3. Grabación de rutas
Las pantallas `grabar.dart` y `grabar_controller.dart` gestionan la grabación de rutas con permisos de ubicación, trazado del recorrido, métricas y guardado del archivo GPX.

### 4. Importación de GPX
El proyecto cuenta con servicios para parsear XML GPX, abrir rutas externas y mostrar una vista previa antes de integrarlas en la app.

### 5. Comunidad y ubicación
Se incluye soporte para amigos, ubicación compartida y visualización del estado de otras personas dentro de la red social del senderismo.

### 6. Logros y progreso
La app incluye un servicio de logros para medir progreso del usuario y exponer estadísticas dentro del perfil.

## Archivos clave

- `lib/main.dart`: inicializa la app y gestiona la apertura de archivos GPX externos.
- `lib/screen/inicio.dart`: pantalla principal con navegación.
- `lib/screen/explorar.dart`: listado y exploración de senderos.
- `lib/screen/grabar.dart`: interfaz de grabación del recorrido.
- `lib/screen/perfil.dart`: perfil del usuario y logros.
- `lib/services/servicio_autenticacion.dart`: autenticación con Supabase.
- `lib/services/gpx_import.dart`: importación y parseo de GPX.
- `lib/services/gpx_open_service.dart`: apertura de archivos GPX externos.
- `lib/services/achievement_service.dart`: lógica de logros.
- `supabase_logros.sql`: base de datos para logros y funcionalidades relacionadas.

## Nota importante

El proyecto está en una fase de desarrollo activa y la configuración de Supabase está actualmente integrada directamente en el código. Para producción y despliegue seguro, se recomienda mover las credenciales a variables de entorno o a un archivo de configuración no versionado.

## Estado del proyecto

La aplicación incluye funcionalidad de autenticación, mapas, grabación GPS, perfiles, GPX y comunidad, con una base sólida para seguir ampliando la experiencia de senderismo y la capa social de la app.

### `analysis_options.yaml`
Configura las reglas de lint para mantener el código limpio y consistente.

### `android/`, `ios/`, `windows/`, `web/`
Estos directorios contienen la parte nativa de la app para cada plataforma objetivo.

## Pruebas

La carpeta `test/` incluye pruebas para elementos importantes del proyecto, por ejemplo:

- `achievement_service_test.dart`
- `route_distance_calculator_test.dart`
- `widget_test.dart`

Estas pruebas sirven para validar servicios y widgets clave del comportamiento de la app.

## Cómo se estructura el flujo real de la app

```text
main.dart
  -> MyApp
    -> AuthGate
      -> LoginScreen (si no hay sesión)
      -> HomePage (si hay sesión)
        -> ExploreContent / SavedContent / AmigosContent / ProfilePage / GrabarPage
```

En resumen, la app tiene una arquitectura basada en:

- Pantallas con estado (`StatefulWidget`)
- Servicios dedicados (clima, GPX, autenticación, almacenamiento, ubicación)
- Modelos para representar senderos y rutas
- Widgets reutilizables para UI consistente

## Recomendaciones para seguir desarrollando

- Mantener la lógica de negocio en `lib/services` y la UI en `lib/screen`/`lib/widgets`.
- Usar modelos en `lib/models` para evitar lógica mezclada en pantallas.
- Añadir pruebas para cada servicio nuevo antes de publicar cambios complejos.
- Revisar siempre `pubspec.yaml` cuando se añadan dependencias.

## Resumen rápido

Si quieres entender la app en una frase:

> Es una aplicación de senderismo con mapas, autenticación, rutas GPS, comunidad, almacenamiento local y publicación de rutas en la nube.



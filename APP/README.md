# Proyecto Senderos

Aplicación móvil desarrollada con Flutter para explorar, guardar, registrar y compartir rutas de senderismo. La app permite ver senderos disponibles, autenticar usuarios, crear rutas desde GPS, importar archivos GPX, consultar clima y gestionar comunidad/seguimiento.

## ¿Qué hace esta app?

La aplicación está pensada como una plataforma tipo social y de registro para senderistas:

- Explorar senderos publicados por otros usuarios.
- Guardar senderos como favoritos y acceder a rutas locales.
- Registrar rutas en tiempo real con GPS.
- Añadir puntos de interés a una ruta.
- Importar y previsualizar archivos GPX.
- Compartir ubicación con amigos.
- Consultar información del clima para cada sendero.
- Gestionar login, perfil y comunidad.

## Tecnologías principales

- Flutter + Dart
- Supabase para autenticación y base de datos
- Flutter Map para renderizado de mapas
- Geolocator para ubicación GPS
- App Links para abrir archivos GPX externos
- File Picker / Image Picker
- Shared Preferences y almacenamiento local

## Estructura general del proyecto

```text
APP/
├── android/                 # Configuración nativa Android
├── assets/                  # Imágenes / recursos estáticos
├── lib/
│   ├── main.dart            # Inicio de la app, inicialización y apertura de GPX
│   ├── models/              # Modelos de datos
│   ├── screen/              # Pantallas principales de la app
│   ├── services/            # Lógica de negocio, supabase, GPX, clima, almacenamiento
│   ├── utils/              # Utilidades y cálculos
│   └── widgets/            # Componentes reutilizables
├── test/                    # Pruebas unitarias y de widgets
├── analysis_options.yaml    # Reglas de linting
├── pubspec.yaml             # Dependencias y configuración Flutter
├── README.md                # Documentación del proyecto
└── ...
```

## Flujo principal de funcionamiento

### 1. Inicio de la aplicación
El punto de entrada es `lib/main.dart`:

- Inicializa Flutter.
- Configura Supabase con la URL y la clave pública.
- Lanza la aplicación con `MyApp`.
- Crea `GpxOpenService` para detectar archivos GPX abiertos desde fuera de la app.
- Si llega un archivo GPX, muestra un diálogo para previsualizarlo.

### 2. Autenticación
La pantalla de login está en `lib/widgets/login.dart` y usa `ServicioAutenticacion` en `lib/services/servicio_autenticacion.dart`.

- Si hay sesión guardada, la app entra directamente.
- Si no, se muestra el login.
- Se pueden crear cuentas y sincronizar el perfil con Supabase.

### 3. Navegación principal
La pantalla inicial `lib/screen/inicio.dart` funciona como home con un `BottomNavigationBar`:

- Explorar senderos
- Guardados
- Grabar ruta
- Comunidad / amigos
- Perfil

### 4. Exploración de senderos
`lib/screen/explorar.dart`:

- Carga senderos desde Supabase.
- Filtra por nombre, dificultad y distancia.
- Permite marcar/desmarcar favoritos.
- Muestra cards con información del sendero.

### 5. Grabación de rutas
`lib/screen/grabar.dart` + `lib/screen/grabar_controller.dart`:

- Piden permisos de ubicación.
- Inician seguimiento GPS.
- Dibuja la ruta en un mapa.
- Mide tiempo, distancia, subida, pausa y parada.
- Guarda la ruta y, si procede, la publica.

### 6. Guardado y publicación
`lib/services/guardado_local.dart` y `lib/services/almacenamiento_r2.dart`:

- Guardan el archivo GPX y fotos en el almacenamiento local.
- Suben el contenido a R2 (Cloudflare) para compartirlo.
- Guardan metadata de la ruta.

### 7. Importación y previsualización GPX
`lib/services/gpx_import.dart` y `lib/services/gpx_open_service.dart`:

- Abren archivos `.gpx` desde el dispositivo o enlaces externos.
- Parsean el XML para leer puntos de la ruta.
- Generan una vista previa con el mapa y el nombre de la ruta.

## Descripción de archivos importantes

### Archivo principal

#### `lib/main.dart`
Inicializa la aplicación, configura Supabase y abre la app en la pantalla principal. También escucha archivos GPX externos para mostrar una vista previa antes de abrir la ruta dentro de la app.

### Modelos

#### `lib/models/explore_trail.dart`
Representa un sendero que se muestra en el listado de exploración. Incluye nombre, descripción, dificultad, distancia, foto, autor y URL del GPX.

#### `lib/models/saved_route.dart`
Modelo para rutas guardadas localmente, con datos como nombre, descripción, puntos, fotos y metadata de publicación.

#### `lib/models/clima_sendero.dart`
Define los modelos del clima para mostrar temperatura, condiciones, humedad y pronóstico diario.

#### `lib/models/detalles_sendero.dart`
Modelo para la estructura de detalle de rutas, útil para mostrar información ampliada de cada sendero.

### Pantallas

#### `lib/screen/inicio.dart`
Pantalla principal de la app. Contiene la barra de navegación, la cabecera de búsqueda y el contenido activo según la sección seleccionada.

#### `lib/screen/explorar.dart`
Lista los senderos disponibles, aplica filtros y permite añadirlos a favoritos.

#### `lib/screen/guardados.dart`
Muestra senderos guardados localmente o favoritos. Permite abrir, importar y gestionar rutas guardadas.

#### `lib/screen/grabar.dart`
Pantalla de grabación del recorrido. Gestiona el mapa, GPS, pausa, parada, ubicación compartida y métricas.

#### `lib/screen/grabar_controller.dart`
Lógica de control del proceso de grabación: permisos, rutas, puntos de interés, almacenamiento y confirmación de salida.

#### `lib/screen/detalle_sendero.dart`
Muestra la información completa de un sendero: foto, ruta en mapa, clima y posibilidad de seguir la ruta.

#### `lib/screen/seguir_sendero.dart`
Pantalla que guía al usuario durante la navegación de un sendero con métricas y seguimiento visual del recorrido.

#### `lib/screen/previsualizar_gpx.dart`
Presenta un archivo GPX antes de abrirlo completamente en la app, con mapa y puntos cargados desde el XML.

#### `lib/screen/amigos.dart`
Muestra la comunidad y la gestión de amigos. Permite buscar usuarios, añadir amigos y ver ubicaciones.

#### `lib/screen/ubicacion_amigo.dart`
Pantalla para visualizar en mapa la ubicación compartida por un amigo.

#### `lib/screen/perfil.dart`
Perfil del usuario, logros, fotos, estadísticas y acciones de cierre de sesión.

#### `lib/screen/configuracion.dart`
Pantalla de ajustes con navegación entre secciones de la aplicación.

#### `lib/screen/localizacion.dart`
Servicio o helper de localización, usado para resolver la posición del usuario y la gestión del GPS.

#### `lib/screen/notificaciones.dart`
Pantalla de notificaciones del usuario.

### Servicios

#### `lib/services/servicio_autenticacion.dart`
Centraliza el inicio de sesión, registro, cierre de sesión y sincronización del perfil con Supabase.

#### `lib/services/obtener_sendero.dart`
Consulta los senderos publicados en la tabla `senderos` y adapta los datos para mostrarlos en la app.

#### `lib/services/guardado_local.dart`
Guarda las rutas creadas por el usuario en almacenamiento local, junto con fotos y metadata del sendero.

#### `lib/services/almacenamiento_r2.dart`
Sube archivos GPX y fotos a un bucket de R2 para que puedan publicarse y descargarse por otros usuarios.

#### `lib/services/gpx_import.dart`
Lee archivos GPX guardados en el dispositivo, valida puntos y genera un modelo de ruta utilizable por la app.

#### `lib/services/gpx_open_service.dart`
Escucha enlaces externos o archivos GPX abiertos desde Android y los convierte para cargarlos en una vista previa dentro de la app.

#### `lib/services/compartir_ubicacion.dart`
Gestiona la funcionalidad de compartir ubicación con amigos a través de Supabase.

#### `lib/services/senderos_favoritos.dart`
Maneja favoritos de senderos. Añade, elimina y carga ids guardados por el usuario.

#### `lib/services/senderos_locales.dart`
Controla rutas locales y caché de senderos guardados en el dispositivo.

#### `lib/services/servicio_clima_sendero.dart`
Consulta el clima en función de la ubicación del sendero usando la API externa que la app tenga configurada.

#### `lib/services/achievement_service.dart`
Lógica de logros y progresos para el perfil del usuario.

#### `lib/services/offline_tile_service.dart`
Ayuda a manejar tiles del mapa offline para poder navegar sin conexión.

### Widgets reutilizables

#### `lib/widgets/login.dart`
Pantalla de login/registro con formulario y gestión del avatar de perfil.

#### `lib/widgets/barra_navegacion.dart`
Componente de navegación inferior reutilizable para todas las pantallas principales.

#### `lib/widgets/sendero_card.dart`
Tarjeta visual de un sendero con imagen, nombre, dificultad, distancia y botón de favorito.

#### `lib/widgets/filtros.dart`
Barra de filtros y búsqueda para explorar y ordenar senderos.

#### `lib/widgets/grabar_action_button.dart`
Botón reutilizable para iniciar, pausar o detener una grabación.

#### `lib/widgets/grabar_metric_indicator.dart`
Muestra datos de métricas como tiempo, distancia o elevación.

#### `lib/widgets/config_card.dart`
Tarjeta visual reutilizable para opciones de configuración.

#### `lib/widgets/clima_sendero_card.dart`
Widget para mostrar el clima del sendero en una tarjeta visual.

#### `lib/widgets/save_route_dialog.dart`
Diálogo para guardar una ruta o completar la metadata antes de publicarla.

#### `lib/widgets/search_field.dart`
Campo de búsqueda reutilizable para explorar, guardados y comunidad.

### Utilidades

#### `lib/utils/route_calculator.dart`
Calcula distancias y encuentra el punto más cercano sobre una ruta. Es útil para saber si el usuario está cerca de un tramo o para controlar seguimiento de recorrido.

## Archivos de configuración

### `pubspec.yaml`
Define todas las dependencias de Flutter y los assets. Aquí se declaran paquetes esenciales como `flutter_map`, `geolocator`, `supabase_flutter`, `image_picker`, `share_plus`, etc.

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



# Proyecto Senderos

## Visión general

Proyecto Senderos es una aplicación móvil desarrollada con Flutter para gestionar la experiencia completa del senderismo digital: descubrimiento de rutas, navegación GPS, grabación de recorridos, carga/importación de archivos GPX, visualización geoespacial, almacenamiento local, autenticación con Supabase y socialización con otros usuarios.

La base arquitectónica del proyecto sigue un patrón híbrido con:

- UI en `lib/screen` y `lib/widgets`
- lógica de negocio y accesos a datos en `lib/services`
- modelos de dominio en `lib/models`
- utilidades transversales en `lib/utils`
- configuración y entrada de la app en `lib/main.dart`

## Objetivo técnico

La app no es solo una pantalla de mapas: integra varias capas funcionales que interactúan entre sí:

- `Supabase` como backend principal para autenticación, perfiles y datos relacionales.
- `Flutter Map` para renderizar mapas interactivos.
- `Geolocator` para obtener ubicación del usuario en tiempo real.
- `GPX` como formato de intercambio de rutas y recorrido.
- `SharedPreferences` para persistencia local y configuración del dispositivo.
- `File Picker`, `Image Picker` y `Share Plus` para integración con sistema operativo y archivos.
- `App Links` para abrir rutas externas o archivos GPX desde fuera de la app.

## Stack principal

- Flutter SDK: `^3.12.2`
- Dart: `3.x`
- Flutter Map: `^6.0.0`
- Supabase Flutter: `^2.17.2`
- Geolocator: `13.0.2`
- Permission Handler: `^12.0.3`
- App Links: `^7.2.1`
- File Picker: `^13.1.0`
- Image Picker: `^1.2.3`
- Shared Preferences: `^2.5.3`
- XML: `^7.0.1`
- UUID: `^4.5.1`

## Instalación y configuración

### Prerrequisitos

- Flutter instalado y configurado en la máquina.
- Android Studio o VS Code con Flutter y Dart plugins.
- Emulador o dispositivo Android conectado.
- Proyecto Supabase operativo con URL y API key pública.
- Permisos de ubicación habilitados en Android.

### Instalar dependencias

```bash
flutter pub get
```

### Ejecutar la app

```bash
flutter run
```

### Validar el proyecto

```bash
flutter analyze
flutter test
```

### Compilar release

```bash
flutter build apk --release
flutter build appbundle --release
```

## Inicialización de la aplicación

El punto de entrada es `lib/main.dart`.

### Qué hace precisamente

- Ejecuta `WidgetsFlutterBinding.ensureInitialized()` para preparar el entorno Flutter antes de la UI.
- Llama a `Supabase.initialize()` con URL y clave pública.
- Crea una instancia de `MyApp`.
- Inicializa `GpxOpenService` para escuchar aperturas de archivos `.gpx` desde fuera de la aplicación.
- Presenta una previsualización cuando se recibe un archivo GPX externo.
- Configura `MaterialApp` con tema visual, `ScaffoldMessenger` y `navigatorKey` para navegación global.

### Flujo de arranque

```text
main() -> MyApp -> AuthGate -> Login / HomePage
                              \-> GpxOpenService escucha archivos externos
```

## Estructura del proyecto

```text
APP/
├── android/                     # Configuración nativa de Android
├── assets/                      # Recursos gráficos estáticos
├── build/                       # Salidas generadas por Flutter
├── lib/
│   ├── main.dart                # Entry point + bootstrap + inicialización de Supabase
│   ├── models/                  # Definiciones de entidades y DTOs del dominio
│   ├── screen/                 # Pantallas de la app (UI + orchestration)
│   ├── services/               # Servicios, APIs, accesos a datos y lógica de negocio
│   ├── utils/                  # Utilidades de cálculo y apoyo transversal
│   └── widgets/                # Componentes reutilizables de UI
├── test/                        # Pruebas unitarias y de widgets
├── web/                         # Configuración web de Flutter
├── windows/                     # Configuración nativa de Windows
├── analysis_options.yaml        # Reglas de linting
├── pubspec.yaml                 # Dependencias del proyecto
├── README.md                    # Documentación del proyecto
├── BACKGROUND_LOCATION_SETUP.md # Guía de permisos y ubicación en segundo plano
├── .gitignore
└── ...
```

## Descripción técnica de cada archivo y carpeta

### Archivos raíz

#### `pubspec.yaml`
Define el proyecto Flutter y todas las dependencias. Aquí se declaran paquetes principales como `flutter_map`, `supabase_flutter`, `geolocator`, `file_picker`, `permission_handler`, `image_picker`, `shared_preferences`, `xml`, `uuid` y `app_links`.

#### `analysis_options.yaml`
Configura Lints globales para imponer estilo, buenas prácticas y evitar errores comunes. Es la capa de calidad estática del proyecto.

#### `BACKGROUND_LOCATION_SETUP.md`
Documento de soporte para establecer permisos de ubicación en segundo plano y resolver problemas específicos de Android. Tiene valor operativo durante la integración con tracking GPS.

### `lib/main.dart`
Archivo central de bootstrap. Tiene responsabilidades de:

- inicializar Flutter y Supabase
- levantar la app con `MaterialApp`
- abrir el flujo de autenticación (`AuthGate`)
- iniciar `GpxOpenService` para detectar GPX externos
- manejar diálogos de confirmación y navegación global

Es el punto de entrada de la runtime y la capa de integración con sistema y servicios básicos.

### `lib/models/`
Directorio con modelos de dominio y serialización de datos fundamentales para la app.

#### `clima_sendero.dart`
Define estructuras para representar el clima del sendero, por ejemplo temperatura, humedad, condiciones meteorológicas y pronósticos. Se usa para visualizar información meteorológica asociada a un recorrido o ubicación.

#### `detalles_sendero.dart`
Modelo orientado a detalle técnico de un sendero. Normalmente se usa para mapear la respuesta de datos asociados a una ruta, sus propiedades y su metadata condicional.

#### `explore_trail.dart`
Representa un sendero del catálogo de exploración. Tiene campos típicos como nombre, dificultad, resumen, distancia, foto, autor y enlace de origen o GPX. Es esencial para listar rutas públicas o compartidas.

#### `saved_route.dart`
Modelo de ruta local guardada por el usuario. Tiene un rol crítico en persistencia offline, almacenamiento local y reproducción de rutas sincronizadas con GPX.

### `lib/screen/`
Directorio principal de la interfaz de usuario.

#### `inicio.dart`
Pantalla principal de navegación de la app. Es la shell de la aplicación con una estructura tipo dashboard. Normalmente se usa para manejar el `BottomNavigationBar` y alternar entre secciones: exploración, guardados, grabación, comunidad y perfil.

#### `explorar.dart`
Pantalla de catálogo de senderos. Aquí se muestran rutas disponibles, se aplican filtros y se gestionan visualmente los senderos. Se conecta con servicios de obtención de senderos y favoritos.

#### `guardados.dart`
Pantalla de rutas locales/guardadas. Sirve para listar recorridos guardados en almacenamiento del dispositivo, mostrar estado local y eventualmente abrir o importar rutas previas.

#### `grabar.dart`
Interfaz de grabación in situ. Controla el proceso visual de seguimiento del recorrido: mapa, detalles de ruta, métricas y acciones de inicio/pausa/fin.

#### `grabar_controller.dart`
Lógica de control del flujo de grabación. Se encarga de permisos, seguimiento de ubicación, cálculo de distancia, almacenamiento y transiciones de estado de la ruta.

#### `grabar_styles.dart`
Define estilos, colores y presentaciones visuales utilizadas por los widgets y pantallas de grabación. Evita duplicación de temas dentro del flujo de tracking.

#### `detalle_sendero.dart`
Pantalla de detalle ampliado para un sendero. Presenta ruta, metadata del recorrido, ubicación, clima y opciones de interacción. En la práctica se usa para profundizar en la descripción del recorrido y preparar la navegación.

#### `seguir_sendero.dart`
Pantalla de seguimiento de ruta durante la navegación. Alinea la ubicación real del usuario con la ruta del sendero para orientar al usuario según un recorrido predefinido.

#### `previsualizar_gpx.dart`
Pantalla de previsualización de un archivo GPX cargado desde almacenamiento externo o desde un enlace de apertura. Muestra puntos de trazado sobre un mapa y deja listo el contenido para analizarlo dentro de la app.

#### `amigos.dart`
Pantalla de comunidad. Permite listar usuarios, buscar amigos, gestionar contactos y quizá consultar ubicaciones compartidas o relaciones sociales entre usuarios.

#### `ubicacion_amigo.dart`
Vista geográfica de la ubicación de un amigo. Suele depender de servicios de ubicación compartida para renderizar el punto del usuario en un mapa.

#### `perfil.dart`
Pantalla de perfil del usuario. Muestra información personal y datos de la cuenta.

#### `configuracion.dart`
Configuración de la app. Aquí se gestionan ajustes visuales, preferencias del usuario y navegación interna de opciones.

#### `localizacion.dart`
Módulo de localización. Es la capa encargada de medir y resolver la posición actual del usuario y apoyar a la lógica de GPS del proyecto.

#### `notificaciones.dart`
Vista para notificaciones internas, probablemente usada para avisos, alertas de rutas o mensajes sociales.

### `lib/services/`
Capa de integración y lógica transversal.

#### `servicio_autenticacion.dart`
Servicio central para autenticación con Supabase. Maneja inicio de sesión, registro, cierre de sesión, sesión persistente y sincronización del perfil con la base de datos.

#### `obtener_sendero.dart`
Servicio para consultar senderos desde backend (Supabase o origen externo) y convertir esos datos en modelos utilizable por la UI. Es la interfaz de consulta de rutas públicas.

#### `guardado_local.dart`
Persistencia de rutas localmente en el dispositivo. Guarda metadata, puntos, fotos y archivos relevantes para la ruta sin depender de conexión externa.

#### `almacenamiento_r2.dart`
Servicio para subir archivos a almacenamiento remoto R2 de Cloudflare. Normalmente se utiliza para guardar GPX, imágenes o recursos relacionados con rutas públicas.

#### `gpx_import.dart`
Parser de archivos GPX. Lee el XML del archivo, extrae puntos GPS y metadatos, y genera una estructura de ruta usable dentro de la app.

#### `gpx_open_service.dart`
Servicio específico para detectar y manejar la apertura de archivos `.gpx` desde fuentes externas (Android intent, enlaces, gestores de archivos), así como para iniciar la previsualización dentro de la app.

#### `compartir_ubicacion.dart`
Servicio para compartir ubicación entre usuarios. Interactúa con Supabase o almacenamiento remoto para publicar la ubicación de un usuario y consultarla desde otra parte de la app.

#### `senderos_favoritos.dart`
Módulo de favoritos. Gestiona la relación entre usuario y rutas destacadas. Permite agregar, eliminar y cargar favoritos sin depender de un servicio global de alta complejidad.

#### `senderos_locales.dart`
Encapsula la lógica de rutas locales, cache y estado persistente en dispositivo. En la práctica, ayuda a distinguir rutas almacenadas localmente de rutas públicas.

#### `servicio_clima_sendero.dart`
Servicio para consultar previsión meteorológica según la ubicación o el sendero. Sirve para mejorar la UX de planificación y navegación al mostrar condiciones del entorno.

#### `offline_tile_service.dart`
Módulo para gestionar tiles cartográficos offline. Es importante en entornos con poca conexión o para navegación sin cobertura de red.

### `lib/utils/`
Carpeta de utilidades reutilizables.

#### `route_calculator.dart`
Calcula distancias, puntos más cercanos y métricas de recorrido. Tiene utilidad en tracking GPS, validación de rutas, cálculo de proximidad y apoyo a la navegación.

### `lib/widgets/`
Componentes UI reutilizables y atómicos.

#### `login.dart`
Pantalla o widget de autenticación. Maneja el flujo completo de login y registro, y suele estar asociado directamente al servicio de autenticación.

#### `barra_navegacion.dart`
Componente de navegación inferior. Centraliza la barra con tabs o destinos principales del app.

#### `sendero_card.dart`
Tarjeta visual para mostrar un sendero con imagen, título, dificultad, distancia y botón de favorito.

#### `filtros.dart`
Widget de filtrado para explorar senderos. Normalmente encapsula inputs visuales para ordenar y filtrar por tipo, dificultad o nombre.

#### `grabar_action_button.dart`
Botón reutilizable para iniciar, pausar, reanudar o detener la grabación de una ruta.

#### `grabar_metric_indicator.dart`
Mostrador de métricas durante la grabación: tiempo, distancia, elevación acumulada, velocidad, etc.

#### `config_card.dart`
Tarjeta reutilizable para opciones de configuración dentro de la pantalla de ajustes.

#### `clima_sendero_card.dart`
Widget visual para mostrar el clima del sendero. Reutiliza la capa de `servicio_clima_sendero.dart` y la de modelos meteorológicos.

#### `save_route_dialog.dart`
Diálogo para guardar una ruta en proceso, completar la metadata y decidir si se publica o se mantiene local.

#### `search_field.dart`
Campo reutilizable para búsqueda por texto dentro de la app.

#### `default_user_avatar.dart`
Asset o widget de fallback para usuarios sin avatar personalizado.

#### `login_styles.dart`
Estilos visuales específicos para la pantalla de login.

## Flujo funcional principal

### 1. Inicio de sesión
La app arranca desde `main.dart`, inicializa Supabase y carga el flujo de autenticación. Si no existe sesión activa, se muestra `login.dart` o una pantalla equivalente. Si sí existe, se entra al `HomePage`.

### 2. Navegación principal
`inicio.dart` gestiona el contenido principal y el estado de la navegación según la pestaña activa. Normalmente el usuario alterna entre:

- exploración
- rutas guardadas
- grabación
- comunidad
- perfil

### 3. Exploración de senderos
`explorar.dart` usa servicios como `obtener_sendero.dart` para consultar rutas y `senderos_favoritos.dart` para sincronizar estado local del usuario.

### 4. Grabación de rutas
`grabar.dart` + `grabar_controller.dart` gestionan permisos de ubicación, inicio de tracking, cálculo de distancia/tiempo y almacenamiento del recorrido. El contorno del recorrido se representa sobre un mapa y se puede guardar como GPX o ruta local.

### 5. Importación de GPX
`gpx_import.dart` parsea un documento XML y crea datos de seguimiento. `gpx_open_service.dart` intercepta archivos externos para iniciar la vista previa de rutas o su carga dentro de la app.

### 6. Persistencia y publicación
- `guardado_local.dart` persiste en almacenamiento local.
- `almacenamiento_r2.dart` gestiona sincronización/cloud de contenido.
- `senderos_locales.dart` centraliza la lógica de quieres guardar rutas o leer rutas guardadas.

### 7. Comunidad y social
`amigos.dart` y `compartir_ubicacion.dart` permiten ver usuarios, gestionar amistades y compartir ubicación geográfica.

## Reglas de diseño del proyecto

### Separación de responsabilidades

- `screen/` = UI + estado componente
- `widgets/` = piezas reutilizables
- `services/` = lógica de negocio, acceso a datos y APIs
- `models/` = contratos de datos
- `utils/` = cálculos y helpers

### Principio de dominio

El proyecto intenta mantener la lógica del negocio fuera de la vista. Esto ayuda a:

- testear más fácilmente los servicios
- reutilizar la lógica en varias pantallas
- evitar acoplamiento fuerte entre UI y acceso a datos

### Dependencia de Supabase

El backend principal está enfocado en:

- autenticación
- perfiles
- almacenamiento de entidades relacionadas con senderos
- comunidad y relaciones de amistad
- disponibilidad de rutas externas

## Pruebas

La carpeta `test/` incluye pruebas para validar el comportamiento crítico del sistema.

### Archivos actuales

- `friend_route_service_test.dart`
- `route_distance_calculator_test.dart`
- `widget_test.dart`

Estas pruebas cubren áreas como:

- cálculo de distancias
- rutas de amistad/amigos
- validación visual básica de widgets

## Riesgos y mejoras recomendadas

1. Credenciales de Supabase en código
   - Actualmente se inicializa directamente con URL y clave pública.
   - Lo recomendable es mover la configuración a variables de entorno o a un archivo local no versionado.

2. Persistencia de rutas y archivos
   - Se recomienda centralizar la política de almacenamiento en un servicio único para evitar duplicidad de responsablidades.

3. Lógica de mapas y GPS
   - `Geolocator` y el manejo del recorrido deberían estar encapsulados con más claridad para reducir dependencia directa de pantallas.

4. Test coverage
   - El proyecto tiene cobertura inicial, pero conviene ampliarla a los servicios de GPX, ubicación y sincronización con Supabase.

## Recomendaciones para desarrollo futuro

- Mantener `lib/services` como la capa de negocio y `lib/screen` como capa de presentación.
- Añadir DTOs/serializers explícitos para evitar acoplar entidades de backend con UI.
- Reutilizar `models` para definir contratos del dominio y no crear clases ad hoc en pantallas.
- Para cada nueva funcionalidad, preferir pruebas unitarias en servicio antes de construir UI compleja.
- Centralizar configuración ambiental para no comprometer claves ni endpoints en código fuente.

## Resumen ejecutivo

Este proyecto tiene una estructura sólida para una app móvil de senderismo con componente social y geoespacial. Su arquitectura se apoya en:

- Flutter como framework principal
- Supabase como backend
- mapas y localización real-time
- carga y exportación de rutas GPX
- almacenamiento local y remoto
- lógica de comunidad

Es un proyecto orientado a una experiencia de usuario completa centrada en rutas de senderismo, pero con una fachadqa técnica suficientemente modular para crecer en varias direcciones: comunidad, geolocalización, planificación, social features y análisis de recorridos.



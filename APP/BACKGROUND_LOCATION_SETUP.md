# Configuración de Ubicación en Segundo Plano

## Cambios Realizados ✅

He actualizado tu app para que mantenga la ubicación activa incluso cuando está en segundo plano:

### 1. **AndroidManifest.xml** 📱
✅ Agregado permiso: `android.permission.ACCESS_BACKGROUND_LOCATION`

Este permiso permite que tu app acceda a la ubicación en segundo plano en Android 10+.

### 2. **main.dart** 🎯
✅ **Solicitud de permisos mejorada**: Ahora solicita:
   - `Permission.location` - Ubicación mientras está en uso
   - `Permission.locationAlways` - Ubicación en segundo plano (Android 12+)

✅ **LocationSettings mejorada**: 
   - `accuracy: LocationAccuracy.high` - Precisión de GPS
   - `distanceFilter: 5` - Actualiza cada 5 metros
   - `timeLimit: Duration(seconds: 5)` - Timeout de 5 segundos entre actualizaciones

✅ **Mejor manejo de servicios**:
   - Ahora intenta abrir la configuración de ubicación si está desactivada
   - Agrega timeout a `getCurrentPosition()` para evitar bloqueos

---

## Requisitos para Funcionamiento ⚙️

### Android 12+ (API 31+)
Cuando el usuario ejecute la app:
1. Se le pedirá permiso: **"¿Permitir acceso a la ubicación?"** 
   - Seleccionar **"Permitir todo el tiempo"** (Allow all the time)
2. Esto activa el permiso de segundo plano

### Android 11 e inferior
- Solo se pide permiso de ubicación normal
- Funciona automáticamente en segundo plano

### iOS (si aplica en futuro)
Agregar en `Info.plist`:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Necesitamos tu ubicación para mostrar el mapa en tiempo real</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Necesitamos acceso a tu ubicación en segundo plano para grabar trayectos</string>
```

---

## Configuraciones Avanzadas (Opcional)

### Para Reducir Consumo de Batería:
```dart
locationSettings: const LocationSettings(
  accuracy: LocationAccuracy.medium,  // Cambiar a medium
  distanceFilter: 10,                  // Actualizar cada 10 metros en lugar de 5
  timeLimit: Duration(seconds: 10),    // 10 segundos en lugar de 5
)
```

### Para Mayor Precisión:
```dart
locationSettings: const LocationSettings(
  accuracy: LocationAccuracy.best,     // Máxima precisión
  distanceFilter: 1,                   // Cada metro
  timeLimit: Duration(seconds: 2),     // Más frecuente
)
```

---

## Compilar y Probar 🚀

```bash
# En la carpeta del proyecto
flutter clean
flutter pub get
flutter run
```

---

## Notas Importantes 📌

1. **Ubicación debe estar activa**: El usuario debe tener GPS/ubicación activada en el dispositivo
2. **Permiso de segundo plano**: En Android 12+, debe elegir "Permitir todo el tiempo" (not "solo mientras usa la app")
3. **Batería**: El seguimiento continuo en segundo plano consume batería. Usa `distanceFilter` para reducir actualizaciones
4. **Testing**: Prueba en un dispositivo físico, no en emulador para ubicación en segundo plano

---

## Verificar que Funciona ✔️

1. Inicia la app
2. Acepta los permisos de ubicación
3. Cierra la app completamente
4. Verifica en la barra de estado del teléfono que hay un ícono de ubicación activa 📍
5. La app seguirá registrando ubicación en segundo plano

---

## Solución de Problemas 🔧

### No actualiza ubicación en segundo plano:
- Verifica que hayas seleccionado "Permitir todo el tiempo"
- Verifica que GPS esté activado en el dispositivo
- En algunas marcas (Samsung, Xiaomi), desactiva "Optimización de batería" para la app

### No se pide permiso de segundo plano:
- Es normal en Android 11 e inferior
- Solo aparece en Android 12+

### La batería se agota rápido:
- Aumenta `distanceFilter` a 10-20 metros
- Aumenta `timeLimit` a 10-30 segundos
- Usa `LocationAccuracy.medium` en lugar de `high`

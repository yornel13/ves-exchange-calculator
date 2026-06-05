# Smart Calculator - Contexto del Proyecto

## Descripcion General

Smart Calculator es una aplicacion movil desarrollada en Flutter que funciona como calculadora con soporte para tasas de cambio en tiempo real. Permite realizar conversiones entre diferentes monedas (USD, EUR, USDT) y Bolivares Venezolanos (VES).

---

## Arquitectura

### Frontend (Este proyecto)
- **Tecnologia:** Flutter/Dart
- **Ubicacion:** `C:\Project\calculadora\smart_calculator`
- **Branch actual:** `feature/dev-luis`

### Backend
- **Proyecto:** multi-backend
- **Ubicacion:** `C:\Project\multi-backend`
- **Servicio utilizado:** `services/calculator`
- **URL Produccion:** `https://multi-backend-5bta.onrender.com`
- **URL Local:** `http://localhost:3000`

---

## Endpoints del Backend

### Tasas BCV (USD/VES y EUR/VES)
```
GET /api/calculator/bcv/rates
```
Respuesta:
```json
{
  "usd": 53.12,
  "eur": 56.89
}
```

### Precio USDT/VES
```
GET /api/calculator/binance/usdt-p2p?asset=USDT&fiat=VES
```
Respuesta:
```json
{
  "asset": "USDT",
  "fiat": "VES",
  "price": 537.16,
  "source": "Yadio USDT"
}
```

---

## Archivos Clave

### Frontend (smart_calculator)

| Archivo | Descripcion |
|---------|-------------|
| `lib/services/rate_service.dart` | Servicio que consume las APIs del backend para obtener tasas de cambio. Contiene URLs configurables para local/produccion. |
| `lib/components/calculator_screen.dart` | Pantalla principal de la calculadora |
| `lib/components/settings_screen.dart` | Pantalla de configuracion con personalizacion de montos y actualizacion automatica |
| `lib/components/history_screen.dart` | Bottom sheet con historial de operaciones |

### Backend (multi-backend/services/calculator)

| Archivo | Descripcion |
|---------|-------------|
| `src/services/binanceP2PService.ts` | Servicio que obtiene el precio de USDT/VES desde Yadio API |
| `src/controllers/binanceController.ts` | Controlador para el endpoint de Binance/USDT |
| `src/routes/binanceRoutes.ts` | Rutas del API de Binance |

---

## Configuracion de URLs (rate_service.dart)

El archivo `lib/services/rate_service.dart` tiene configuracion para cambiar facilmente entre entornos:

```dart
// -------------------- URLs LOCALES (desarrollo) --------------------
// static const _bcvBackendUrl =
//     'http://localhost:3000/api/calculator/bcv/rates';
// static const _usdtBackendUrl =
//     'http://localhost:3000/api/calculator/binance/usdt-p2p?asset=USDT&fiat=VES';

// -------------------- URLs PRODUCCION --------------------
static const _bcvBackendUrl =
    'https://multi-backend-5bta.onrender.com/api/calculator/bcv/rates';
static const _usdtBackendUrl =
    'https://multi-backend-5bta.onrender.com/api/calculator/binance/usdt-p2p?asset=USDT&fiat=VES';
```

**Nota para emulador Android:** `localhost` apunta al emulador, no a tu PC. Usa `10.0.2.2` para llegar a tu maquina local.

---

## Historial de Cambios Importantes

### 2026-02-05: Mejoras de UI y UX

**Cambios realizados:**

1. **Padding inferior global para barra de navegacion:**
   - Se agrego `MediaQuery.of(context).viewPadding.bottom` en `calculator_screen.dart` y `settings_screen.dart`
   - Evita que la barra de navegacion del sistema cubra los botones inferiores
   - El padding es dinamico y se adapta a cada dispositivo

2. **Scroll optimizado en Settings:**
   - Se movio el padding del widget `Padding` al `ListView.padding`
   - Permite que el contenido llegue hasta el borde del AppBar al hacer scroll
   - Mantiene el espaciado inicial de 16px

3. **Boton de sincronizacion reubicado:**
   - Se movio el boton "Consultar montos oficiales" a la seccion "Ultima actualizacion"
   - Ahora es un IconButton transparente con solo el icono de sync
   - Ubicado en la esquina superior derecha del Card

4. **Actualizacion automatica de tasas:**
   - Se implemento `_silentRefreshRates()` para actualizacion automatica cada hora
   - Control con `_isAutoUpdating` para evitar multiples actualizaciones simultaneas
   - Timer que calcula tiempo restante basado en ultima actualizacion

5. **Mejora en seccion de montos personalizados:**
   - Cada moneda ahora muestra su valor oficial al lado del titulo
   - Labels mas descriptivos: "Personalizado" en los TextFields
   - Formato: "USD a VES (Oficial: XX.XX Bs)"

### 2026-02-05: Correccion de precio USDT

**Problema:** El precio de USDT/VES que devolvia el backend era menor al esperado (450 vs 537).

**Causa:** El servicio `binanceP2PService.ts` consultaba directamente la API de Binance P2P, que devolvia el primer anuncio disponible (~450 VES).

**Solucion:** Se modifico el servicio para usar la API de Yadio (`https://api.yadio.io/json`) que devuelve el precio correcto (~537 VES).

**Archivos modificados:**
- `C:\Project\multi-backend\services\calculator\src\services\binanceP2PService.ts`

### 2025-12-30: Migracion de backend

**Cambio:** Se migraron las URLs del backend antiguo al nuevo multi-backend.

| Tipo | URL Anterior | URL Nueva |
|------|--------------|-----------|
| BCV | `https://smart-calculator-backend-9ott.onrender.com/api/bcv/rates` | `https://multi-backend-5bta.onrender.com/api/calculator/bcv/rates` |
| USDT | `https://smart-calculator-backend-9ott.onrender.com/api/binance/usdt-p2p` | `https://multi-backend-5bta.onrender.com/api/calculator/binance/usdt-p2p` |

---

## Estructura de Pantallas

### Calculator Screen
```
Scaffold
├── AppBar (con menu de opciones)
└── Body (Container con imagen de fondo opcional)
    └── Padding (con viewPadding.bottom para barra de navegacion)
        └── Column
            ├── Display (flex: 2) - Muestra expresion y resultado
            ├── Divider
            └── Keyboard (flex: 3) - Botones de la calculadora
```

### Settings Screen
```
Scaffold
├── AppBar
└── ListView (con padding que incluye viewPadding.bottom)
    ├── Card: Configuracion de inicio (tipo de calculadora)
    ├── Card: Apariencia (tema, imagen de fondo, transparencia)
    ├── Card: Personalizar Montos (USD, EUR, USDT)
    └── Card: Ultima actualizacion (con boton sync)
```

---

## Fuentes de Datos

### Yadio API
- **URL:** `https://api.yadio.io/json`
- **Uso:** Obtener precio USDT/VES
- **Campo utilizado:** `USD.other.usdt.rate`

### BCV (Banco Central de Venezuela)
- **Uso:** Obtener tasas oficiales USD/VES y EUR/VES
- **Nota:** El backend hace scraping o consulta APIs del BCV

---

## Comandos Utiles

### Flutter
```bash
# Ejecutar app en modo debug
flutter run

# Compilar APK
flutter build apk

# Limpiar cache
flutter clean
```

### Backend Local
```bash
# Desde C:\Project\multi-backend
npm run dev
```

---

## Notas Adicionales

- El backend `multi-backend` es una arquitectura de microservicios que contiene varios servicios: `calculator`, `ecommerce`, `secury`
- El servicio `calculator` es el que usa esta app
- Siempre que se hagan cambios en el backend, se debe hacer deploy a Render para que se reflejen en produccion
- Las tasas se actualizan automaticamente cada hora cuando la app esta en la pantalla de Settings
- El padding inferior usa `MediaQuery.viewPadding.bottom` que es dinamico segun el dispositivo

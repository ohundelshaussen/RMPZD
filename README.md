# RMPZD: Sistema de Alerta Temprana de Riesgo Materno-Perinatal

Aplicación multiplataforma para tamizaje clínico y detección temprana de complicaciones obstétricas en comunidades rurales dispersas y resguardos indígenas del departamento del Cesar y La Guajira.

- **Institución:** Universidad Popular del Cesar (Valledupar, Colombia)
- **Programa:** Ingeniería de Sistemas
- **Asignatura:** Inteligencia Artificial (Grupo 02, 2026)
- **Docente:** Ing. Tonny Jiménez Márquez
- **Integrantes:**
  - Dharla José Durán Riobo
  - César Andrés Amaya Díaz
  - Óscar Andrés Hundelshaussen Barreto

---

## 1. Descripción del Proyecto

RMPZD es un sistema de soporte a la decisión clínica diseñado para operar en zonas de difícil acceso geográfico con conectividad nula o intermitente. La herramienta permite a promotores de salud comunitaria, personal de enfermería y médicos evaluar a gestantes mediante un formulario estandarizado, emitir una estratificación de riesgo en tiempo real y almacenar la información de forma local para su posterior sincronización con la nube institucional.

El sistema incorpora un doble flujo de interacción:
1. **Portal de Consulta Ciudadana:** Acceso público para pacientes que requieren verificar su resultado de evaluación mediante documento de identidad y código de consulta seguro, sin requerir credenciales ni almacenar datos privados en el dispositivo de consulta.
2. **Entorno Clínico y Administrativo:** Acceso restringido por credenciales institucionales para el personal de salud, con capacidades de triaje obstétrico, historial local, auditoría de registros centralizados y visualización analítica.

---

## 2. Motor de Inferencia e Inteligencia Artificial

La evaluación del riesgo materno y perinatal implementa un enfoque híbrido en dos niveles, priorizando la seguridad del paciente sobre el modelo probabilístico:

### Nivel 1: Reglas Determinísticas de Seguridad Clínica (Código Rojo)
Antes de ejecutar cualquier estimación probabilística, el sistema valida signos de alarma críticos basados en guías ACOG y protocolos nacionales de obstetricia:
- Presión arterial sistólica >= 160 mmHg o diastólica >= 110 mmHg (Crisis Hipertensiva / Sospecha de Preeclampsia Severa).
- Hemoglobina < 7.0 g/dL (Anemia Grado IV / Severa).
- Proteinuria positiva (>= 2+).
- Sangrado vaginal activo o antecedentes inmediatos de convulsiones.

Si se detecta cualquiera de estos criterios, el sistema clasifica de inmediato a la paciente en **Alto Riesgo Obstétrico (Código Rojo)** y despliega recomendaciones de remisión urgente a segundo o tercer nivel, sin supeditar la alerta al modelo estadístico.

### Nivel 2: Inferencia Supervisada Embebida
Si no se disparan reglas de emergencia, el motor ejecuta localmente en Dart (`AiInferenceEngine`) la inferencia con parámetros precalculados durante la fase de entrenamiento:
- **Preprocesamiento:** Imputación de variables faltantes por mediana/moda, codificación One-Hot para variables categóricas (grupo étnico, zona, régimen de salud) y normalización numérica con `StandardScaler`.
- **Modelos:** Regresión logística multiclase para nivel de riesgo (Bajo, Medio, Alto) y modelo logístico binario para probabilidad de desenlace perinatal adverso.
- **Calibración de Umbrales:** Ajuste para optimizar sensibilidad en subgrupos vulnerables, fijando el umbral de corte en 0.25 para riesgo alto y 0.30 para desenlace adverso, minimizando falsos negativos en poblaciones dispersas.

---

## 3. Arquitectura del Software

El proyecto sigue una arquitectura limpia orientada a características (Feature-First) con desacoplamiento entre capas de datos, dominio y presentación.

### Estructura del Repositorio

```text
lib/
├── app/
│   ├── app.dart                   # Enrutamiento principal y compuerta declarativa de autenticación
│   └── routes.dart                # Nombres de rutas del sistema
├── core/
│   ├── config/                    # Carga de variables de entorno desde env.json
│   ├── constants/                 # Umbrales clínicos ACOG, pesos de IA y constantes globales
│   ├── database/                  # Configuración SQLite local con soporte FFI multiplataforma
│   ├── network/                   # Utilidades de conectividad y detección de red
│   ├── sync/                      # Gestor de sincronización transaccional unidireccional
│   ├── theme/                     # Paleta institucional, tipografía y estilos visuales
│   └── utils/                     # Formateadores, validadores y generadores de código
└── features/
    ├── admin_records/             # Auditoría y visualización de registros centralizados (Rol Admin)
    ├── auth/                      # Autenticación Supabase, control de roles y menú de sesión
    ├── dashboard/                 # Tablero analítico (vista operativa y validación clínica de Fase 2)
    ├── history/                   # Historial local de evaluaciones guardadas en SQLite
    ├── patient_portal/            # Consulta ciudadana de dictámenes mediante RPC y descarga de PDF
    └── triage/                    # Formulario de evaluación, motor de inferencia y dictamen clínico
```

### Principios Arquitecturales
- **Offline-First:** Las evaluaciones del personal de salud se persisten inmediatamente en SQLite de forma local. La ausencia de internet no interrumpe el flujo de trabajo ni bloquea la emisión de resultados.
- **Sincronización Idempotente:** La subida de evaluaciones a Supabase emplea identificadores UUID únicos generados en el cliente, control de estados (`pendiente`, `sincronizado`, `error`) y reintentos transaccionales para evitar duplicaciones.
- **Seguridad en Consulta de Pacientes:** El portal de pacientes se comunica mediante una función RPC en el servidor. La información consultada vive únicamente en la memoria de la vista y no se almacena en la base de datos local del dispositivo donde se consulta.
- **Gestión de Sesión:** Menú de cuenta integrado (`AccountMenuButton`) en todas las vistas clínicas, el cual alerta al operador si intenta cerrar sesión mientras existan registros locales pendientes de sincronizar.

---

## 4. Requisitos del Entorno

Para compilar y ejecutar el proyecto se requiere:
- Flutter SDK 3.24.0 o superior (compatible con canal estable 3.47+)
- Dart SDK 3.5.0 o superior
- Git
- Compilador de C++ para soporte de escritorio (Visual Studio con herramientas de escritorio C++ en Windows) o Android Studio con SDK configurado para compilación móvil.

---

## 5. Instalación y Configuración

### 1. Clonar el repositorio
```bash
git clone https://github.com/ohundelshaussen/RMPZD.git
cd RMPZD
```

### 2. Instalar dependencias
```bash
flutter pub get
```

### 3. Configurar variables de entorno
Crear el archivo `env.json` en la raíz del proyecto tomando como base `env.example.json`:
```bash
# En Windows (PowerShell)
Copy-Item env.example.json env.json

# En Linux / macOS
cp env.example.json env.json
```

Completar los valores correspondientes en `env.json`:
```json
{
  "SUPABASE_URL": "https://tu-proyecto.supabase.co",
  "SUPABASE_ANON_KEY": "tu-clave-anonima-publica"
}
```
*Nota: Este archivo contiene credenciales públicas y se encuentra ignorado en el control de versiones. No exponga la clave de servicio (`service_role`).*

---

## 6. Verificación y Pruebas

El repositorio mantiene una suite de pruebas automatizadas que cubren el motor de inferencia, reglas de validación clínica, persistencia en SQLite, generación de reportes en PDF y componentes de interfaz.

Para ejecutar el análisis estático de código:
```bash
flutter analyze
```

Para ejecutar la suite completa de pruebas unitarias y de widgets:
```bash
flutter test
```

---

## 7. Ejecución de la Aplicación

### Windows Desktop
```bash
flutter run -d windows --dart-define-from-file=env.json
```

### Dispositivo o Emulador Android
```bash
flutter run -d android --dart-define-from-file=env.json
```

### Navegador Web
```bash
flutter run -d chrome --dart-define-from-file=env.json
```

---

## 8. Módulos y Funcionalidades Principales

| Módulo | Tipo de Acceso | Funcionalidad Principal |
| :--- | :--- | :--- |
| Portal de Pacientes | Público (Sin autenticación) | Consulta de resultados con cédula y código alfanumérico de 6 dígitos. Visualización del nivel de riesgo, recomendaciones obstétricas y exportación de dictamen médico en PDF. |
| Autenticación | Público / Institucional | Selector de acceso entre paciente y personal de salud. Ingreso con correo institucional y contraseña, validación de roles y control de estado de sesión. |
| Triaje Clínico | Personal de Salud | Formulario dinámico con validación de signos vitales, antecedentes y síntomas de alarma. Inferencia local híbrida (reglas + modelo IA) y generación de código de consulta. |
| Historial Local | Personal de Salud | Listado de evaluaciones registradas en el dispositivo, detalle clínico individual y estado de sincronización hacia la nube. |
| Tablero Analítico | Personal de Salud / Admin | Panel dual con indicadores operativos en tiempo real y métricas de validación clínica (matrices de confusión, F1-macro y análisis de disparidad étnica). |
| Registros Centrales | Administrador | Vista global de registros sincronizados en Supabase con paginación, filtros por médico, rango de fechas, etnia y nivel de riesgo. |

---

## 9. Licencia y Uso Académico

Proyecto desarrollado exclusivamente con fines académicos y de investigación en salud pública para la asignatura de Inteligencia Artificial de la Universidad Popular del Cesar. Prohibido su uso comercial no autorizado.

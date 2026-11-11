# RMPZD — Sistema de Alerta Temprana de Riesgo Materno-Perinatal

**Aplicación Móvil para Zonas Dispersas y Comunidades Indígenas (Cesar y La Guajira)**  
*Proyecto de Aula — Asignatura: Inteligencia Artificial (Grupo 02)*  
*Universidad Popular del Cesar (Valledupar, Colombia - 2026)*

---

## 👥 Equipo y Docente
* **Docente:** Tonny Jiménez Márquez
* **Integrantes:**
  * Dharla José Durán Riobo
  * César Andrés Amaya Díaz
  * Óscar Andrés Hundelshaussen Barreto

---

## 📱 Descripción de la Solución (Fase 3)

Esta aplicación móvil desarrollada en **Flutter** permite a los promotores y agentes comunitarios de salud realizar tamizaje y detección temprana de complicaciones obstétricas en gestantes de asentamientos rurales e indígenas dispersos sin depender de conexión a internet (**100% Offline-First**).

### Características Principales:
1. **Motor Híbrido de Inferencia en Tiempo Real:**
   * **Capa 1 (Reglas Clínicas Inflexibles):** Si la gestante presenta crisis hipertensiva ($\ge 160/110$ mmHg) o anemia severa ($< 7.0$ g/dL), el sistema activa de inmediato **Alerta Roja Obstétrica / Código Rojo** sin supeditar la decisión al modelo estadístico.
   * **Capa 2 (IA Supervisada Embebida):** Ejecución nativa del pipeline de Machine Learning (imputación, escalado `StandardScaler`, One-Hot Encoding y modelo logístico multiclase y binario) con los umbrales calibrados en la Fase 2 ($0.25$ para riesgo alto y $0.30$ para desenlace adverso).
2. **Persistencia Local Segura con SQLite:** Almacenamiento íntegro de historias clínicas y dictámenes en el dispositivo móvil.
3. **Casos Preconfigurados para Demostración / Sustentación:** Botón con selector rápido de casos (Bajo Riesgo Urbano, Emergencia Hipertensiva Wayuu, Riesgo Moderado en Serranía) para agilizar la demo ante el docente.
4. **Módulo de Auditoría y Métricas IA:** Dashboard visual con métricas de la Fase 2, F1-macro, recall por etnia (Wayuu vs No Indígena) y justificación metodológica.

---

## 🏛️ Arquitectura de Software: Feature-First

El código está estructurado bajo principios de arquitectura limpia orientada a funcionalidades (**Feature-First**):

```text
lib/
├── core/
│   ├── constants/           # Colores, umbrales clínicos de ACOG y de IA
│   ├── database/            # Helper local SQLite con soporte móvil y desktop
│   └── theme/               # Diseño accesible y paleta cultural
│
└── features/
    ├── triage/              # Feature central de evaluación de riesgo
    │   ├── data/            # Motores de inferencia offline, SQLite datasource y repositorios
    │   ├── domain/          # Entidades (PatientAssessment, TriageResult) y Casos de Uso
    │   └── presentation/    # Formulario dinámico, presets y pantalla de dictamen
    │
    ├── history/             # Historial de consultas prenatales guardadas en SQLite
    │   └── presentation/    # Lista de pacientes, estados y cola de sincronización
    │
    └── dashboard/           # Métricas académicas y auditoría de subgrupos para la sustentación
        └── presentation/    # Tablas comparativas de modelos y análisis de sesgo étnico
```

---

## 🚀 Instrucciones de Ejecución

### Requisitos:
* Flutter SDK (versión 3.44 o superior)
* Dart SDK

### Pasos:
1. Clonar el repositorio:
   ```bash
   git clone -b feature/fase3-mobile-app https://github.com/ohundelshaussen/RMPZD.git
   cd RMPZD
   ```

2. Descargar paquetes:
   ```bash
   flutter pub get
   ```

3. Ejecutar pruebas unitarias y de widgets:
   ```bash
   flutter test
   ```

4. Ejecutar la aplicación:
   ```bash
   # En Windows Desktop
   flutter run -d windows

   # En Dispositivo o Emulador Android
   flutter run -d android

   # En Navegador Web
   flutter run -d chrome
   ```

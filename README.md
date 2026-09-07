# 🌾 AgroTrade Direct

> **Plataforma móvil para la negociación y trazabilidad de exportaciones de café y cacao entre Colombia y la Unión Europea.**

AgroTrade Direct es un desarrollo en Flutter diseñado para **RiTech SAS** que conecta directamente a pequeños y medianos exportadores colombianos con importadores de la Unión Europea mediante un modelo dinámico de negociación de precios estilo *InDrive*.

---

## 🔗 Enlaces Importantes

- 📄 **Espacio en Confluence:** `[COLOCAR_AQUI_URL_DE_CONFLUENCE]`
- 🎨 **Prototipos y Wireframes (Framer):** `[COLOCAR_AQUI_URL_DE_FRAMER]`
- 📊 **Product Backlog & Requerimientos:** [Google Drive - AgroTrade Backlog](https://drive.google.com/file/d/1MKV_Ac984Y7VsclXakVrPD6ntK1H9-Cx/view?usp=drive_link)

---

## 📌 Información General

- **Impulsor:** Valentina Burbano
- **Aprobador:** Profesora / Cliente (Representante de RiTech SAS)
- **Estado del Proyecto:** 🟡 En progreso
- **Fecha de Vencimiento:** 30 de octubre de 2026
- **Resultados Principales:**
  - Archivo ejecutable **APK** final para dispositivos Android.
  - Catálogo dinámico integrado con 25 requerimientos del sistema distribuidos en 3 Releases.
  - Módulo de negociación de precios estilo *InDrive* con actualización de propuestas en tiempo real.
  - Mapa dinámico interactivo de ruta logística Colombia – UE.

---

## 🚨 Planteamiento del Problema e Hipótesis

### Problema
Los pequeños y medianos exportadores colombianos de café y cacao enfrentan intermediaciones complejas, opacidad en la fijación de precios y barreras de entrada para conectar directamente con los compradores en la Unión Europea. Esta falta de canal directo limita el margen de ganancia de los productores agrícolas y dificulta la trazabilidad requerida por los importadores europeos.

### Hipótesis
Creemos que implementando una plataforma móvil accesible en Flutter con negociación directa de precios tipo *InDrive* y visualización geolocalizada entre Colombia y la UE, lograremos reducir la brecha comercial y agilizar los acuerdos de exportación de commodities. Sabremos que estamos en lo cierto si los exportadores e importadores logran cerrar intenciones de compra acordadas en tiempo real dentro de la aplicación con un flujo transparente.

---

## 🎯 Alcance del Proyecto

### 🟢 Debe tener (Must Have - Release 1 MVP)
* **REQ-01:** Generación del ejecutable APK en Flutter para Android.
* **REQ-02, REQ-03, REQ-04:** Sistema de registro e inicio de sesión independiente para Exportadores (NIT/Finca) e Importadores (Registro fiscal UE).
* **REQ-24:** Seguridad y control de acceso basado en roles.
* **REQ-06, REQ-07, REQ-08, REQ-09:** Módulo de registro y publicación de lotes de café y cacao (calidad, varietal, volumen disponible y precio base).
* **REQ-11, REQ-13:** Búsqueda y catálogo de ofertas activas con vista detallada.
* **REQ-14, REQ-15, REQ-16, REQ-17:** Flujo de negociación de precios en tiempo real estilo *InDrive* (solicitudes, contraofertas, aceptación, rechazo y confirmación).
* **REQ-25:** Pruebas integrales de funcionamiento de la solución.

### 🟡 Podría tener (Should Have - Release 2)
* **REQ-05:** Perfil de usuario editable para gestión de datos corporativos.
* **REQ-10, REQ-12:** Filtros avanzados por tipo de producto, rango de precio, volumen y país de destino en la UE.
* **REQ-18:** Tablero de seguimiento en mapa dinámico (Colombia - UE) sobre el estado logístico del despacho.
* **REQ-19:** Historial de operaciones finalizadas y canceladas.
* **REQ-20:** Sistema de notificaciones push para cambios de estado en negociaciones.

### 🔴 Fuera del alcance (Won't Have - Release 3 / Versiones posteriores)
* Procesamiento de pasarelas de pago transaccionales bancarias en vivo dentro de la app (se gestiona vía acuerdo contractual independiente).
* Rastreo por satélite GPS de buques cargueros en tiempo real (el seguimiento en mapa es por hitos logísticos estacionales).
* **REQ-21, REQ-22:** Calificaciones con estrellas y módulo de denuncias/reportes (reservados para Release 3).
* **REQ-23:** Gestión de base de datos relacional avanzada de alta densidad.

---

## 👥 Equipo de Trabajo

| Nombre | Rol |
| :--- | :--- |
| **Valentina Burbano** | Impulsora / Diseñadora UI/UX |
| **David Luna** | Colaborador / Product Owner / Analyst |
| **Valery Rosero** | Colaboradora / Arquitecta de Software |
| **Johan Delgado** | Colaborador / Desarrollador Backend |
| **Omar Acosta** | Colaborador / Desarrollador Frontend (Flutter) |
| **Equipo QA / Todos** | Aseguramiento de Calidad y Pruebas |

---

## 📅 Cronograma e Hitos

| Hito | Responsable | Fecha Límite | Estado |
| :--- | :--- | :--- | :--- |
| **Hito 1:** Propuesta comercial/técnica y User Story Map (25 REQ) | David Luna | 2026-09-05 | ✅ Completado |
| **Hito 2:** Aprobación de Confluence y arquitectura de datos | Valery Rosero | 2026-09-12 | 🟡 En progreso |
| **Hito 3:** Diseño de prototipos de alta fidelidad (Framer) | Valentina Burbano | 2026-09-20 | 🟡 En progreso |
| **Hito 4:** Estructuración de backend y servicios de autenticación | Johan Delgado | 2026-10-05 | ⚪ Sin iniciar |
| **Hito 5:** Desarrollo frontend en Flutter y conexión | Omar Acosta | 2026-10-18 | ⚪ Sin iniciar |
| **Hito 6:** Pruebas QA, corrección de hallazgos y APK final | Equipo QA / Todos | 2026-10-30 | ⚪ Sin iniciar |

---

## 🛠️ Stack Tecnológico

- **Frontend:** Flutter (Dart)
- **Backend / Base de datos:** Supabase REST API + PostgreSQL
- **Mapas y Geolocalización:** Google Maps SDK / OpenStreetMap (Marcadores Colombia – UE)
- **Gestión del Proyecto y Documentación:** Confluence

---

## 💻 Instalación y Configuración Local

### Requisitos Previos

1. [Flutter SDK](https://flutter.dev/docs/get-started/install) (Versión 3.x o superior)
2. [Android Studio](https://developer.android.com/studio) o [VS Code](https://code.visualstudio.com/)
3. Un emulador de Android o un dispositivo físico Android con modo depuración activado.

### Pasos para Ejecutar

1. **Clonar el repositorio:**
   ```bash
   git clone https://github.com/tu-usuario/Agrotrade_Direct.git
   cd Agrotrade_Direct
   ```

2. **Instalar dependencias:**
   ```bash
   flutter pub get
   ```

3. **Configurar variables de entorno:**
   Crea un archivo `.env` en la raíz del proyecto agregando las credenciales necesarias:
   ```env
   SUPABASE_URL=tu_url_de_supabase
   SUPABASE_ANON_KEY=tu_clave_anon_supabase
   GOOGLE_MAPS_API_KEY=tu_api_key_de_maps
   ```

4. **Ejecutar la aplicación:**
   ```bash
   flutter run
   ```

5. **Compilar la APK para pruebas:**
   ```bash
   flutter build apk --release
   ```

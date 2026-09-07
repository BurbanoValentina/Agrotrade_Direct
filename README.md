# 🌾 AgroTrade Direct

> **Plataforma móvil para la negociación y trazabilidad de exportaciones de café y cacao entre Colombia y la Unión Europea.**

AgroTrade Direct es una aplicación móvil desarrollada en **Flutter** diseñada para **RiTech SAS**. Conecta directamente a pequeños y medianos exportadores colombianos con importadores de la Unión Europea mediante un modelo dinámico de negociación de precios estilo *InDrive*.

---

## 🔗 Enlaces Importantes

- 📄 **Espacio en Confluence:** `[COLOCAR_AQUI_URL_DE_CONFLUENCE]`
- 🎨 **Prototipos y Wireframes (Framer):** `[COLOCAR_AQUI_URL_DE_FRAMER]`
- 📊 **Product Backlog & Requerimientos:** [Google Drive - AgroTrade Backlog](https://drive.google.com/file/d/1MKV_Ac984Y7VsclXakVrPD6ntK1H9-Cx/view?usp=drive_link)

---

## 📌 Información General

- **Impulsora / UX Lead:** Valentina Burbano
- **Aprobador:** Profesora / Cliente (Representante de RiTech SAS)
- **Estado del Proyecto:** 🟡 En progreso (Prototipo funcional / Migración a Backend)
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

## 🎯 Alcance del Proyecto y Estado de Requerimientos

### 🟢 MVP Actual / Base Prototipo Funcional
- **Autenticación Básica:** Registro e inicio de sesión con captura de rol (Exportador / Importador), empresa y país (`REQ-02`, `REQ-03`, `REQ-04`).
- **Exploración de Mercado:** Catálogo de ofertas de café y cacao con detalle completo (variedad, región, precio por tonelada, volumen, certificaciones y calificación) (`REQ-11`, `REQ-13`).
- **Búsqueda y Filtros:** Búsqueda por variedad u origen y filtrado por categoría (Todos, Café, Cacao) (`REQ-10`, `REQ-12`).
- **Simulación de Negociación:** Modal para envío de contraofertas con precio propuesto (`REQ-14`).
- **Arquitectura Base:** Separación en capas (Modelos, Proveedores de estado con Provider, Repositorios e Interfaces de datos) preparada para conexión a backend.

### 🟡 En Desarrollo / Pendientes (Release 2)
- **Persistencia en Backend:** Migración de datos locales simulados a base de datos real en **Supabase** (`REQ-23`).
- **Gestión de Ofertas:** Módulo completo para publicar, editar y eliminar ofertas por parte del exportador (`REQ-06` a `REQ-09`).
- **Flujo de Negociación Real:** Persistencia de contraofertas, ciclo de vida de propuestas (Aceptar / Rechazar) e historial de tratos en *My Deals* (`REQ-15` a `REQ-17`, `REQ-19`).
- **Rastreo Logístico:** Implementación completa del mapa dinámico Colombia – UE con marcadores e hitos de despacho en *Trade Map* (`REQ-18`).
- **Gestión de Perfil:** Pantalla de *Profile* completa y editable (`REQ-05`).
- **Seguridad y Notificaciones:** Control de acceso por roles (RBAC) y notificaciones Push (`REQ-20`, `REQ-24`).

### 🔴 Versiones Posteriores (Release 3)
- Procesamiento de pasarelas de pago transaccionales bancarias en vivo (acuerdo contractual independiente).
- Rastreo satelital GPS en tiempo real de buques cargueros (se gestiona mediante hitos logísticos estacionales).
- Sistema avanzado de calificaciones, reseñas, reportes y denuncias (`REQ-21`, `REQ-22`).
- Indicadores de mercado en vivo integrados a APIs financieras externas.

---

## 👥 Equipo de Trabajo

| Nombre | Rol Principal | Responsabilidades |
| :--- | :--- | :--- |
| **David Luna** | Product Owner / Developer | Gestión del Backlog, definición de producto y desarrollo |
| **Valery Rosero** | Scrum Master / Developer | Facilitación ágil, arquitectura general y desarrollo |
| **Omar Acosta** | Developer Lead (Flutter) | Liderazgo de arquitectura Frontend y UI/UX implementation |
| **Johan Delgado** | Backend & Database Engineer | Integración de Supabase, API REST y base de datos PostgreSQL |
| **Valentina Burbano** | UX/UI Designer & QA Specialist | Diseño de interfaz/prototipos, experiencia de usuario y estrategia QA |

---

## 📅 Cronograma e Hitos

| Hito | Responsable | Fecha Límite | Estado |
| :--- | :--- | :--- | :--- |
| **Hito 1:** Propuesta comercial/técnica y User Story Map (25 REQ) | David Luna | 2026-09-05 | ✅ Completado |
| **Hito 2:** Aprobación de Confluence y arquitectura de datos | Valery Rosero | 2026-09-12 | 🟡 En progreso |
| **Hito 3:** Diseño de prototipos de alta fidelidad (Framer) | Valentina Burbano | 2026-09-20 | 🟡 En progreso |
| **Hito 4:** Estructuración de backend y servicios de autenticación | Johan Delgado | 2026-10-05 | ⚪ Sin iniciar |
| **Hito 5:** Desarrollo frontend en Flutter y conexión | Omar Acosta | 2026-10-18 | ⚪ Sin iniciar |
| **Hito 6:** Pruebas QA, corrección de hallazgos y APK final | Valentina Burbano / Equipo | 2026-10-30 | ⚪ Sin iniciar |

---

## 🛠️ Stack Tecnológico y Arquitectura

- **Lenguaje:** Dart 3.3+
- **Framework Frontend:** Flutter (3.x+)
- **Manejo de Estado:** `provider` (MultiProvider + ChangeNotifier)
- **Estilos y Formato:** `google_fonts`, `intl`
- **Backend Target:** Supabase REST API + PostgreSQL
- **Mapas y Geolocalización:** Google Maps SDK / OpenStreetMap
- **Gestión de Proyecto:** Confluence & Google Drive

---

## 💻 Instalación y Configuración Local

### Requisitos Previos

1. [Flutter SDK](https://flutter.dev/docs/get-started/install) (Versión 3.3.0 o superior)
2. [Android Studio](https://developer.android.com/studio) o [VS Code](https://code.visualstudio.com/) con plugins de Flutter/Dart.
3. Emulador de Android o dispositivo físico en modo depuración.

### Pasos para Ejecutar

1. **Clonar el repositorio:**
   ```bash
   git clone [https://github.com/tu-usuario/Agrotrade_Direct.git](https://github.com/tu-usuario/Agrotrade_Direct.git)
   cd Agrotrade_Direct

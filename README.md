# BoardScan

## Descripción
BoardScan es una aplicación móvil desarrollada en Flutter diseñada para escanear pizarrones, extraer la información de las imágenes de forma inteligente y exportar los resultados directamente a documentos PDF limpios y estructurados.

## Características Principales
* **Captura y Escaneo:** Integración fluida para la toma de fotografías de pizarrones.
* **Extracción de Texto Avanzada:** Implementación de Google ML Kit para detectar y procesar texto escrito.
* **Exportación a PDF Limpio:** Generación de documentos PDF enfocados únicamente en el contenido útil, omitiendo encabezados innecesarios (como "Texto Extraído" o "Imágenes Detectadas") para entregar un resultado profesional a través de un servicio dedicado.
* **Flujo de Usuario Optimizado:** Diseño basado en un sistema de dos pantallas (`home_screen.dart` y `results_screen.dart`) que separa claramente la lógica de captura visual de la revisión de resultados.

## Requisitos Previos
Asegúrate de tener instalados los siguientes componentes en tu máquina antes de intentar ejecutar el proyecto:
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (versión estable más reciente).
* [Android Studio](https://developer.android.com/studio) o [Visual Studio Code](https://code.visualstudio.com/) con las extensiones de Flutter y Dart instaladas.
* Un dispositivo físico (Android/iOS) conectado mediante USB/Wi-Fi o un emulador configurado.

## Instalación y Ejecución
Ejecuta los siguientes comandos en tu terminal para compilar y probar la aplicación en tu entorno local:

1. **Clona este repositorio:**
   ```bash
   git clone https://github.com/soruflorelena/board_scan.git
   ```
   
2. **Navega al directorio del proyecto:**
   ```bash
   cd board_scan
   ```

3. **Descarga e instala las dependencias de Flutter:**
   ```bash
   flutter pub get
   ```

4. **Ejecuta la aplicación** (asegúrate de tener un dispositivo o emulador activo):
   ```bash
   flutter run
   ```

## Arquitectura y Tecnologías
* **Framework:** Flutter / Dart.
* **Estructura del Proyecto:**
  * **Vistas (`/lib/screens/`):** Sistema de navegación principal dividido entre `HomeScreen` para la captura inicial y `ResultsScreen` para el procesamiento y visualización.
  * **Servicios (`/lib/services/`):** 
    * `scanner_service.dart`: Encargado de la lógica de reconocimiento y procesamiento de imágenes.
    * `pdf_service.dart`: Maneja la creación, formateo y guardado del documento final.

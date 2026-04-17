import 'package:path_provider/path_provider.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

class ImageProcessingService {
  static Future<String> procesarParaOcr(String imagePath) async {
    // 1. Cargar imagen en Escala de Grises (para procesar) y a Color (para dibujar)
    cv.Mat srcGray = cv.imread(imagePath, flags: cv.IMREAD_GRAYSCALE);
    cv.Mat srcColor = cv.imread(imagePath, flags: cv.IMREAD_COLOR);

    if (srcGray.isEmpty) return imagePath;

    // 2. Limpieza y Binarización (Paso 1 que ya calibramos)
    cv.Mat blurred = cv.gaussianBlur(srcGray, (5, 5), 0);

    cv.Mat procesada = cv.adaptiveThreshold(
      blurred,
      255,
      cv.ADAPTIVE_THRESH_GAUSSIAN_C,
      cv.THRESH_BINARY_INV, // IMPORTANTE: Cambiamos a INV. OpenCV busca contornos blancos sobre fondo negro.
      55, // Tu bloque calibrado
      10, // Tu constante calibrada
    );

    // Morfología para engrosar trazos de plumón
    cv.Mat kernel = cv.getStructuringElement(cv.MORPH_RECT, (2, 2));
    procesada = cv.dilate(
        procesada, kernel); // Usamos dilate porque invertimos los colores

    // 3. ¡PASO 2! Encontrar Contornos (Agrupaciones)
    // RETR_EXTERNAL ignora huecos dentro de las letras (ej. el centro de la 'O')
    final (contours, _) =
        cv.findContours(procesada, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE);

    // 4. Dibujar cajas alrededor de lo que encontró
    for (int i = 0; i < contours.length; i++) {
      final contour = contours[i];
      final rect = cv.boundingRect(contour);

      // FILTRO DE RUIDO: Ignorar basurita menor a 15x15 píxeles
      if (rect.width > 15 && rect.height > 15) {
        // Dibujamos un rectángulo Verde (B, G, R) de grosor 3
        cv.rectangle(
          srcColor,
          rect,
          cv.Scalar(0, 255, 0, 255),
          thickness: 3,
        );
      }
    }

    // 5. Guardar la imagen a COLOR con las cajas verdes dibujadas
    final tempDir = await getTemporaryDirectory();
    final processedPath =
        '${tempDir.path}/boxes_${DateTime.now().millisecondsSinceEpoch}.jpg';

    cv.imwrite(processedPath, srcColor);

    return processedPath;
  }
}

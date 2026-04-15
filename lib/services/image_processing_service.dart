import 'package:path_provider/path_provider.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

class ImageProcessingService {
  static Future<String> procesarParaOcr(String imagePath) async {
    // 1. Leer la imagen directamente en escala de grises
    cv.Mat src = cv.imread(imagePath, flags: cv.IMREAD_GRAYSCALE);

    if (src.isEmpty) return imagePath;

    // 2. Aplicar desenfoque ligero para eliminar el "polvo" o ruido del borrador
    cv.Mat blurred = cv.gaussianBlur(src, (5, 5), 0);

    // 3. Binarización Adaptativa (La magia para pizarrones)
    cv.Mat procesada = cv.adaptiveThreshold(
      blurred,
      255, // Valor máximo (Blanco)
      cv.ADAPTIVE_THRESH_GAUSSIAN_C, // Método gaussiano para transiciones de luz más suaves
      cv.THRESH_BINARY, // Genera texto negro sobre fondo blanco
      31, // blockSize: Tamaño del cuadrante a evaluar
      15, // C: Constante para ajustar la sensibilidad
    );

    // 4. Guardar la imagen procesada
    final tempDir = await getTemporaryDirectory();
    final processedPath =
        '${tempDir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.jpg';

    cv.imwrite(processedPath, procesada);

    return processedPath;
  }
}

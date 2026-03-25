import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImageProcessingService {
  static Future<String> processForOcr(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return imagePath;

    // Redimensionar si es muy grande
    if (image.width > 2000 || image.height > 2000) {
      image = img.copyResize(
        image,
        width: image.width > image.height ? 2000 : null,
        height: image.height >= image.width ? 2000 : null,
      );
    }

    // Escala de grises
    image = img.grayscale(image);

    // Aumentar contraste
    image = img.adjustColor(image, contrast: 1.8);

    // Nitidez
    image = img.convolution(
      image,
      filter: [0, -1, 0, -1, 5, -1, 0, -1, 0],
      div: 1,
      offset: 0,
    );

    // Guardar imagen procesada
    final tempDir = await getTemporaryDirectory();
    final processedPath =
        '${tempDir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(processedPath).writeAsBytes(img.encodeJpg(image, quality: 95));

    return processedPath;
  }
}

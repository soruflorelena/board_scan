import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class ScannerService {
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  // Cámara
  Future<String?> escanearPizarrones() async {
    DocumentScanner documentScanner = DocumentScanner(
      options: DocumentScannerOptions(
        mode: ScannerMode.filter,
        pageLimit: 10,
      ),
    );

    try {
      debugPrint("Abriendo cámara...");
      final result = await documentScanner.scanDocument();
      final imagenes = result.images;

      if (imagenes == null || imagenes.isEmpty) {
        documentScanner.close();
        return null;
      }

      documentScanner.close();
      return await _procesarListaDeImagenes(imagenes);
    } catch (e) {
      debugPrint("Error en la cámara: $e");
      documentScanner.close();
      return "Error: $e";
    }
  }

  // Seleccionar desde la galería
  Future<String?> seleccionarDeGaleria() async {
    final ImagePicker picker = ImagePicker();
    try {
      debugPrint("Abriendo galería...");
      // Permite seleccionar varias fotos a la vez
      final List<XFile> photos = await picker.pickMultiImage();

      if (photos.isEmpty) return null;

      // Convertimos los archivos XFile a una lista de rutas (String)
      final rutasImagenes = photos.map((e) => e.path).toList();

      return await _procesarListaDeImagenes(rutasImagenes);
    } catch (e) {
      debugPrint("Error en la galería: $e");
      return "Error: $e";
    }
  }

  Future<String> _procesarListaDeImagenes(List<String> rutas) async {
    debugPrint("Procesando ${rutas.length} imágenes con IA...");
    StringBuffer textoFinal = StringBuffer();

    for (int i = 0; i < rutas.length; i++) {
      final inputImage = InputImage.fromFilePath(rutas[i]);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      if (rutas.length > 1) {
        textoFinal.writeln("--- Imagen ${i + 1} ---");
      }

      textoFinal.writeln(recognizedText.text);
      textoFinal.writeln(); // Espacio extra entre textos
    }

    debugPrint("Procesamiento terminado.");
    return textoFinal.toString().trim();
  }

  // Liberamos la memoria cuando cerramos la app
  void dispose() {
    textRecognizer.close();
  }
}

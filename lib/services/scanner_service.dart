import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/foundation.dart';

class ScannerService {
  Future<String?> escanearYLeerTexto() async {
    DocumentScanner documentScanner = DocumentScanner(
      options: DocumentScannerOptions(
        mode: ScannerMode.filter,
        pageLimit: 1,
      ),
    );

    try {
      debugPrint("📸 Abriendo escáner de Google...");
      final result = await documentScanner.scanDocument();

      // TRUCO PRO: Pasamos la lista a una variable local.
      // Así Dart la puede analizar de forma 100% segura sin pedirnos el signo "!"
      final imagenes = result.images;

      // Solo verificamos la variable local
      if (imagenes == null || imagenes.isEmpty) {
        documentScanner.close();
        return null;
      }

      debugPrint("✨ Foto recortada y limpiada con éxito.");

      // Como ya validamos arriba, podemos sacar la primera imagen sin errores
      final imagePath = imagenes.first;

      debugPrint("🧠 Leyendo texto con Inteligencia Artificial...");
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);

      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      await textRecognizer.close();
      documentScanner.close();

      debugPrint("✅ Texto leído: \n${recognizedText.text}");
      return recognizedText.text;
    } catch (e) {
      debugPrint("❌ Error en el escáner: $e");
      documentScanner.close();
      return "Error al procesar: $e";
    }
  }
}

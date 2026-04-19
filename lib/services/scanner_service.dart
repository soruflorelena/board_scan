import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ScannerService {
  Future<String?> escanearYLeerTexto() async {
    // 1. Configuramos el escáner inteligente
    DocumentScanner documentScanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormat: DocumentFormat.jpeg, // Solo queremos la foto limpia
        mode: ScannerMode
            .filter, // Le da al usuario filtros mágicos (Blanco y negro, color mejorado)
        pageLimit: 1, // Escaneamos un pizarrón a la vez
        isGalleryImportAllowed: true, // Permitir subir fotos de la galería
      ),
    );

    try {
      print("📸 Abriendo escáner de Google...");
      // 2. Esto abre la cámara nativa especial. El código se pausa aquí hasta que el usuario tome la foto y la recorte.
      DocumentScanningResult? result = await documentScanner.scanDocument();

      // Si el usuario canceló o cerró la cámara
      if (result == null || result.images.isEmpty) {
        documentScanner.close();
        return null;
      }

      print("✨ Foto recortada y limpiada con éxito.");
      final imagePath = result.images.first;

      // 3. Pasamos la foto limpia al motor de Deep Learning (OCR)
      print("🧠 Leyendo texto con Inteligencia Artificial...");
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);

      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      // 4. Limpiamos la memoria
      await textRecognizer.close();
      documentScanner.close();

      print("✅ Texto leído: \n${recognizedText.text}");
      return recognizedText.text;
    } catch (e) {
      print("❌ Error en el escáner: $e");
      documentScanner.close();
      return "Error al procesar: $e";
    }
  }
}

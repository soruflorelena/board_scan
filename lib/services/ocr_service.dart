import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<OcrResult> extractText(String imagePath) async {
    final inputImage = InputImage.fromFile(File(imagePath));
    final RecognizedText recognizedText =
    await _textRecognizer.processImage(inputImage);

    List<TextBlock> textBlocks = [];
    List<ImageZone> imageZones = [];

    // Obtener tamaño total para detectar zonas sin texto
    double maxBottom = 0;
    double maxRight = 0;

    for (final block in recognizedText.blocks) {
      final rect = block.boundingBox;
      textBlocks.add(TextBlock(
        text: block.text,
        x: rect.left,
        y: rect.top,
        width: rect.width,
        height: rect.height,
      ));
      if (rect.bottom > maxBottom) maxBottom = rect.bottom;
      if (rect.right > maxRight) maxRight = rect.right;
    }

    // Detectar zonas grandes sin texto
    imageZones = _detectImageZones(recognizedText.blocks, maxRight, maxBottom);

    return OcrResult(
      fullText: recognizedText.text,
      textBlocks: textBlocks,
      imageZones: imageZones,
    );
  }

  List<ImageZone> _detectImageZones(
      List<dynamic> blocks, double imageWidth, double imageHeight) {
    List<ImageZone> zones = [];

    // Buscar gaps verticales grandes entre bloques de texto
    if (blocks.isEmpty) return zones;

    List<double> topEdges =
    blocks.map((b) => b.boundingBox.top as double).toList();
    List<double> bottomEdges =
    blocks.map((b) => b.boundingBox.bottom as double).toList();
    topEdges.sort();
    bottomEdges.sort();

    for (int i = 0; i < bottomEdges.length - 1; i++) {
      double gap = topEdges[i + 1] - bottomEdges[i];
      // Si hay un gap mayor a 100px, probablemente hay una gráfica
      if (gap > 100) {
        zones.add(ImageZone(
          y: bottomEdges[i],
          height: gap,
          label: 'Gráfica ${zones.length + 1}',
        ));
      }
    }

    return zones;
  }

  void dispose() {
    _textRecognizer.close();
  }
}

// Modelos de datos
class OcrResult {
  final String fullText;
  final List<TextBlock> textBlocks;
  final List<ImageZone> imageZones;

  OcrResult({
    required this.fullText,
    required this.textBlocks,
    required this.imageZones,
  });
}

class TextBlock {
  final String text;
  final double x, y, width, height;

  TextBlock({
    required this.text,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

class ImageZone {
  final double y;
  final double height;
  final String label;

  ImageZone({
    required this.y,
    required this.height,
    required this.label,
  });
}
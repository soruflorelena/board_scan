import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  // Carga el modelo de ML Kit para letras de alfabeto latino
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<OcrResult> extractText(String imagePath) async {
    final inputImage = InputImage.fromFile(File(imagePath));
    // Pasa la imagen por la Inteligencia Artificial
    final RecognizedText recognizedText =
        await _textRecognizer.processImage(inputImage);

    List<TextBlock> textBlocks = [];

    // Recorre bloque por bloque lo que detectó
    for (final block in recognizedText.blocks) {
      final rect = block.boundingBox;
      textBlocks.add(TextBlock(
        text: block.text,
        x: rect.left,
        y: rect.top,
        width: rect.width,
        height: rect.height,
      ));
    }

    return OcrResult(
      fullText: recognizedText.text,
      textBlocks: textBlocks,
    );
  }

  void dispose() {
    _textRecognizer.close();
  }
}

class OcrResult {
  final String fullText;
  final List<TextBlock> textBlocks;

  OcrResult({
    required this.fullText,
    required this.textBlocks,
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

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class OcrService {
  // ¡OJO! Revisa que esta IP sea la que tiene tu computadora el día de HOY.
  final String _baseUrl = 'http://192.168.1.179:8000'; 

  Future<ResultadoOcr> extraerTexto(String imagePath) async {
    print("📢 [OCR_SERVICE] Iniciando extracción de texto...");
    print("📢 [OCR_SERVICE] Ruta de la imagen: $imagePath");
    
    final uri = Uri.parse('$_baseUrl/procesar-pizarron/');
    print("📢 [OCR_SERVICE] Intentando conectar a: $uri");
    
    final request = http.MultipartRequest('POST', uri);
    final file = await http.MultipartFile.fromPath(
      'file',
      imagePath,
      contentType: MediaType('image', 'jpeg'),
    );
    request.files.add(file);

    try {
      print("📢 [OCR_SERVICE] Enviando petición HTTP al servidor Python...");
      // Le agregamos un límite de tiempo de 10 segundos para que no se quede cargando infinito
      final response = await request.send().timeout(const Duration(seconds: 10));
      
      print("📢 [OCR_SERVICE] ¡Respuesta recibida! Código: ${response.statusCode}");
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(responseBody);
        
        List<TextBlock> textBlocks = (data['blocks'] as List).map((block) {
          return TextBlock(
            text: block['text'],
            x: block['x'].toDouble(),
            y: block['y'].toDouble(),
            width: block['width'].toDouble(),
            height: block['height'].toDouble(),
          );
        }).toList();

        print("📢 [OCR_SERVICE] Texto extraído correctamente.");
        return ResultadoOcr(
          fullText: data['full_text'],
          textBlocks: textBlocks,
        );
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print("❌ [OCR_SERVICE ERROR CRÍTICO]: $e");
      throw Exception('No se pudo conectar al servidor: $e');
    }
  }

  void dispose() {}
}

class ResultadoOcr {
  final String fullText;
  final List<TextBlock> textBlocks;
  ResultadoOcr({required this.fullText, required this.textBlocks});
}

class TextBlock {
  final String text;
  final double x, y, width, height;
  TextBlock({required this.text, required this.x, required this.y, required this.width, required this.height});
}
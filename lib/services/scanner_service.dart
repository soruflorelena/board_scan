import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class ScannerService {
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  Interpreter? _interpreter;
  bool _isModelLoaded = false;

  ScannerService() {
    _initTensorFlow();
  }

  // --- CARGAMOS LA RED NEURONAL A LA MEMORIA ---
  Future<void> _initTensorFlow() async {
    try {
      // Busca el archivo detect.tflite en tu carpeta assets/models/
      _interpreter = await Interpreter.fromAsset('assets/models/detect.tflite');
      _isModelLoaded = true;
      debugPrint("🤖 Modelo TensorFlow Lite cargado exitosamente.");
    } catch (e) {
      debugPrint("❌ Error al cargar modelo TFLite: $e");
      debugPrint(
          "⚠️ Asegúrate de colocar tu archivo detect.tflite en assets/models/");
    }
  }

  Future<ScanResult?> escanearPizarrones() async {
    DocumentScanner documentScanner = DocumentScanner(
      options: DocumentScannerOptions(mode: ScannerMode.filter, pageLimit: 10),
    );

    try {
      final result = await documentScanner.scanDocument();
      final imagenes = result.images;
      if (imagenes == null || imagenes.isEmpty) {
        documentScanner.close();
        return null;
      }
      documentScanner.close();
      return await _procesarConIA(imagenes);
    } catch (e) {
      documentScanner.close();
      return ScanResult(
          texto: "Error: $e", imagenPrevia: null, imagenesDetectadas: []);
    }
  }

  Future<ScanResult?> seleccionarDeGaleria() async {
    final ImagePicker picker = ImagePicker();
    try {
      final List<XFile> photos = await picker.pickMultiImage();
      if (photos.isEmpty) return null;
      final rutasImagenes = photos.map((e) => e.path).toList();
      return await _procesarConIA(rutasImagenes);
    } catch (e) {
      return ScanResult(
          texto: "Error: $e", imagenPrevia: null, imagenesDetectadas: []);
    }
  }

  Future<ScanResult> _procesarConIA(List<String> rutas) async {
    debugPrint("🧠 Procesando ${rutas.length} imágenes con IA TFLite...");

    StringBuffer textoFinal = StringBuffer();
    File? imagenPrevia;
    List<File> imagenesDetectadas = [];

    if (rutas.isNotEmpty) imagenPrevia = File(rutas.first);

    for (int i = 0; i < rutas.length; i++) {
      final inputImage = InputImage.fromFilePath(rutas[i]);
      final recognizedText = await textRecognizer.processImage(inputImage);

      if (rutas.length > 1) textoFinal.writeln("--- Imagen ${i + 1} ---");
      textoFinal.writeln(recognizedText.text);
      textoFinal.writeln();

      // Mandamos la imagen al modelo de TensorFlow
      if (_isModelLoaded && _interpreter != null) {
        final recortes = await _detectarObjetosTFLite(rutas[i]);
        imagenesDetectadas.addAll(recortes);
      } else {
        debugPrint(
            "⚠️ El modelo TFLite no está disponible. Saltando extracción de imagen.");
      }
    }

    return ScanResult(
      texto: textoFinal.toString().trim(),
      imagenPrevia: imagenPrevia,
      imagenesDetectadas: imagenesDetectadas,
    );
  }

  // --- INFERENCIA TENSORFLOW LITE ---
  Future<List<File>> _detectarObjetosTFLite(String rutaImagen) async {
    final List<File> recortesGuardados = [];
    final bytes = await File(rutaImagen).readAsBytes();
    final imagenOriginal = img.decodeImage(bytes);

    if (imagenOriginal == null) return recortesGuardados;

    // 1. PRE-PROCESAMIENTO
    // La mayoría de los modelos móviles aceptan imágenes de 300x300
    const int inputSize = 300;
    final imagenRedimensionada =
        img.copyResize(imagenOriginal, width: inputSize, height: inputSize);

    // Convertimos los píxeles a la matriz plana que TensorFlow entiende [1, 300, 300, 3]
    var inputTensor = List.generate(
      1,
      (i) => List.generate(
        inputSize,
        (y) => List.generate(
          inputSize,
          (x) {
            final pixel = imagenRedimensionada.getPixel(x, y);
            return [
              pixel.r.toDouble() / 255.0,
              pixel.g.toDouble() / 255.0,
              pixel.b.toDouble() / 255.0
            ];
          },
        ),
      ),
    );

    // 2. CONFIGURACIÓN DE LOS TENSORES DE SALIDA (Asumiendo arquitectura estándar SSD)
    // Esto se ajusta dependiendo de la arquitectura de tu .tflite (YOLO, SSD, etc.)
    var outputLocations =
        List.generate(1, (_) => List.generate(10, (_) => List.filled(4, 0.0)));
    var outputClasses = List.generate(1, (_) => List.filled(10, 0.0));
    var outputScores = List.generate(1, (_) => List.filled(10, 0.0));
    var numDetections = List.filled(1, 0.0);

    Map<int, Object> outputs = {
      0: outputLocations,
      1: outputClasses,
      2: outputScores,
      3: numDetections,
    };

    // 3. EJECUTAMOS LA RED NEURONAL
    try {
      _interpreter!.runForMultipleInputs([inputTensor], outputs);
    } catch (e) {
      debugPrint("❌ Error en la inferencia de TFLite: $e");
      return recortesGuardados;
    }

    // 4. POST-PROCESAMIENTO Y RECORTE
    final tempDir = await getTemporaryDirectory();
    int contador = 0;

    for (int i = 0; i < 10; i++) {
      final score = outputScores[0][i];

      // Umbral de confianza: Si la IA está más del 60% segura de que hay una gráfica/dibujo
      if (score > 0.60) {
        // Obtenemos las coordenadas normalizadas [0.0 a 1.0]
        final top = outputLocations[0][i][0];
        final left = outputLocations[0][i][1];
        final bottom = outputLocations[0][i][2];
        final right = outputLocations[0][i][3];

        // Mapeamos a las dimensiones de la imagen original de alta resolución
        int rectLeft = (left * imagenOriginal.width).toInt();
        int rectTop = (top * imagenOriginal.height).toInt();
        int rectWidth = ((right - left) * imagenOriginal.width).toInt();
        int rectHeight = ((bottom - top) * imagenOriginal.height).toInt();

        // Aplicamos un pequeño margen para no cortar los bordes exactos
        final margin = 15;
        rectLeft = (rectLeft - margin).clamp(0, imagenOriginal.width - 1);
        rectTop = (rectTop - margin).clamp(0, imagenOriginal.height - 1);
        rectWidth =
            (rectWidth + margin * 2).clamp(0, imagenOriginal.width - rectLeft);
        rectHeight =
            (rectHeight + margin * 2).clamp(0, imagenOriginal.height - rectTop);

        if (rectWidth > 50 && rectHeight > 50) {
          final recorte = img.copyCrop(
            imagenOriginal,
            x: rectLeft,
            y: rectTop,
            width: rectWidth,
            height: rectHeight,
          );

          final archivo = File(
              "${tempDir.path}/grafica_tflite_${DateTime.now().millisecondsSinceEpoch}_$contador.jpg");
          await archivo.writeAsBytes(img.encodeJpg(recorte, quality: 90));
          recortesGuardados.add(archivo);
          contador++;
        }
      }
    }

    return recortesGuardados;
  }

  void dispose() {
    textRecognizer.close();
    _interpreter?.close();
  }
}

class ScanResult {
  final String texto;
  final File? imagenPrevia;
  final List<File> imagenesDetectadas;

  ScanResult(
      {required this.texto,
      required this.imagenPrevia,
      required this.imagenesDetectadas});
}

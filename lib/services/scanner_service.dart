import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ScanResult {
  final String texto;
  final File? imagenPrevia;
  final List<File> imagenesDetectadas;

  ScanResult({
    required this.texto,
    required this.imagenPrevia,
    required this.imagenesDetectadas,
  });
}

class ScannerService {
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<ScanResult?> escanearPizarrones() async {
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

      return ScanResult(
        texto: "Error: $e",
        imagenPrevia: null,
        imagenesDetectadas: [],
      );
    }
  }

  Future<ScanResult?> seleccionarDeGaleria() async {
    final ImagePicker picker = ImagePicker();

    try {
      debugPrint("Abriendo galería...");
      final List<XFile> photos = await picker.pickMultiImage();

      if (photos.isEmpty) return null;

      final rutasImagenes = photos.map((e) => e.path).toList();
      return await _procesarListaDeImagenes(rutasImagenes);
    } catch (e) {
      debugPrint("Error en la galería: $e");

      return ScanResult(
        texto: "Error: $e",
        imagenPrevia: null,
        imagenesDetectadas: [],
      );
    }
  }

  Future<ScanResult> _procesarListaDeImagenes(List<String> rutas) async {
    debugPrint("Procesando ${rutas.length} imágenes...");

    StringBuffer textoFinal = StringBuffer();
    File? imagenPrevia;
    List<File> imagenesDetectadas = [];

    if (rutas.isNotEmpty) {
      imagenPrevia = File(rutas.first);
    }

    for (int i = 0; i < rutas.length; i++) {
      final inputImage = InputImage.fromFilePath(rutas[i]);
      final recognizedText = await textRecognizer.processImage(inputImage);

      if (rutas.length > 1) {
        textoFinal.writeln("--- Imagen ${i + 1} ---");
      }

      textoFinal.writeln(recognizedText.text);
      textoFinal.writeln();

      final recortes =
      await _extraerRegionesNoTextuales(rutas[i], recognizedText);

      imagenesDetectadas.addAll(recortes);
    }

    return ScanResult(
      texto: textoFinal.toString().trim(),
      imagenPrevia: imagenPrevia,
      imagenesDetectadas: imagenesDetectadas,
    );
  }

  Future<List<File>> _extraerRegionesNoTextuales(
      String rutaImagen,
      RecognizedText recognizedText,
      ) async {
    final List<File> recortesGuardados = [];

    final bytes = await File(rutaImagen).readAsBytes();
    final imagenOriginal = img.decodeImage(bytes);

    if (imagenOriginal == null) return recortesGuardados;

    final ancho = imagenOriginal.width;
    final alto = imagenOriginal.height;

    final procesada = img.grayscale(imagenOriginal);

    // Matriz binaria: true = contenido oscuro, false = fondo claro
    final List<List<bool>> mascara =
    List.generate(alto, (_) => List.filled(ancho, false));

    for (int y = 0; y < alto; y++) {
      for (int x = 0; x < ancho; x++) {
        final pixel = procesada.getPixel(x, y);
        final v = pixel.r.toInt();
        mascara[y][x] = v < 185;
      }
    }

    // Eliminar zonas de texto detectadas por OCR
    for (final block in recognizedText.blocks) {
      final rect = block.boundingBox;

      final left = (rect.left.toInt() - 4).clamp(0, ancho - 1);
      final top = (rect.top.toInt() - 4).clamp(0, alto - 1);
      final right = (rect.right.toInt() + 4).clamp(0, ancho - 1);
      final bottom = (rect.bottom.toInt() + 4).clamp(0, alto - 1);

      for (int y = top; y <= bottom; y++) {
        for (int x = left; x <= right; x++) {
          mascara[y][x] = false;
        }
      }
    }

    // Quitar ruido pequeño
    _limpiarRuido(mascara, ancho, alto);

    // Detectar componentes conectados
    final regiones = _detectarComponentesConectados(mascara, ancho, alto);

    // Unir regiones cercanas
    final regionesFusionadas = _fusionarRegiones(regiones);

    final tempDir = await getTemporaryDirectory();
    int contador = 0;

    for (final r in regionesFusionadas) {
      if (r.width < 80 || r.height < 80) continue;

      final area = r.width * r.height;
      if (area < 12000) continue;

      final proporcion = r.width / r.height;
      if (proporcion < 0.2 || proporcion > 10) continue;

      final margen = 10;
      final x = (r.x - margen).clamp(0, ancho - 1);
      final y = (r.y - margen).clamp(0, alto - 1);
      final right = (r.x + r.width + margen).clamp(0, ancho);
      final bottom = (r.y + r.height + margen).clamp(0, alto);

      final width = right - x;
      final height = bottom - y;

      if (width <= 0 || height <= 0) continue;

      final recorte = img.copyCrop(
        imagenOriginal,
        x: x,
        y: y,
        width: width,
        height: height,
      );

      final archivo = File(
        "${tempDir.path}/grafica_${DateTime.now().millisecondsSinceEpoch}_$contador.jpg",
      );

      await archivo.writeAsBytes(img.encodeJpg(recorte, quality: 90));
      recortesGuardados.add(archivo);
      contador++;
    }

    return recortesGuardados;
  }

  void _limpiarRuido(List<List<bool>> mascara, int ancho, int alto) {
    for (int y = 1; y < alto - 1; y++) {
      for (int x = 1; x < ancho - 1; x++) {
        if (!mascara[y][x]) continue;

        int vecinos = 0;
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            if (mascara[y + dy][x + dx]) vecinos++;
          }
        }

        if (vecinos <= 1) {
          mascara[y][x] = false;
        }
      }
    }
  }

  List<_RegionVisual> _detectarComponentesConectados(
      List<List<bool>> mascara,
      int ancho,
      int alto,
      ) {
    final visitado = List.generate(alto, (_) => List.filled(ancho, false));
    final List<_RegionVisual> regiones = [];

    const direcciones = [
      [1, 0],
      [-1, 0],
      [0, 1],
      [0, -1],
      [1, 1],
      [1, -1],
      [-1, 1],
      [-1, -1],
    ];

    for (int y = 0; y < alto; y++) {
      for (int x = 0; x < ancho; x++) {
        if (!mascara[y][x] || visitado[y][x]) continue;

        int minX = x;
        int maxX = x;
        int minY = y;
        int maxY = y;
        int pixeles = 0;

        final cola = Queue<List<int>>();
        cola.add([x, y]);
        visitado[y][x] = true;

        while (cola.isNotEmpty) {
          final actual = cola.removeFirst();
          final cx = actual[0];
          final cy = actual[1];
          pixeles++;

          if (cx < minX) minX = cx;
          if (cx > maxX) maxX = cx;
          if (cy < minY) minY = cy;
          if (cy > maxY) maxY = cy;

          for (final d in direcciones) {
            final nx = cx + d[0];
            final ny = cy + d[1];

            if (nx < 0 || ny < 0 || nx >= ancho || ny >= alto) continue;
            if (visitado[ny][nx]) continue;
            if (!mascara[ny][nx]) continue;

            visitado[ny][nx] = true;
            cola.add([nx, ny]);
          }
        }

        final width = maxX - minX + 1;
        final height = maxY - minY + 1;

        if (pixeles >= 40) {
          regiones.add(
            _RegionVisual(
              x: minX,
              y: minY,
              width: width,
              height: height,
            ),
          );
        }
      }
    }

    return regiones;
  }

  List<_RegionVisual> _fusionarRegiones(List<_RegionVisual> regiones) {
    if (regiones.isEmpty) return [];

    final List<_RegionVisual> resultado = [];
    final List<_RegionVisual> pendientes = List.from(regiones);

    while (pendientes.isNotEmpty) {
      _RegionVisual base = pendientes.removeAt(0);
      bool fusionado;

      do {
        fusionado = false;

        for (int i = 0; i < pendientes.length; i++) {
          final otra = pendientes[i];

          if (_estanCerca(base, otra)) {
            base = _unir(base, otra);
            pendientes.removeAt(i);
            fusionado = true;
            break;
          }
        }
      } while (fusionado);

      resultado.add(base);
    }

    return resultado;
  }

  bool _estanCerca(_RegionVisual a, _RegionVisual b) {
    const margen = 25;

    final ax1 = a.x;
    final ay1 = a.y;
    final ax2 = a.x + a.width;
    final ay2 = a.y + a.height;

    final bx1 = b.x;
    final by1 = b.y;
    final bx2 = b.x + b.width;
    final by2 = b.y + b.height;

    final cercaX = ax1 <= bx2 + margen && ax2 + margen >= bx1;
    final cercaY = ay1 <= by2 + margen && ay2 + margen >= by1;

    return cercaX && cercaY;
  }

  _RegionVisual _unir(_RegionVisual a, _RegionVisual b) {
    final x1 = a.x < b.x ? a.x : b.x;
    final y1 = a.y < b.y ? a.y : b.y;
    final x2 = (a.x + a.width) > (b.x + b.width)
        ? (a.x + a.width)
        : (b.x + b.width);
    final y2 = (a.y + a.height) > (b.y + b.height)
        ? (a.y + a.height)
        : (b.y + b.height);

    return _RegionVisual(
      x: x1,
      y: y1,
      width: x2 - x1,
      height: y2 - y1,
    );
  }

  void dispose() {
    textRecognizer.close();
  }
}

class _RegionVisual {
  final int x;
  final int y;
  final int width;
  final int height;

  _RegionVisual({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}
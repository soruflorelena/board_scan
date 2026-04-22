import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ScannerService {
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<ScanResult?> escanearPizarrones() async {
    DocumentScanner documentScanner = DocumentScanner(
      options: DocumentScannerOptions(mode: ScannerMode.filter, pageLimit: 10),
    );

    try {
      debugPrint("Abriendo cámara");
      final result = await documentScanner.scanDocument();
      final imagenes = result.images;

      if (imagenes == null || imagenes.isEmpty) {
        documentScanner.close();
        return null;
      }

      documentScanner.close();
      return await _procesarImagenes(imagenes);
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
      return await _procesarImagenes(rutasImagenes);
    } catch (e) {
      return ScanResult(
          texto: "Error: $e", imagenPrevia: null, imagenesDetectadas: []);
    }
  }

  Future<ScanResult> _procesarImagenes(List<String> rutas) async {
    debugPrint("Procesando ${rutas.length} imágenes");

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

      // Llamamos al nuevo motor
      final recortes = await _extraerGraficas(rutas[i], recognizedText);
      imagenesDetectadas.addAll(recortes);
    }

    return ScanResult(
      texto: textoFinal.toString().trim(),
      imagenPrevia: imagenPrevia,
      imagenesDetectadas: imagenesDetectadas,
    );
  }

  // Extrae las gráficas de la imagen
  Future<List<File>> _extraerGraficas(
      String rutaImagen, RecognizedText recognizedText) async {
    final List<File> recortesGuardados = [];
    final bytes = await File(rutaImagen).readAsBytes();
    final imagenOriginal = img.decodeImage(bytes);

    if (imagenOriginal == null) return recortesGuardados;

    final ancho = imagenOriginal.width;
    final alto = imagenOriginal.height;
    final procesada = img.grayscale(imagenOriginal);

    final List<List<bool>> mascara =
        List.generate(alto, (_) => List.filled(ancho, false));

    for (int y = 0; y < alto; y++) {
      for (int x = 0; x < ancho; x++) {
        if (procesada.getPixel(x, y).r < 128) {
          mascara[y][x] = true;
        }
      }
    }

    // Elimina los bordes de la imagen
    int margenBordeX = (ancho * 0.03).toInt();
    int margenBordeY = (alto * 0.03).toInt();
    for (int y = 0; y < alto; y++) {
      for (int x = 0; x < ancho; x++) {
        if (x < margenBordeX ||
            x > ancho - margenBordeX ||
            y < margenBordeY ||
            y > alto - margenBordeY) {
          mascara[y][x] = false;
        }
      }
    }

    // Borrar texto
    for (final block in recognizedText.blocks) {
      final rect = block.boundingBox;
      final left = (rect.left.toInt() - 10).clamp(0, ancho - 1);
      final top = (rect.top.toInt() - 10).clamp(0, alto - 1);
      final right = (rect.right.toInt() + 10).clamp(0, ancho - 1);
      final bottom = (rect.bottom.toInt() + 10).clamp(0, alto - 1);

      for (int y = top; y <= bottom; y++) {
        for (int x = left; x <= right; x++) {
          mascara[y][x] = false;
        }
      }
    }

    // Une las regiones cercanas para formar regiones más grandes
    final regiones = _detectarComponentesConectados(mascara, ancho, alto);
    final regionesFusionadas = _fusionarRegiones(regiones);

    final tempDir = await getTemporaryDirectory();
    int contador = 0;
    final areaTotalImagen = ancho * alto;

    // Filtrado
    for (final r in regionesFusionadas) {
      // Filtrar ruido
      if (r.width < 80 || r.height < 80) continue;

      final area = r.width * r.height;
      if (area < 10000) continue;

      if (area > (areaTotalImagen * 0.70)) continue;

      // Aplicar margen
      final margen = 20;
      final xMin = (r.x - margen).clamp(0, ancho - 1);
      final yMin = (r.y - margen).clamp(0, alto - 1);
      final xMax = (r.x + r.width + margen).clamp(0, ancho);
      final yMax = (r.y + r.height + margen).clamp(0, alto);

      final recorte = img.copyCrop(
        imagenOriginal,
        x: xMin,
        y: yMin,
        width: xMax - xMin,
        height: yMax - yMin,
      );

      final archivo = File(
          "${tempDir.path}/grafica_detectada_${DateTime.now().millisecondsSinceEpoch}_$contador.jpg");
      await archivo.writeAsBytes(img.encodeJpg(recorte, quality: 90));
      recortesGuardados.add(archivo);
      contador++;
    }

    return recortesGuardados;
  }

  // Detecta regiones conectadas
  List<_RegionVisual> _detectarComponentesConectados(
      List<List<bool>> mascara, int ancho, int alto) {
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
      [-1, -1]
    ];

    for (int y = 0; y < alto; y++) {
      for (int x = 0; x < ancho; x++) {
        if (!mascara[y][x] || visitado[y][x]) continue;

        int minX = x, maxX = x, minY = y, maxY = y, pixeles = 0;
        final cola = Queue<List<int>>();
        cola.add([x, y]);
        visitado[y][x] = true;

        while (cola.isNotEmpty) {
          final actual = cola.removeFirst();
          final cx = actual[0], cy = actual[1];
          pixeles++;

          if (cx < minX) minX = cx;
          if (cx > maxX) maxX = cx;
          if (cy < minY) minY = cy;
          if (cy > maxY) maxY = cy;

          for (final d in direcciones) {
            final nx = cx + d[0], ny = cy + d[1];
            // Tolerancia de salto
            if (nx >= 0 && ny >= 0 && nx < ancho && ny < alto) {
              if (!visitado[ny][nx] && mascara[ny][nx]) {
                visitado[ny][nx] = true;
                cola.add([nx, ny]);
              }
            }
          }
        }

        if (pixeles > 100) {
          regiones.add(_RegionVisual(
              x: minX, y: minY, width: maxX - minX, height: maxY - minY));
        }
      }
    }
    return regiones;
  }

  // Junta las regiones que estén cerca para formar una sola región más grande
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
          // Unir elementos que estén separados por hasta 100 píxeles
          if (_estanCerca(base, pendientes[i], 100)) {
            base = _unir(base, pendientes[i]);
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

  // Determina si dos regiones están cerca
  bool _estanCerca(_RegionVisual a, _RegionVisual b, int margen) {
    final cercaX =
        a.x <= (b.x + b.width) + margen && (a.x + a.width) + margen >= b.x;
    final cercaY =
        a.y <= (b.y + b.height) + margen && (a.y + a.height) + margen >= b.y;
    return cercaX && cercaY;
  }

  // Une dos regiones en una sola que las tenga a ambas
  _RegionVisual _unir(_RegionVisual a, _RegionVisual b) {
    final x1 = a.x < b.x ? a.x : b.x;
    final y1 = a.y < b.y ? a.y : b.y;
    final x2 =
        (a.x + a.width) > (b.x + b.width) ? (a.x + a.width) : (b.x + b.width);
    final y2 = (a.y + a.height) > (b.y + b.height)
        ? (a.y + a.height)
        : (b.y + b.height);
    return _RegionVisual(x: x1, y: y1, width: x2 - x1, height: y2 - y1);
  }

  void dispose() {
    textRecognizer.close();
  }
}

// Mostrar el resultado de la foto, con el texto y las imágenes
class ScanResult {
  final String texto;
  final File? imagenPrevia;
  final List<File> imagenesDetectadas;

  ScanResult(
      {required this.texto,
      required this.imagenPrevia,
      required this.imagenesDetectadas});
}

// Clase auxiliar para representar las regiones detectadas en la imagen
class _RegionVisual {
  final int x, y, width, height;
  _RegionVisual(
      {required this.x,
      required this.y,
      required this.width,
      required this.height});
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static Future<Uint8List> _crearDocumentoPdf(
    String texto,
    List<File> imagenes,
  ) async {
    final pdf = pw.Document();
    final List<pw.MemoryImage> imagenesPdf = [];

    for (var archivoImagen in imagenes) {
      final bytes = await archivoImagen.readAsBytes();
      imagenesPdf.add(pw.MemoryImage(bytes));
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Documento Escaneado',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            if (texto.isNotEmpty) ...[
              pw.Text(texto, style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 30),
            ],
            if (imagenesPdf.isNotEmpty) ...[
              pw.Wrap(
                spacing: 20,
                runSpacing: 20,
                children: imagenesPdf.map((img) {
                  return pw.Container(
                    width: 200,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400, width: 1),
                    ),
                    child: pw.Image(img),
                  );
                }).toList(),
              ),
            ],
          ];
        },
      ),
    );

    return await pdf.save();
  }

  static Future<void> compartirPdf({
    required String texto,
    required List<File> imagenes,
  }) async {
    final bytesDelPdf = await _crearDocumentoPdf(texto, imagenes);
    await Printing.sharePdf(
      bytes: bytesDelPdf,
      filename: 'BoardScan_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  // Guarda el archivo en la carpeta pública de Descargas
  static Future<String> descargarPdf({
    required String texto,
    required List<File> imagenes,
  }) async {
    final bytesDelPdf = await _crearDocumentoPdf(texto, imagenes);
    Directory? directorio;

    if (Platform.isAndroid) {
      directorio = Directory('/storage/emulated/0/Download');

      if (!await directorio.exists()) {
        try {
          await directorio.create(recursive: true);
        } catch (e) {
          directorio = await getExternalStorageDirectory();
        }
      }
    } else {
      directorio = await getApplicationDocumentsDirectory();
    }

    if (directorio == null) {
      throw Exception("No se pudo acceder al almacenamiento del dispositivo.");
    }

    // Escribir el archivo en el disco
    final rutaArchivo =
        '${directorio.path}/BoardScan_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final archivo = File(rutaArchivo);
    await archivo.writeAsBytes(bytesDelPdf);

    return rutaArchivo;
  }
}

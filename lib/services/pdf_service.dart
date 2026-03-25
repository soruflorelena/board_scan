import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'ocr_service.dart';

class PdfService {
  static Future<void> generateAndShare({
    required String imagePath,
    required OcrResult ocrResult,
  }) async {
    final pdf = pw.Document();

    // Cargar la imagen del pizarrón
    final imageFile = File(imagePath);
    final imageBytes = await imageFile.readAsBytes();
    final pdfImage = pw.MemoryImage(imageBytes);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          List<pw.Widget> content = [];

          // Título
          content.add(
            pw.Text(
              'Escaneo de Pizarrón',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          );
          content.add(pw.SizedBox(height: 8));

          // Fecha
          content.add(
            pw.Text(
              'Fecha: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: const pw.TextStyle(
                fontSize: 11,
                color: PdfColors.grey600,
              ),
            ),
          );
          content.add(pw.Divider());
          content.add(pw.SizedBox(height: 12));

          // Imagen original del pizarrón
          content.add(
            pw.Text(
              'Imagen original',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          );
          content.add(pw.SizedBox(height: 8));
          content.add(
            pw.Center(
              child: pw.Image(
                pdfImage,
                width: 500,
                fit: pw.BoxFit.contain,
              ),
            ),
          );
          content.add(pw.SizedBox(height: 20));

          // Texto extraído
          if (ocrResult.fullText.isNotEmpty) {
            content.add(pw.Divider());
            content.add(pw.SizedBox(height: 12));
            content.add(
              pw.Text(
                'Texto extraído',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
            content.add(pw.SizedBox(height: 8));

            // Cada bloque de texto como párrafo
            for (final block in ocrResult.textBlocks) {
              content.add(
                pw.Container(
                  width: double.infinity,
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(6),
                    ),
                  ),
                  child: pw.Text(
                    block.text,
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ),
              );
            }
          } else {
            content.add(
              pw.Text(
                'No se detectó texto en la imagen.',
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey600,
                ),
              ),
            );
          }

          // Zonas de imagen detectadas
          if (ocrResult.imageZones.isNotEmpty) {
            content.add(pw.SizedBox(height: 16));
            content.add(pw.Divider());
            content.add(pw.SizedBox(height: 12));
            content.add(
              pw.Text(
                'Zonas gráficas detectadas: ${ocrResult.imageZones.length}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
            content.add(pw.SizedBox(height: 4));
            for (final zone in ocrResult.imageZones) {
              content.add(
                pw.Text(
                  '• ${zone.label} — posición vertical: ${zone.y.toInt()}px',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              );
            }
          }

          return content;
        },
      ),
    );

    // Abrir diálogo para compartir / guardar el PDF
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'pizarron_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}
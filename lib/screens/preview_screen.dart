import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../services/ocr_service.dart';
import '../services/image_processing_service.dart';

class PreviewScreen extends StatefulWidget {
  final List<String> imagePaths;
  const PreviewScreen({super.key, required this.imagePaths});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final OcrService _ocrService = OcrService();
  List<_ImageResult> _results = [];

  @override
  void initState() {
    super.initState();
    // Inicializa el estado para cada imagen seleccionada y arranca el análisis
    _results =
        widget.imagePaths.map((p) => _ImageResult(imagePath: p)).toList();
    _runOcrAll();
  }

  @override
  void dispose() {
    _ocrService.dispose();
    for (final r in _results) r.controller.dispose();
    super.dispose();
  }

  // Pasa imagen por imagen para mejorarla y luego extraer el texto
  Future<void> _runOcrAll() async {
    for (int i = 0; i < _results.length; i++) {
      try {
        final processedPath =
            await ImageProcessingService.processForOcr(_results[i].imagePath);
        final ocr = await _ocrService.extractText(processedPath);
        setState(() {
          _results[i].ocrResult = ocr;
          _results[i].controller.text = ocr.fullText;
          _results[i].isDone = true;
        });
      } catch (e) {
        setState(() {
          _results[i].error = 'Error: $e';
          _results[i].isDone = true;
        });
      }
    }
  }

  // Copia todo el texto extraído al portapapeles
  Future<void> _copyAll() async {
    final allText = _results
        .map((r) => r.controller.text.trim())
        .where((t) => t.isNotEmpty)
        .join('\n\n---\n\n');
    if (allText.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: allText));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Todo copiado'), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Vista previa'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: _copyAll,
            icon: const Icon(Icons.copy, color: Colors.white),
            label: const Text('Copiar todo',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final result = _results[index];
          return Card(
            child: Column(
              children: [
                // Imagen escaneada
                SizedBox(
                    height: 180,
                    width: double.infinity,
                    child:
                        Image.file(File(result.imagePath), fit: BoxFit.cover)),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: !result.isDone
                      // Muestra cargador si aún procesa
                      ? const CircularProgressIndicator()
                      // Muestra el texto cuando termina
                      : TextField(
                          controller: result.controller,
                          maxLines: null,
                          decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Texto extraído...'),
                        ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ImageResult {
  final String imagePath;
  OcrResult? ocrResult;
  final TextEditingController controller = TextEditingController();
  bool isDone = false;
  String? error;
  _ImageResult({required this.imagePath});
}

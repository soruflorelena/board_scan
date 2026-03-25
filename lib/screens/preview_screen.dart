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

  // Una entrada por imagen
  List<_ImageResult> _results = [];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _results =
        widget.imagePaths.map((p) => _ImageResult(imagePath: p)).toList();
    _runOcrAll();
  }

  @override
  void dispose() {
    _ocrService.dispose();
    for (final r in _results) {
      r.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _runOcrAll() async {
    setState(() => _isProcessing = true);
    for (int i = 0; i < _results.length; i++) {
      try {
        final processed =
            await ImageProcessingService.processForOcr(_results[i].imagePath);
        final ocr = await _ocrService.extractText(processed);
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
    setState(() => _isProcessing = false);
  }

  Future<void> _copyAll() async {
    final all = _results
        .map((r) => r.controller.text.trim())
        .where((t) => t.isNotEmpty)
        .join('\n\n---\n\n');
    if (all.isEmpty) {
      _showSnack('No hay texto para copiar', isError: true);
      return;
    }
    await Clipboard.setData(ClipboardData(text: all));
    _showSnack('Todo el texto copiado');
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final doneCount = _results.where((r) => r.isDone).length;
    final total = _results.length;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
            total > 1 ? 'Vista previa ($doneCount/$total)' : 'Vista previa'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          if (doneCount == total)
            TextButton.icon(
              onPressed: _copyAll,
              icon: const Icon(Icons.copy, color: Colors.white, size: 18),
              label: const Text('Copiar todo',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _results.length,
        itemBuilder: (context, index) {
          return _ImageCard(
            result: _results[index],
            index: index,
            total: total,
            onCopy: () async {
              final text = _results[index].controller.text.trim();
              if (text.isEmpty) {
                _showSnack('No hay texto', isError: true);
                return;
              }
              await Clipboard.setData(ClipboardData(text: text));
              _showSnack('Texto de foto ${index + 1} copiado');
            },
          );
        },
      ),
    );
  }
}

// Modelo de resultado por imagen
class _ImageResult {
  final String imagePath;
  OcrResult? ocrResult;
  final TextEditingController controller = TextEditingController();
  bool isDone = false;
  String? error;

  _ImageResult({required this.imagePath});
}

// Card por cada imagen
class _ImageCard extends StatelessWidget {
  final _ImageResult result;
  final int index;
  final int total;
  final VoidCallback onCopy;

  const _ImageCard({
    required this.result,
    required this.index,
    required this.total,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Encabezado ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.indigo,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    total > 1 ? 'Foto ${index + 1}' : 'Foto',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                if (result.isDone && result.error == null)
                  _InfoChip(
                    label:
                        '${result.ocrResult?.textBlocks.length ?? 0} bloques',
                    color: Colors.indigo,
                  ),
              ],
            ),
          ),

          // ── Imagen ──
          ClipRRect(
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: Image.file(
                File(result.imagePath),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // ── Contenido OCR ──
          Padding(
            padding: const EdgeInsets.all(14),
            child: !result.isDone
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: Colors.indigo),
                          SizedBox(height: 10),
                          Text('Extrayendo texto...',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ),
                  )
                : result.error != null
                    ? Text(result.error!,
                        style: const TextStyle(color: Colors.red))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Label
                          const Text(
                            'Texto detectado',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Campo de texto
                          Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(minHeight: 80),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: TextField(
                              controller: result.controller,
                              maxLines: null,
                              style: const TextStyle(fontSize: 13),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'No se detectó texto...',
                                hintStyle: TextStyle(color: Colors.grey),
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Botón copiar individual
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: onCopy,
                              icon: const Icon(Icons.copy, size: 15),
                              label: Text(
                                  total > 1
                                      ? 'Copiar texto de foto ${index + 1}'
                                      : 'Copiar texto',
                                  style: const TextStyle(fontSize: 13)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.indigo,
                                side: const BorderSide(color: Colors.indigo),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }
}

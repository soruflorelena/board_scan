import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/scanner_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScannerService _scannerService = ScannerService();

  String _textoEscaneado = "";
  bool _estaCargando = false;

  File? _imagenPrevia;
  List<File> _imagenesDetectadas = [];

  @override
  void dispose() {
    _scannerService.dispose();
    super.dispose();
  }

  // Función genérica para ejecutar cámara o galería
  void _procesar(Future<ScanResult?> Function() metodoEscaneo) async {
    setState(() {
      _estaCargando = true;
      _textoEscaneado = "";
      _imagenPrevia = null;
      _imagenesDetectadas = [];
    });

    final resultado = await metodoEscaneo();

    setState(() {
      _estaCargando = false;

      if (resultado != null) {
        _textoEscaneado = resultado.texto;
        _imagenPrevia = resultado.imagenPrevia;
        _imagenesDetectadas = resultado.imagenesDetectadas;
      }
    });
  }

  void _copiarTexto() {
    if (_textoEscaneado.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _textoEscaneado));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("¡Texto copiado al portapapeles!"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _buildPreviewImagen() {
    if (_imagenPrevia == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Column(
          children: [
            Icon(Icons.image_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              "Aquí se mostrará la vista previa de la imagen seleccionada",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        _imagenPrevia!,
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildImagenesDetectadas() {
    if (_imagenesDetectadas.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Text(
          "No se detectaron gráficas o dibujos como imágenes.",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _imagenesDetectadas.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _imagenesDetectadas[index],
              width: 160,
              height: 140,
              fit: BoxFit.cover,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text(
          "Board Scan",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Icon(
                      Icons.document_scanner_rounded,
                      size: 50,
                      color: Colors.indigo,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Escáner de pizarrón",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _estaCargando
                                ? null
                                : () => _procesar(
                              _scannerService.escanearPizarrones,
                            ),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text("Cámara"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _estaCargando
                                ? null
                                : () => _procesar(
                              _scannerService.seleccionarDeGaleria,
                            ),
                            icon: const Icon(Icons.photo_library),
                            label: const Text("Galería"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.indigo,
                              side: const BorderSide(
                                color: Colors.indigo,
                                width: 2,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              "Vista previa",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                            const Divider(),
                            _buildPreviewImagen(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              "Gráficas o dibujos detectados",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                            const Divider(),
                            _buildImagenesDetectadas(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Encabezado de la tarjeta
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Texto Resultado",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black54,
                                  ),
                                ),
                                if (_textoEscaneado.isNotEmpty && !_estaCargando)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.copy,
                                      color: Colors.indigo,
                                    ),
                                    onPressed: _copiarTexto,
                                    tooltip: "Copiar texto",
                                  ),
                              ],
                            ),
                            const Divider(),
                            SizedBox(
                              height: 250,
                              child: _estaCargando
                                  ? const Center(
                                child: Column(
                                  mainAxisAlignment:
                                  MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      color: Colors.indigo,
                                    ),
                                    SizedBox(height: 15),
                                    Text(
                                      "Procesando imágenes...",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              )
                                  : SingleChildScrollView(
                                child: SelectableText(
                                  _textoEscaneado.isEmpty
                                      ? "Toma fotos o selecciona imágenes de tu galería para comenzar."
                                      : _textoEscaneado,
                                  style: TextStyle(
                                    fontSize: 16,
                                    height: 1.5,
                                    color: _textoEscaneado.isEmpty
                                        ? Colors.grey
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
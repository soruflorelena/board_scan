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

  @override
  void dispose() {
    _scannerService.dispose();
    super.dispose();
  }

  // Función genérica para ejecutar cámara o galería
  void _procesar(Future<String?> Function() metodoEscaneo) async {
    setState(() {
      _estaCargando = true;
      _textoEscaneado = "";
    });

    final texto = await metodoEscaneo();

    setState(() {
      _estaCargando = false;
      if (texto != null && texto.isNotEmpty) {
        _textoEscaneado = texto;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text("Board Scan",
            style: TextStyle(fontWeight: FontWeight.bold)),
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
                  borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Icon(Icons.document_scanner_rounded,
                        size: 50, color: Colors.indigo),
                    const SizedBox(height: 10),
                    const Text(
                      "Escáner de pizarrón",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _estaCargando
                                ? null
                                : () => _procesar(
                                    _scannerService.escanearPizarrones),
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
                                    _scannerService.seleccionarDeGaleria),
                            icon: const Icon(Icons.photo_library),
                            label: const Text("Galería"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.indigo,
                              side: const BorderSide(
                                  color: Colors.indigo, width: 2),
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
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
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
                                color: Colors.black54),
                          ),
                          if (_textoEscaneado.isNotEmpty && !_estaCargando)
                            IconButton(
                              icon:
                                  const Icon(Icons.copy, color: Colors.indigo),
                              onPressed: _copiarTexto,
                              tooltip: "Copiar texto",
                            )
                        ],
                      ),
                      const Divider(),

                      Expanded(
                        child: _estaCargando
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                        color: Colors.indigo),
                                    SizedBox(height: 15),
                                    Text("Procesando imágenes...",
                                        style: TextStyle(color: Colors.grey)),
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
            ),
          ],
        ),
      ),
    );
  }
}

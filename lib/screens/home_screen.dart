import 'dart:io';
import 'package:flutter/material.dart';
// Importamos tu servicio de escáner
import '../services/scanner_service.dart';
// Importamos tu nuevo servicio de PDF
import '../services/pdf_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScannerService _scannerService = ScannerService();

  // Esta es tu variable maestra donde se guarda todo el resultado
  ScanResult? _resultadoActual;
  bool _estaCargando = false;

  // --- MÉTODOS DE LA CÁMARA Y GALERÍA ---
  Future<void> _escanearConCamara() async {
    setState(() => _estaCargando = true);

    final resultado = await _scannerService.escanearPizarrones();

    setState(() {
      _resultadoActual = resultado;
      _estaCargando = false;
    });
  }

  Future<void> _seleccionarDeGaleria() async {
    setState(() => _estaCargando = true);

    final resultado = await _scannerService.seleccionarDeGaleria();

    setState(() {
      _resultadoActual = resultado;
      _estaCargando = false;
    });
  }

  @override
  void dispose() {
    _scannerService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Barra con los botones del pdf
      appBar: AppBar(
        title: const Text('Board Scan'),
        actions: [
          if (_resultadoActual != null &&
              (_resultadoActual!.texto.isNotEmpty ||
                  _resultadoActual!.imagenesDetectadas.isNotEmpty)) ...[
            // Botón descargar al celular
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Guardar en dispositivo',
              onPressed: () async {
                setState(() => _estaCargando = true);
                try {
                  final ruta = await PdfService.descargarPdf(
                    texto: _resultadoActual!.texto,
                    imagenes: _resultadoActual!.imagenesDetectadas,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('¡PDF guardado con éxito!\nRuta: $ruta'),
                      duration: const Duration(seconds: 4),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Error al descargar: $e'),
                        backgroundColor: Colors.red),
                  );
                } finally {
                  if (mounted) setState(() => _estaCargando = false);
                }
              },
            ),

            // Botón compartir
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Compartir PDF',
              onPressed: () async {
                setState(() => _estaCargando = true);
                try {
                  await PdfService.compartirPdf(
                    texto: _resultadoActual!.texto,
                    imagenes: _resultadoActual!.imagenesDetectadas,
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Error al compartir: $e'),
                        backgroundColor: Colors.red),
                  );
                } finally {
                  if (mounted) setState(() => _estaCargando = false);
                }
              },
            ),
          ]
        ],
      ),

      body: _estaCargando
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Procesando imagen...', style: TextStyle(fontSize: 16)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Botones acciones principales
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _escanearConCamara,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Escanear'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 15),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _seleccionarDeGaleria,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Galería'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Resultados
                  if (_resultadoActual == null)
                    const Center(
                      child: Text(
                        'Toma una foto de un pizarrón o selecciona una de la galería.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                  else ...[
                    if (_resultadoActual!.texto.isNotEmpty)
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '📝 Texto Extraído',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const Divider(),
                              SelectableText(
                                _resultadoActual!.texto,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Tarjeta de imágenes
                    if (_resultadoActual!.imagenesDetectadas.isNotEmpty)
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🖼️ Gráficas o dibujos detectados (${_resultadoActual!.imagenesDetectadas.length})',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const Divider(),
                              const SizedBox(height: 10),
                              // Lista horizontal de recortes
                              SizedBox(
                                height: 250,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _resultadoActual!
                                      .imagenesDetectadas.length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(right: 15.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: Colors.grey.shade300,
                                              width: 2),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: Image.file(
                                            _resultadoActual!
                                                .imagenesDetectadas[index],
                                            height: 240,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_resultadoActual!.texto.isNotEmpty)
                      // Mensaje si encontró texto pero no dibujos
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No se detectaron dibujos o gráficas aisladas en esta imagen.',
                          style: TextStyle(
                              color: Colors.orange,
                              fontStyle: FontStyle.italic),
                        ),
                      ),
                  ]
                ],
              ),
            ),
    );
  }
}

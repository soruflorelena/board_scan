import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'camera_screen.dart';
import 'preview_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Lógica intacta
  Future<void> _openCamera(BuildContext context) async {
    final cameras = await availableCameras();
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(cameras: cameras),
      ),
    );
  }

  // Lógica intacta
  Future<void> _pickFromGallery(BuildContext context) async {
    final picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(
      imageQuality: 90,
    );
    if (images.isEmpty) return;
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreviewScreen(
          imagePaths: images.map((e) => e.path).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fondo con un degradado sutil en lugar de gris sólido
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.indigo.shade50,
              Colors.white,
              Colors.indigo.shade100,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 32.0),
                child: Container(
                  padding: const EdgeInsets.all(32.0),
                  // Tarjeta central blanca con sombra
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigo.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ícono con fondo circular y resplandor
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.indigo.withOpacity(0.15),
                              blurRadius: 15,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.document_scanner_rounded,
                          size: 70,
                          color: Colors.indigo.shade600,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Títulos con mejor tipografía
                      const Text(
                        'Board Scan',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Digitaliza tu pizarrón al instante.\nToma una foto o selecciona imágenes para extraer el texto.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Botones con bordes más redondeados y elevación
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () => _openCamera(context),
                          icon: const Icon(Icons.camera_alt_rounded, size: 22),
                          label: const Text('Tomar Foto',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo.shade600,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: Colors.indigo.withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: () => _pickFromGallery(context),
                          icon:
                              const Icon(Icons.photo_library_rounded, size: 22),
                          label: const Text('Elegir de Galería',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.indigo.shade600,
                            side: BorderSide(
                                color: Colors.indigo.shade200, width: 2),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

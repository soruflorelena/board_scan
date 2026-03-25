import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'preview_screen.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isTakingPhoto = false;
  int _selectedCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // ── Forzamos la orientación horizontal ──
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _initCamera(0);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();

    // ── Restauramos la orientación vertical al salir ──
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera(_selectedCameraIndex);
    }
  }

  Future<void> _initCamera(int index) async {
    if (widget.cameras.isEmpty) return;
    final controller = CameraController(
      widget.cameras[index],
      ResolutionPreset.max, // Máxima resolución para mejor OCR
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await controller.initialize();
      if (!mounted) return;

      await controller.lockCaptureOrientation();

      setState(() {
        _controller = controller;
        _isInitialized = true;
        _selectedCameraIndex = index;
      });
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isTakingPhoto) return;
    setState(() => _isTakingPhoto = true);

    try {
      final XFile photo = await _controller!.takePicture();
      final bytes = await File(photo.path).readAsBytes();
      img.Image? capturedImage = img.decodeImage(bytes);

      if (capturedImage != null) {
        capturedImage = img.bakeOrientation(capturedImage);
        final size = MediaQuery.of(context).size;

        // Dimensiones del marco en pantalla
        final frameW = size.width * 0.70;
        final frameH = size.height * 0.80;
        final frameLeft = (size.width - frameW) / 2 - 40; // Desplazado un poco a la izq para balancear la UI
        final frameTop = (size.height - frameH) / 2;

        // Matemáticas exactas para BoxFit.cover
        final imageRatio = capturedImage.width / capturedImage.height;
        final screenRatio = size.width / size.height;

        double scale;
        double dx = 0;
        double dy = 0;

        if (screenRatio > imageRatio) {
          scale = capturedImage.width / size.width;
          dy = (capturedImage.height - size.height * scale) / 2;
        } else {
          scale = capturedImage.height / size.height;
          dx = (capturedImage.width - size.width * scale) / 2;
        }

        final int cropX = (frameLeft * scale + dx).toInt();
        final int cropY = (frameTop * scale + dy).toInt();
        final int cropW = (frameW * scale).toInt();
        final int cropH = (frameH * scale).toInt();

        img.Image croppedImage = img.copyCrop(
          capturedImage,
          x: cropX,
          y: cropY,
          width: cropW,
          height: cropH,
        );

        final tempDir = await getTemporaryDirectory();
        final croppedFile = File('${tempDir.path}/cropped_board_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await croppedFile.writeAsBytes(img.encodeJpg(croppedImage));

        if (!mounted) return;

        await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PreviewScreen(imagePaths: [croppedFile.path]),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al tomar/recortar foto: $e');
    } finally {
      if (mounted) setState(() => _isTakingPhoto = false);
    }
  }

  void _flipCamera() {
    if (widget.cameras.length < 2) return;
    _initCamera((_selectedCameraIndex + 1) % widget.cameras.length);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // ── Dimensiones del marco ──
    final frameW = size.width * 0.70; // 70% del ancho de la pantalla
    final frameH = size.height * 0.80; // 80% del alto
    final frameLeft = (size.width - frameW) / 2 - 40; // Centrado pero ajustado por el panel derecho
    final frameTop = (size.height - frameH) / 2;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Preview de Cámara ──
          if (_isInitialized && _controller != null)
            Positioned.fill(
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.aspectRatio,
                    height: 1.0,
                    child: CameraPreview(_controller!),
                  ),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // ── Overlay oscuro exterior al marco ──
          _DarkOverlay(
            frameLeft: frameLeft,
            frameTop: frameTop,
            frameWidth: frameW,
            frameHeight: frameH,
          ),

          // ── Marco Verde Central ──
          Positioned(
            left: frameLeft,
            top: frameTop,
            width: frameW,
            height: frameH,
            child: const _GuideFrame(),
          ),

          // ── Textos y Botón Atrás (Izquierda/Arriba) ──
          Positioned(
            top: 16,
            left: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ESCÁNER DE PIZARRÓN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'Alinea para extraer texto OCR',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Instrucción inferior ──
          Positioned(
            bottom: 24,
            left: frameLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Mantén el dispositivo estable y paralelo al pizarrón',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),

          // ── Panel de Controles (Derecha) ──
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 130,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54, // Fondo semitransparente oscuro
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icono decorativo de cámara
                  const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 28),
                  const SizedBox(height: 40),

                  // Disparador principal
                  GestureDetector(
                    onTap: _isTakingPhoto ? null : _takePhoto,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        color: _isTakingPhoto ? Colors.grey : Colors.white24,
                      ),
                      child: _isTakingPhoto
                          ? const Padding(
                        padding: EdgeInsets.all(22),
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                      )
                          : Center(
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Voltear cámara
                  GestureDetector(
                    onTap: _flipCamera,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.15),
                      ),
                      child: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Voltear', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Clases Auxiliares Visuales ──

class _DarkOverlay extends StatelessWidget {
  final double frameLeft, frameTop, frameWidth, frameHeight;
  const _DarkOverlay({
    required this.frameLeft,
    required this.frameTop,
    required this.frameWidth,
    required this.frameHeight,
  });

  @override
  Widget build(BuildContext context) {
    const color = Color(0x99000000); // 60% opacidad
    return Stack(children: [
      Positioned(top: 0, left: 0, right: 0, height: frameTop, child: const ColoredBox(color: color)),
      Positioned(top: frameTop + frameHeight, left: 0, right: 0, bottom: 0, child: const ColoredBox(color: color)),
      Positioned(top: frameTop, left: 0, width: frameLeft, height: frameHeight, child: const ColoredBox(color: color)),
      Positioned(top: frameTop, left: frameLeft + frameWidth, right: 0, height: frameHeight, child: const ColoredBox(color: color)),
    ]);
  }
}

class _GuideFrame extends StatelessWidget {
  const _GuideFrame();

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF4ADE80); // Verde brillante
    const s = 40.0; // Esquinas más largas
    const w = 4.0;  // Esquinas más gruesas
    return Stack(children: [
      // Borde tenue completo
      Positioned.fill(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          ),
        ),
      ),
      // Líneas guías cruzadas (tercios) opcionales
      Positioned.fill(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Container(height: 1, color: Colors.white.withOpacity(0.1)),
            Container(height: 1, color: Colors.white.withOpacity(0.1)),
          ],
        ),
      ),
      Positioned.fill(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Container(width: 1, color: Colors.white.withOpacity(0.1)),
            Container(width: 1, color: Colors.white.withOpacity(0.1)),
          ],
        ),
      ),
      // Esquinas
      Positioned(top: 0, left: 0, child: _CornerWidget(color: color, size: s, width: w, top: true, left: true)),
      Positioned(top: 0, right: 0, child: _CornerWidget(color: color, size: s, width: w, top: true, left: false)),
      Positioned(bottom: 0, left: 0, child: _CornerWidget(color: color, size: s, width: w, top: false, left: true)),
      Positioned(bottom: 0, right: 0, child: _CornerWidget(color: color, size: s, width: w, top: false, left: false)),
    ]);
  }
}

class _CornerWidget extends StatelessWidget {
  final Color color;
  final double size, width;
  final bool top, left;
  const _CornerWidget({
    required this.color,
    required this.size,
    required this.width,
    required this.top,
    required this.left,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(color: color, width: width, top: top, left: left),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double width;
  final bool top, left;
  _CornerPainter({
    required this.color,
    required this.width,
    required this.top,
    required this.left,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;
    final x = left ? 0.0 : size.width;
    final y = top ? 0.0 : size.height;
    final dx = left ? size.width : -size.width;
    final dy = top ? size.height : -size.height;
    canvas.drawLine(Offset(x, y), Offset(x + dx, y), paint);
    canvas.drawLine(Offset(x, y), Offset(x, y + dy), paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}
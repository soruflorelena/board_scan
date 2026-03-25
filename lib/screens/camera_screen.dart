import 'package:flutter/material.dart';
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

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isTakingPhoto = false;
  int _selectedCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera(0);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
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
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await controller.initialize();
      if (!mounted) return;
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
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PreviewScreen(imagePaths: [photo.path]),
        ),
      );
    } catch (e) {
      debugPrint('Error: $e');
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
    final frameW = size.width * 0.85;
    final frameH = frameW * 0.65;
    final frameLeft = (size.width - frameW) / 2;
    final frameTop = (size.height - frameH) / 2 - 20;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Preview sin distorsión ──
            if (_isInitialized && _controller != null)
              Positioned.fill(
                child: LayoutBuilder(
                  // Usamos LayoutBuilder para obtener el tamaño disponible
                  builder: (context, constraints) {
                    return ClipRect(
                      // Evita que la cámara se dibuje fuera de la pantalla
                      child: OverflowBox(
                        alignment: Alignment.center,
                        maxWidth: constraints.maxWidth,
                        // Aquí forzamos a que el alto se adapte a la proporción sin ser infinito
                        maxHeight: constraints.maxWidth /
                            _controller!.value.aspectRatio,
                        child: CameraPreview(_controller!),
                      ),
                    );
                  },
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            // ── Overlay oscuro ──
            _DarkOverlay(
              frameLeft: frameLeft,
              frameTop: frameTop,
              frameWidth: frameW,
              frameHeight: frameH,
            ),

            // ── Marco ──
            Positioned(
              left: frameLeft,
              top: frameTop,
              width: frameW,
              height: frameH,
              child: const _GuideFrame(),
            ),

            // ── Header ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                            'Tomar foto',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Text(
                        'Alinea el pizarrón dentro del marco',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Hint ──
            Positioned(
              top: frameTop + frameH + 12,
              left: 0,
              right: 0,
              child: const Text(
                'Mantén el celular estable y paralelo al pizarrón',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ),

            // ── Controles ──
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 46),
                    // Disparador
                    GestureDetector(
                      onTap: _isTakingPhoto ? null : _takePhoto,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          color: _isTakingPhoto ? Colors.grey : Colors.white,
                        ),
                        child: _isTakingPhoto
                            ? const Padding(
                                padding: EdgeInsets.all(18),
                                child: CircularProgressIndicator(
                                    color: Colors.grey, strokeWidth: 2),
                              )
                            : Container(
                                margin: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    // Voltear
                    GestureDetector(
                      onTap: _flipCamera,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.5),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.flip_camera_ios,
                            color: Colors.white, size: 22),
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
    const color = Color(0x8C000000);
    return Stack(children: [
      Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: frameTop,
          child: const ColoredBox(color: color)),
      Positioned(
          top: frameTop + frameHeight,
          left: 0,
          right: 0,
          bottom: 0,
          child: const ColoredBox(color: color)),
      Positioned(
          top: frameTop,
          left: 0,
          width: frameLeft,
          height: frameHeight,
          child: const ColoredBox(color: color)),
      Positioned(
          top: frameTop,
          left: frameLeft + frameWidth,
          right: 0,
          height: frameHeight,
          child: const ColoredBox(color: color)),
    ]);
  }
}

class _GuideFrame extends StatelessWidget {
  const _GuideFrame();

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF4ADE80);
    const s = 26.0;
    const w = 3.5;
    return Stack(children: [
      Positioned.fill(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.25), width: 1),
          ),
        ),
      ),
      Positioned(
          top: 0,
          left: 0,
          child: _CornerWidget(
              color: color, size: s, width: w, top: true, left: true)),
      Positioned(
          top: 0,
          right: 0,
          child: _CornerWidget(
              color: color, size: s, width: w, top: true, left: false)),
      Positioned(
          bottom: 0,
          left: 0,
          child: _CornerWidget(
              color: color, size: s, width: w, top: false, left: true)),
      Positioned(
          bottom: 0,
          right: 0,
          child: _CornerWidget(
              color: color, size: s, width: w, top: false, left: false)),
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
        painter:
            _CornerPainter(color: color, width: width, top: top, left: left),
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

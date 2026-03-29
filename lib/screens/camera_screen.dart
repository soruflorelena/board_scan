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

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isTakingPhoto = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _initCamera(0);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    super.dispose();
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
      });
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _takePhoto() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isTakingPhoto) return;
    setState(() => _isTakingPhoto = true);

    try {
      final XFile photo = await _controller!.takePicture();
      final bytes = await File(photo.path).readAsBytes();
      img.Image? capturedImage = img.decodeImage(bytes);

      if (capturedImage != null) {
        capturedImage = img.bakeOrientation(capturedImage);
        final size = MediaQuery.of(context).size;

        //Calcular el area de recorte
        final frameH = size.height * 0.70;
        final frameW = frameH * 1.5;
        final frameLeft = (size.width - frameW) / 2;
        final frameTop = (size.height - frameH) / 2;

        final imageRatio = capturedImage.width / capturedImage.height;
        final screenRatio = size.width / size.height;
        double scale, dx = 0, dy = 0;

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

        img.Image croppedImage = img.copyCrop(capturedImage,
            x: cropX, y: cropY, width: cropW, height: cropH);

        // Guardar la imagen recortada
        final tempDir = await getTemporaryDirectory();
        final croppedFile = File(
            '${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await croppedFile.writeAsBytes(img.encodeJpg(croppedImage));

        if (!mounted) return;
        await SystemChrome.setPreferredOrientations(
            [DeviceOrientation.portraitUp]);

        // Navegar a la pantalla de vista previa
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => PreviewScreen(imagePaths: [croppedFile.path])),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isTakingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final frameH = size.height * 0.70;
    final frameW = frameH * 1.5;
    final frameLeft = (size.width - frameW) / 2;
    final frameTop = (size.height - frameH) / 2;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
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

          _DarkOverlay(
              frameLeft: frameLeft,
              frameTop: frameTop,
              frameWidth: frameW,
              frameHeight: frameH),

          // Cuadro verde de guía
          Positioned(
              left: frameLeft,
              top: frameTop,
              width: frameW,
              height: frameH,
              child: const _GuideFrame()),

          // Botón flotante para regresar
          Positioned(
            top: 20,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
              onPressed: () {
                SystemChrome.setPreferredOrientations(
                    [DeviceOrientation.portraitUp]);
                Navigator.pop(context);
              },
            ),
          ),

          // Botón para tomar foto
          Positioned(
            right: 30,
            top: 0,
            bottom: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _isTakingPhoto ? null : _takePhoto,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3)),
                    child: _isTakingPhoto
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Center(
                            child: Container(
                                width: 60,
                                height: 60,
                                decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white))),
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

class _DarkOverlay extends StatelessWidget {
  final double frameLeft, frameTop, frameWidth, frameHeight;
  const _DarkOverlay(
      {required this.frameLeft,
      required this.frameTop,
      required this.frameWidth,
      required this.frameHeight});
  @override
  Widget build(BuildContext context) {
    const color = Color(0x99000000);
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
    return Container(
        decoration: BoxDecoration(
            border: Border.all(color: Colors.greenAccent, width: 2)));
  }
}

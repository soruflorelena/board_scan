import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import '../services/scanner_service.dart';
import '../services/pdf_service.dart';

class ResultsScreen extends StatefulWidget {
  final ScanResult resultadoInicial;

  const ResultsScreen({super.key, required this.resultadoInicial});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final ScannerService _scannerService = ScannerService();
  late ScanResult _resultadoActual;
  bool _estaCargando = false;
  late TextEditingController _textoController;

  // lista mutable para controlar cuáles imágenes se quedan y sus recortes
  List<File> _imagenesDetectadas = [];

  @override
  void initState() {
    super.initState();
    _resultadoActual = widget.resultadoInicial;
    _textoController = TextEditingController(text: _resultadoActual.texto);
    _imagenesDetectadas = List.from(_resultadoActual.imagenesDetectadas);
  }

  Future<void> _escanearConCamara() async {
    setState(() => _estaCargando = true);
    final resultado = await _scannerService.escanearPizarrones();

    if (resultado != null) {
      setState(() {
        _resultadoActual = resultado;
        _textoController.text = resultado.texto;
        _imagenesDetectadas = List.from(resultado.imagenesDetectadas);
      });
    }
    setState(() => _estaCargando = false);
  }

  Future<void> _seleccionarDeGaleria() async {
    setState(() => _estaCargando = true);
    final resultado = await _scannerService.seleccionarDeGaleria();

    if (resultado != null) {
      setState(() {
        _resultadoActual = resultado;
        _textoController.text = resultado.texto;
        _imagenesDetectadas = List.from(resultado.imagenesDetectadas);
      });
    }
    setState(() => _estaCargando = false);
  }

  // función para abrir el editor de recortes en una imagen específica
  // función para abrir el editor de recortes en una imagen específica
  Future<void> _modificarRecorte(int indice) async {
    final archivoActual = _imagenesDetectadas[indice];

    final archivoRecortado = await ImageCropper().cropImage(
      sourcePath: archivoActual.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Modificar recorte',
          toolbarColor: Colors.indigo,
          // Añade esta línea para pintar la barra superior y evitar el choque
          statusBarColor: Colors.indigo.shade900,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Modificar recorte',
        ),
      ],
    );

    if (archivoRecortado != null) {
      setState(() {
        // actualizamos la imagen en la lista con el nuevo recorte
        _imagenesDetectadas[indice] = File(archivoRecortado.path);
      });
    }
  }

  @override
  void dispose() {
    _textoController.dispose();
    _scannerService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Board Scan',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: [
          if (_textoController.text.isNotEmpty ||
              _imagenesDetectadas.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Guardar PDF',
              onPressed: () async {
                setState(() => _estaCargando = true);
                try {
                  final ruta = await PdfService.descargarPdf(
                    texto: _textoController.text,
                    imagenes: _imagenesDetectadas,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Guardado en:\n$ruta'),
                      backgroundColor: Colors.green.shade700,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: colorScheme.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } finally {
                  if (mounted) setState(() => _estaCargando = false);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Compartir',
              onPressed: () async {
                setState(() => _estaCargando = true);
                try {
                  await PdfService.compartirPdf(
                    texto: _textoController.text,
                    imagenes: _imagenesDetectadas,
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: colorScheme.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } finally {
                  if (mounted) setState(() => _estaCargando = false);
                }
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: _estaCargando
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: colorScheme.primary),
                  const SizedBox(height: 24),
                  Text(
                    'Analizando el pizarrón...',
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : _construirPantallaResultados(colorScheme, textTheme),
    );
  }

  Widget _construirPantallaResultados(
      ColorScheme colorScheme, TextTheme textTheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Resultados',
                style:
                    textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: _escanearConCamara,
                    icon: const Icon(Icons.camera_alt_rounded, size: 20),
                    tooltip: 'Escanear otro',
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _seleccionarDeGaleria,
                    icon: const Icon(Icons.photo_library_rounded, size: 20),
                    tooltip: 'Elegir otra',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_resultadoActual.texto.isNotEmpty) ...[
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.text_fields_rounded,
                            color: colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Texto detectado',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _textoController,
                      maxLines: null,
                      minLines: 4,
                      keyboardType: TextInputType.multiline,
                      style: textTheme.bodyLarge?.copyWith(height: 1.5),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Edita aquí el texto detectado...',
                      ),
                    ),
                    const Divider(height: 32),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Texto actualizado.'),
                              backgroundColor: Colors.green.shade700,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: const Text('Confirmar cambios'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (_imagenesDetectadas.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.image_rounded, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Gráficas (${_imagenesDetectadas.length})',
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 240,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _imagenesDetectadas.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Stack(
                      children: [
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: colorScheme.outlineVariant),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.file(
                            _imagenesDetectadas[index],
                            width: 240,
                            height: 240,
                            fit: BoxFit.contain,
                          ),
                        ),
                        // agrupamos los botones de edición y borrado
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Row(
                            children: [
                              // boton para recortar
                              IconButton.filled(
                                style: IconButton.styleFrom(
                                  backgroundColor: colorScheme
                                      .secondaryContainer
                                      .withValues(alpha: 0.9),
                                  foregroundColor:
                                      colorScheme.onSecondaryContainer,
                                ),
                                icon: const Icon(Icons.crop_rounded, size: 20),
                                tooltip: 'Ajustar recorte',
                                onPressed: () => _modificarRecorte(index),
                              ),
                              const SizedBox(width: 8),
                              // boton para eliminar
                              IconButton.filled(
                                style: IconButton.styleFrom(
                                  backgroundColor: colorScheme.errorContainer
                                      .withValues(alpha: 0.9),
                                  foregroundColor: colorScheme.onErrorContainer,
                                ),
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 20),
                                tooltip: 'Quitar del PDF',
                                onPressed: () {
                                  setState(() {
                                    _imagenesDetectadas.removeAt(index);
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Imagen removida del documento.'),
                                      behavior: SnackBarBehavior.floating,
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ] else if (_resultadoActual.texto.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: colorScheme.onSecondaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No hay dibujos o gráficas seleccionadas para este documento.',
                      style: TextStyle(color: colorScheme.onSecondaryContainer),
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

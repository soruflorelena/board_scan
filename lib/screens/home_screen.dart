import 'package:flutter/material.dart';
import '../services/scanner_service.dart';
import '../services/pdf_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScannerService _scannerService = ScannerService();

  ScanResult? _resultadoActual;
  bool _estaCargando = false;

  // inicializa el controlador del texto escaneado
  final TextEditingController _textoController = TextEditingController();

  Future<void> _escanearConCamara() async {
    setState(() => _estaCargando = true);
    final resultado = await _scannerService.escanearPizarrones();

    setState(() {
      _resultadoActual = resultado;
      _textoController.text = resultado?.texto ?? '';
      _estaCargando = false;
    });
  }

  Future<void> _seleccionarDeGaleria() async {
    setState(() => _estaCargando = true);
    final resultado = await _scannerService.seleccionarDeGaleria();

    setState(() {
      _resultadoActual = resultado;
      _textoController.text = resultado?.texto ?? '';
      _estaCargando = false;
    });
  }

  @override
  void dispose() {
    _textoController.dispose();
    _scannerService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // extrae el tema actual para mantener consistencia de colores
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
          // muestra opciones de guardado solo si hay datos
          if (_resultadoActual != null &&
              (_textoController.text.isNotEmpty ||
                  _resultadoActual!.imagenesDetectadas.isNotEmpty)) ...[
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Guardar PDF',
              onPressed: () async {
                setState(() => _estaCargando = true);
                try {
                  final ruta = await PdfService.descargarPdf(
                    texto: _textoController.text,
                    imagenes: _resultadoActual!.imagenesDetectadas,
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
                    imagenes: _resultadoActual!.imagenesDetectadas,
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
          : _resultadoActual == null
              ? _construirPantallaInicio(colorScheme, textTheme)
              : _construirPantallaResultados(colorScheme, textTheme),
    );
  }

  // dibuja la pantalla principal centrada cuando no hay escaneos
  Widget _construirPantallaInicio(
      ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // icono decorativo principal
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.document_scanner_rounded,
                size: 80,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Escanea tu pizarrón',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Digitaliza tus apuntes y gráficas para convertirlos en PDF en segundos.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),

            // botones de captura centrados y amplios
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _escanearConCamara,
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text(
                  'Abrir cámara',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.tonalIcon(
                onPressed: _seleccionarDeGaleria,
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text(
                  'Subir desde galería',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // dibuja la vista de tarjetas una vez que hay resultados
  Widget _construirPantallaResultados(
      ColorScheme colorScheme, TextTheme textTheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // fila superior con título y botones compactos
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

          // editor de texto extraído
          if (_resultadoActual!.texto.isNotEmpty) ...[
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

          // visor de gráficas detectadas
          if (_resultadoActual!.imagenesDetectadas.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.image_rounded, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Gráficas (${_resultadoActual!.imagenesDetectadas.length})',
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
                itemCount: _resultadoActual!.imagenesDetectadas.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.file(
                        _resultadoActual!.imagenesDetectadas[index],
                        width: 240,
                        fit: BoxFit.contain,
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else if (_resultadoActual!.texto.isNotEmpty)
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
                      'No se detectaron dibujos aislados en esta imagen.',
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

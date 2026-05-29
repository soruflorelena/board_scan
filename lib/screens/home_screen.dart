import 'package:flutter/material.dart';
import '../services/scanner_service.dart';
import 'results_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScannerService _scannerService = ScannerService();
  bool _estaCargando = false;

  Future<void> _escanearConCamara() async {
    setState(() => _estaCargando = true);
    final resultado = await _scannerService.escanearPizarrones();

    setState(() => _estaCargando = false);

    if (resultado != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultsScreen(resultadoInicial: resultado),
        ),
      );
    }
  }

  Future<void> _seleccionarDeGaleria() async {
    setState(() => _estaCargando = true);
    final resultado = await _scannerService.seleccionarDeGaleria();

    setState(() => _estaCargando = false);

    if (resultado != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultsScreen(resultadoInicial: resultado),
        ),
      );
    }
  }

  @override
  void dispose() {
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
          : _construirPantallaInicio(colorScheme, textTheme),
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
}

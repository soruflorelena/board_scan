import 'package:flutter/material.dart';
import '../services/scanner_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String textoEscaneado = "Toca el botón para escanear el pizarrón";
  bool estaCargando = false;

  void _iniciarEscaneo() async {
    setState(() {
      estaCargando = true;
    });

    final scanner = ScannerService();
    final texto = await scanner.escanearYLeerTexto();

    setState(() {
      estaCargando = false;
      if (texto != null) {
        textoEscaneado = texto;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Board Scan")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            ElevatedButton.icon(
              onPressed: estaCargando ? null : _iniciarEscaneo,
              icon: Icon(Icons.camera_alt),
              label: Text("Escanear Pizarrón"),
            ),
            SizedBox(height: 20),
            if (estaCargando) Center(child: CircularProgressIndicator()),
            if (!estaCargando)
              SelectableText(
                textoEscaneado,
                style: TextStyle(fontSize: 16),
              ),
          ],
        ),
      ),
    );
  }
}

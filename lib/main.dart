import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Board Scan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Aquí generamos la paleta completa basada en tu color #6B0000
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0x7EA67B),
          brightness: Brightness
              .light, // puedes cambiar a dark si prefieres modo oscuro
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

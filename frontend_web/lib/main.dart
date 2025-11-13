import 'package:flutter/material.dart';
import 'package:frontend_web/features/auth/screens/login_screen.dart'; // Importa tu pantalla de login

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Punto de Venta',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F6F8),
      ),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
import 'package:flutter/material.dart';
import 'package:frontend_web/features/auth/controllers/auth_controller.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nombreUsuarioController = TextEditingController();
  final _accesoController = TextEditingController();
  final _contrasenaController = TextEditingController();
  String _mensajeRespuesta = '';
  final AuthController _auth = AuthController();

  Future<void> _registrarUsuario() async {
    final success = await _auth.registrarUsuario(
      nombreUsuario: _nombreUsuarioController.text.trim(),
      nombreAcceso: _accesoController.text.trim(),
      contrasena: _contrasenaController.text,
      idRol: 1,
    );

    setState(() => _mensajeRespuesta = _auth.mensaje);

    if (success && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Nuevo Usuario'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: _nombreUsuarioController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre Completo',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _accesoController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de Acceso (login)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_circle),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _contrasenaController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _registrarUsuario,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo[600],
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: const Text('Registrar'),
                ),
                const SizedBox(height: 24),
                Text(
                  _mensajeRespuesta,
                  style: TextStyle(
                    color: _mensajeRespuesta.startsWith('Error')
                        ? Colors.red
                        : Colors.green,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nombreUsuarioController.dispose();
    _accesoController.dispose();
    _contrasenaController.dispose();
    _auth.dispose();
    super.dispose();
  }
}
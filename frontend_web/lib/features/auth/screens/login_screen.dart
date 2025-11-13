import 'package:flutter/material.dart';
import 'package:frontend_web/features/home/controllers/home_controller.dart';
import 'package:frontend_web/features/auth/controllers/auth_controller.dart';
import 'package:frontend_web/features/auth/screens/register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _accesoController = TextEditingController();
  final _contrasenaController = TextEditingController();
  String _mensajeRespuesta = '';
  final AuthController _auth = AuthController();

  Future<void> _iniciarSesion() async {
    // delegar al controller
    final success = await _auth.iniciarSesion(_accesoController.text.trim(), _contrasenaController.text);
    setState(() => _mensajeRespuesta = _auth.mensaje);

    if (success && mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Iniciar Sesión', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 24),
                TextField(
                  controller: _accesoController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de Acceso',
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
                  onPressed: _iniciarSesion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo[600],
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: const Text('Entrar'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    // Navegar a la pantalla de Registro
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegistrationScreen()),
                    );
                  },
                  child: const Text('¿No tienes cuenta? Regístrate aquí'),
                ),
                const SizedBox(height: 24),
                Text(
                  _mensajeRespuesta,
                  style: TextStyle(
                    color: _mensajeRespuesta.startsWith('Error') ? Colors.red : Colors.green,
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
    _accesoController.dispose();
    _contrasenaController.dispose();
    _auth.dispose();
    super.dispose();
  }
}
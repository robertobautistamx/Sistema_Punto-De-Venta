import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String _baseUrl = 'http://localhost:3000/api';

class AuthController extends ChangeNotifier {
	String mensaje = '';
	bool cargando = false;

	Future<bool> iniciarSesion(String nombreAcceso, String contrasena) async {
		cargando = true;
		mensaje = 'Iniciando sesión...';
		notifyListeners();

		try {
			final response = await http.post(
				Uri.parse('$_baseUrl/login'),
				headers: {'Content-Type': 'application/json; charset=UTF-8'},
				body: json.encode({'nombre_acceso': nombreAcceso, 'contrasena': contrasena}),
			);

			final responseData = json.decode(response.body);

			if (response.statusCode == 200) {
				// Guardar token y datos de usuario
				final prefs = await SharedPreferences.getInstance();
				await prefs.setString('token', responseData['token']);
				await prefs.setString('usuario_nombre', responseData['usuario']['nombre']);
				await prefs.setString('usuario_rol', responseData['usuario']['rol']);

				mensaje = '¡Bienvenido!';
				cargando = false;
				notifyListeners();
				return true;
			} else {
				mensaje = 'Error: ${responseData['error'] ?? 'Respuesta inesperada'}';
				cargando = false;
				notifyListeners();
				return false;
			}
		} catch (e) {
			mensaje = 'Error de conexión: $e';
			cargando = false;
			notifyListeners();
			return false;
		}
	}

	Future<bool> registrarUsuario({
		required String nombreUsuario,
		required String nombreAcceso,
		required String contrasena,
		int idRol = 1,
		String? correo,
		String? telefono,
	}) async {
		cargando = true;
		mensaje = 'Registrando...';
		notifyListeners();

		try {
			final body = {
				'nombre_usuario': nombreUsuario,
				'nombre_acceso': nombreAcceso,
				'contrasena': contrasena,
				'id_rol': idRol,
			};

			if (correo != null) body['correo'] = correo;
			if (telefono != null) body['telefono'] = telefono;

			final response = await http.post(
				Uri.parse('$_baseUrl/register'),
				headers: {'Content-Type': 'application/json; charset=UTF-8'},
				body: json.encode(body),
			);

			final responseData = json.decode(response.body);

			if (response.statusCode == 201) {
				mensaje = '¡Éxito! Usuario registrado.';
				cargando = false;
				notifyListeners();
				return true;
			} else {
				mensaje = 'Error: ${responseData['detalle'] ?? responseData['error'] ?? 'Respuesta inesperada'}';
				cargando = false;
				notifyListeners();
				return false;
			}
		} catch (e) {
			mensaje = 'Error de conexión: $e';
			cargando = false;
			notifyListeners();
			return false;
		}
	}
}

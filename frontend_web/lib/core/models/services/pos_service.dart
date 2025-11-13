// ignore_for_file: prefer_interpolation_to_compose_strings

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend_web/core/models/producto_model.dart'; // Tu modelo

class PosService {
  final String _baseUrl = 'http://localhost:3000/api';

  // funcion privada para obtener el token
  Future<String?> _getToken() async {
    final prefs=await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Lista de todos los productos
  Future<List<Producto>> getProductos() async {
    final token=await _getToken();
    if (token==null) throw Exception('No autenticado. Token nulo.');

    // Preferimos obtener los productos junto con la informacion de inventario
    // usando el endpoint paginado /api/inventario para reflejar existencia_actual.
    final response=await http.get(
      Uri.parse('$_baseUrl/inventario?page=1&limit=100'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode==200) {
      final decoded=json.decode(response.body);
      // El endpoint devuelve { page, limit, total, items }
      final List<dynamic> items=decoded is List ? decoded : (decoded['items'] as List<dynamic>);
      return items.map((item) => Producto.fromJson(item as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Error al cargar productos: ${response.body}');
    }
  }

  //2. Enviar la venta final al backend
  // METODOS DE PAGO: 'Efectivo', 'Tarjeta', 'Mixto' pendiente , falta tarjeta y mixo
  Future<bool> crearVenta({
    required double total,
    required String metodoPago,
    required List<Map<String, dynamic>> detalle,
    int? idCliente,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('No autenticado. Token nulo.');

    // Preparamos el (body) que espera el endpoint /api/ventas
    final Map<String, dynamic> body = {
      'total': total,
      'metodo_pago': metodoPago,
      'detalle': detalle, // lista de mapas (carrito)
      'id_cliente': idCliente,
    };

    final response = await http.post(
      Uri.parse('$_baseUrl/ventas'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(body),
    );
    return response.statusCode==201; //exito
  }

  //Registrar una entrada (compra)
  Future<bool> crearEntrada({
    required double totalEntrada,
    required List<Map<String, dynamic>> detalle,
    int? idProveedor,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('No autenticado. Token nulo.');

    final Map<String, dynamic> body = {
      'total_entrada': totalEntrada,
      'detalle': detalle,
      'id_proveedor': idProveedor,
    };

    final response = await http.post(
      Uri.parse('$_baseUrl/entradas'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(body),
    );

    return response.statusCode == 201;
  }

  // 4. clientes
  Future<Map<String, dynamic>> getClientes({int page = 1, int limit = 50, String? search}) async {
    final token = await _getToken();
    if (token == null) throw Exception('No autenticado.');

    final params = '?page=$page&limit=$limit' + (search != null ? '&search=${Uri.encodeComponent(search)}' : '');
    final response = await http.get(Uri.parse('$_baseUrl/clientes$params'), headers: {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Error al obtener clientes: ${response.body}');
  }

  Future<bool> crearCliente({required String nombreCliente, String? direccion, String? telefono, String? email, String? rfc, String? cp}) async {
    final token = await _getToken();
    if (token == null) throw Exception('No autenticado.');

    final body = {
      'nombre_cliente': nombreCliente,
      'direccion': direccion,
      'telefono': telefono,
      'email': email,
      'rfc': rfc,
      'cp': cp,
    };

    final response = await http.post(Uri.parse('$_baseUrl/clientes'), headers: {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    }, body: json.encode(body));

    return response.statusCode == 201;
  }

  // 5. proveedores
  Future<Map<String, dynamic>> getProveedores({int page = 1, int limit = 50, String? search}) async {
    final token = await _getToken();
    if (token == null) throw Exception('No autenticado.');

    final params = '?page=$page&limit=$limit' + (search != null ? '&search=${Uri.encodeComponent(search)}' : '');
    final response = await http.get(Uri.parse('$_baseUrl/proveedores$params'), headers: {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Error al obtener proveedores: ${response.body}');
  }

  Future<bool> crearProveedor({required String nombreProveedor, String? nombreEmpresa, String? telefono, String? direccion, String? rfc, String? correo}) async {
    final token = await _getToken();
    if (token == null) throw Exception('No autenticado.');

    final body = {
      'nombre_proveedor': nombreProveedor,
      'nombre_empresa': nombreEmpresa,
      'telefono': telefono,
      'direccion': direccion,
      'rfc': rfc,
      'correo': correo,
    };

    final response = await http.post(Uri.parse('$_baseUrl/proveedores'), headers: {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    }, body: json.encode(body));

    return response.statusCode == 201;
  }

  // 6. historial de ventas
  Future<Map<String, dynamic>> getVentasHistory({int page = 1, int limit = 50, int? idCliente, DateTime? fechaFrom, DateTime? fechaTo}) async {
    final token = await _getToken();
    if (token == null) throw Exception('No autenticado.');

    final params = StringBuffer('?page=$page&limit=$limit');
    if (idCliente != null) params.write('&id_cliente=$idCliente');
    if (fechaFrom != null) params.write('&fecha_from=${Uri.encodeComponent(fechaFrom.toIso8601String())}');
    if (fechaTo != null) params.write('&fecha_to=${Uri.encodeComponent(fechaTo.toIso8601String())}');

    final response = await http.get(Uri.parse('$_baseUrl/ventas/history${params.toString()}'), headers: {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 200) return json.decode(response.body) as Map<String, dynamic>;
    throw Exception('Error al obtener historial de ventas: ${response.body}');
  }

  // 7. actualizar inventario (ajuste manual)
  Future<bool> updateInventario({required int idProducto, required int existenciaActual, String? observaciones}) async {
    final token = await _getToken();
    if (token == null) throw Exception('No autenticado.');

    final body = {
      'existencia_actual': existenciaActual,
      'observaciones': observaciones,
    };

    final response = await http.patch(Uri.parse('$_baseUrl/inventario/$idProducto'), headers: {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    }, body: json.encode(body));

    return response.statusCode == 200;
  }

  // 8. categorias / marcas
  Future<List<dynamic>> getCategorias() async {
    final token = await _getToken();
    if (token == null) throw Exception('No autenticado.');
    final response = await http.get(Uri.parse('$_baseUrl/categorias'), headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) return json.decode(response.body) as List<dynamic>;
    throw Exception('Error al obtener categorias: ${response.body}');
  }

  Future<bool> crearCategoria({required String nombreCategoria}) async {
    final token = await _getToken();
    if (token == null) throw Exception('No autenticado.');
    final body = {'nombre_categoria': nombreCategoria};
    final response = await http.post(Uri.parse('$_baseUrl/categorias'), headers: {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    }, body: json.encode(body));

    return response.statusCode == 201;
  }

  Future<bool> actualizarCategoria({required int idCategoria, required String nombreCategoria}) async {
    final token = await _getToken();
    if (token == null) throw Exception('No autenticado.');
    final body = {'nombre_categoria': nombreCategoria};
    final response = await http.put(Uri.parse('$_baseUrl/categorias/$idCategoria'), headers: {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    }, body: json.encode(body));

    return response.statusCode == 200;
  }

  Future<bool> eliminarCategoria({required int idCategoria}) async {
    final token = await _getToken();
    if (token == null) throw Exception('No autenticado.');
    final response = await http.delete(Uri.parse('$_baseUrl/categorias/$idCategoria'), headers: {
      'Authorization': 'Bearer $token',
    });

    return response.statusCode == 200;
  }

  Future<List<dynamic>> getMarcas() async {
    final token = await _getToken();
    if (token == null) throw Exception('No autenticado.');
    final response = await http.get(Uri.parse('$_baseUrl/marcas'), headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) return json.decode(response.body) as List<dynamic>;
    throw Exception('Error al obtener marcas: ${response.body}');
  }

  // 7. bitacora y movimientos
  Future<Map<String, dynamic>> getBitacora({int page = 1, int limit = 50, String? nombreTabla, String? tipoOperacion, DateTime? fechaFrom, DateTime? fechaTo}) async {
    final token = await _getToken();
    if (token == null) throw Exception('No autenticado.');

    final params = StringBuffer('?page=$page&limit=$limit');
    if (nombreTabla != null) params.write('&nombre_tabla=${Uri.encodeComponent(nombreTabla)}');
    if (tipoOperacion != null) params.write('&tipo_operacion=${Uri.encodeComponent(tipoOperacion)}');
    if (fechaFrom != null) params.write('&fecha_from=${Uri.encodeComponent(fechaFrom.toIso8601String())}');
    if (fechaTo != null) params.write('&fecha_to=${Uri.encodeComponent(fechaTo.toIso8601String())}');

    final response = await http.get(Uri.parse('$_baseUrl/bitacora${params.toString()}'), headers: {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 200) return json.decode(response.body) as Map<String, dynamic>;
    throw Exception('Error al obtener bitacora: ${response.body}');
  }

  Future<Map<String, dynamic>> getInventarioMovimientos({int page = 1, int limit = 50, int? idProducto, String? tipo, DateTime? fechaFrom, DateTime? fechaTo}) async {
    final token = await _getToken();
    if (token == null) throw Exception('No autenticado.');

    final params = StringBuffer('?page=$page&limit=$limit');
    if (idProducto != null) params.write('&id_producto=$idProducto');
    if (tipo != null) params.write('&tipo=${Uri.encodeComponent(tipo)}');
    if (fechaFrom != null) params.write('&fecha_from=${Uri.encodeComponent(fechaFrom.toIso8601String())}');
    if (fechaTo != null) params.write('&fecha_to=${Uri.encodeComponent(fechaTo.toIso8601String())}');

    final response = await http.get(Uri.parse('$_baseUrl/inventario/movimientos${params.toString()}'), headers: {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 200) return json.decode(response.body) as Map<String, dynamic>;
    throw Exception('Error al obtener movimientos de inventario: ${response.body}');
  }
}
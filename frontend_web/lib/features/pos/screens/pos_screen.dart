// lib/features/pos/screens/pos_screen.dart
// ignore_for_file: deprecated_member_use, unnecessary_import
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend_web/core/models/cart_item_model.dart';
// Modelos y Servicios
import 'package:frontend_web/core/models/producto_model.dart';
import 'package:frontend_web/core/models/services/pos_service.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  // --- Estado de la Pantalla ---
  final PosService _posService = PosService();
  final TextEditingController _searchController = TextEditingController();

  // Listas
  List<Producto> _listaDeProductos = []; // La lista maestra
  List<Producto> _productosFiltrados = []; // La lista para la UI
  final List<CartItem> _carrito = []; // El carrito de compras

  // Banderas de estado
  bool _isLoading = true;
  String _mensajeError = '';

  @override
  void initState() {
    super.initState();
    _cargarProductos();
    _searchController.addListener(_filtrarProductos);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- LÓGICA DE DATOS ---

  /// Carga la lista de productos desde la API
  Future<void> _cargarProductos() async {
    setState(() {
      _isLoading = true;
      _mensajeError = '';
    });
    try {
      final productos = await _posService.getProductos();
      setState(() {
        // Asegurarnos de respetar el flag `activo` (aunque el SP ya filtra)
        _listaDeProductos = productos.where((p) => p.activo).toList();
        _productosFiltrados = _listaDeProductos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _mensajeError = 'Error al cargar productos: ${e.toString()}';
      });
    }
  }

  /// Filtra la lista de productos basado en el buscador
  void _filtrarProductos() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _productosFiltrados = _listaDeProductos.where((p) {
        final nombre = p.nombreProducto.toLowerCase();
        final codigo = p.codigoProducto.toLowerCase();
        return nombre.contains(query) || codigo.contains(query);
      }).toList();
    });
  }

  /// Añade un producto al carrito
  void _agregarAlCarrito(Producto producto) {
    setState(() {
      // 1. Revisar si ya está en el carrito
      final itemExistente = _carrito.indexWhere(
        (item) => item.producto.idProducto == producto.idProducto,
      );

      if (itemExistente != -1) {
        // 2. Si existe, incrementar cantidad (con tope de stock)
        final item = _carrito[itemExistente];
        if (item.cantidad < producto.stock) {
          item.incrementar();
        } else {
          _mostrarErrorSnackBar('No hay más stock disponible para este producto.');
        }
      } else {
        // 3. Si no existe y hay stock, añadirlo
        if (producto.stock > 0) {
          _carrito.add(CartItem(producto: producto));
        } else {
          _mostrarErrorSnackBar('Producto sin stock.');
        }
      }
    });
  }

  /// Remueve un item del carrito
  void _removerDelCarrito(int index) {
    setState(() {
      _carrito.removeAt(index);
    });
  }

  /// Calcula el total del carrito
  double _calcularTotal() {
    return _carrito.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  /// Muestra un diálogo de confirmación y procesa el pago
  Future<void> _cobrar() async {
    if (_carrito.isEmpty) {
      _mostrarErrorSnackBar('El carrito está vacío.');
      return;
    }

    // 1. Mostrar diálogo de confirmación
    final bool? confirmado = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Venta'),
        content: Text(
          'El total es: \$${_calcularTotal().toStringAsFixed(2)}. ¿Proceder con el pago? (Método: Efectivo)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    // 2. Preparar los datos para la API
    final total = _calcularTotal();
    final metodoPago = 'Efectivo'; 

    // Formatear el carrito al List<Map> que espera el backend
    final List<Map<String, dynamic>> detalleParaApi = _carrito.map((item) {
      return {
        'id_producto': item.producto.idProducto,
        'cantidad': item.cantidad,
        'precio_unitario': item.producto.precioVenta,
        // Usamos el precio_compra del producto, o 0 si es nulo
        'costo_unitario': item.producto.precioCompra ?? 0.0,
        'subtotal': item.subtotal,
      };
    }).toList();

    // 3. Llamar al servicio
    try {
      final exito = await _posService.crearVenta(
        total: total,
        metodoPago: metodoPago,
        detalle: detalleParaApi,
      );

      if (exito) {
        // 4. ¡Éxito! Limpiar todo
        setState(() {
          _carrito.clear();
          _searchController.clear();
        });
        // Recargar productos para actualizar el stock
        await _cargarProductos();
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Venta registrada con éxito!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        _mostrarErrorSnackBar('Error en el servidor al crear la venta.');
      }
    } catch (e) {
      _mostrarErrorSnackBar('Error: ${e.toString()}');
    }
  }

  void _mostrarErrorSnackBar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
      ),
    );
  }

  // --- INTERFAZ DE USUARIO ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Punto de Venta'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar Productos',
            onPressed: _cargarProductos,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mensajeError.isNotEmpty
              ? Center(child: Text(_mensajeError, style: const TextStyle(color: Colors.red)))
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Columna Izquierda: Productos ---
                    _buildListaProductos(),

                    // --- Columna Derecha: Carrito ---
                    _buildCarrito(),
                  ],
                ),
    );
  }

  /// El widget de la lista de productos (izquierda)
  Widget _buildListaProductos() {
    return Expanded(
      flex: 2, // Ocupa 2/3 de la pantalla
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar producto por nombre o código',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _productosFiltrados.length,
              itemBuilder: (context, index) {
                final producto = _productosFiltrados[index];
                final hayStock = producto.stock > 0;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ListTile(
                    leading: producto.urlImagen != null && producto.urlImagen!.isNotEmpty
                        ? CircleAvatar(
                            backgroundImage: NetworkImage(producto.urlImagen!),
                            radius: 24,
                            backgroundColor: Colors.grey[200],
                          )
                        : CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.grey[200],
                            child: const Icon(Icons.image_not_supported, color: Colors.grey),
                          ),
                    title: Text(producto.nombreProducto),
                    subtitle: Row(
                      children: [
                        Expanded(child: Text('Código: ${producto.codigoProducto}')),
                        const SizedBox(width: 8),
                        Text('Stock: ${producto.stock}'),
                        const SizedBox(width: 6),
                        // Indicador de stock bajo respecto a stockMinimo
                        if (producto.stock <= producto.stockMinimo)
                          const Padding(
                            padding: EdgeInsets.only(left: 6.0),
                            child: Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '\$${producto.precioVenta.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: Icon(Icons.add_shopping_cart,
                              color: hayStock ? Colors.indigo : Colors.grey),
                          onPressed: hayStock
                              ? () => _agregarAlCarrito(producto)
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// El widget del carrito (derecha)
  Widget _buildCarrito() {
    return Expanded(
      flex: 1, // Ocupa 1/3 de la pantalla
      child: Container(
        margin: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Carrito',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            // --- Lista de items en el carrito ---
            Expanded(
              child: _carrito.isEmpty
                  ? const Center(child: Text('El carrito está vacío.'))
                  : ListView.builder(
                      itemCount: _carrito.length,
                      itemBuilder: (context, index) {
                        final item = _carrito[index];
                        return ListTile(
                          title: Text(item.producto.nombreProducto),
                          subtitle: Text(
                            '${item.cantidad} x \$${item.producto.precioVenta.toStringAsFixed(2)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '\$${item.subtotal.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.red),
                                onPressed: () => _removerDelCarrito(index),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(),
            // --- Total y Botón de Cobrar ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL:',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '\$${_calcularTotal().toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _cobrar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    child: const Text('Cobrar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:frontend_web/core/models/services/pos_service.dart';
import 'package:frontend_web/core/models/producto_model.dart';

class EntradaScreen extends StatefulWidget {
  const EntradaScreen({super.key});

  @override
  State<EntradaScreen> createState() => _EntradaScreenState();
}

class _EntradaScreenState extends State<EntradaScreen> {
  final PosService _posService = PosService();
  bool _isLoading = true;
  String _error = '';

  List<Producto> _productos = [];
  final Map<int, TextEditingController> _qtyControllers = {};

  @override
  void initState() {
    super.initState();
    _loadProductos();
  }

  @override
  void dispose() {
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProductos() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final productos = await _posService.getProductos();
      setState(() {
        _productos = productos;
        for (final p in productos) {
          _qtyControllers[p.idProducto] = TextEditingController(text: '0');
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error cargando productos: $e';
        _isLoading = false;
      });
    }
  }

  double _calcularTotal() {
    double total = 0.0;
    for (final p in _productos) {
      final t = _qtyControllers[p.idProducto]?.text ?? '0';
      final qty = int.tryParse(t) ?? 0;
      total += (p.precioCompra ?? 0) * qty;
    }
    return total;
  }

  Future<void> _registrarEntrada() async {
    final detalle = <Map<String, dynamic>>[];
    for (final p in _productos) {
      final t = _qtyControllers[p.idProducto]?.text ?? '0';
      final qty = int.tryParse(t) ?? 0;
      if (qty > 0) {
        detalle.add({
          'id_producto': p.idProducto,
          'cantidad': qty,
          'costo_unitario': p.precioCompra ?? 0,
          'precio_unitario': p.precioVenta,
        });
      }
    }

    if (detalle.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona al menos un producto con cantidad > 0')));
      return;
    }

    final total = _calcularTotal();

    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final exito = await _posService.crearEntrada(totalEntrada: total, detalle: detalle, idProveedor: null);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (exito) {
        // Recargar productos para reflejar la nueva existencia
        await _loadProductos();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entrada registrada con éxito'), backgroundColor: Colors.green));
        // Limpiar cantidades
        for (final c in _qtyControllers.values) {
          c.text = '0';
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al registrar entrada'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Entrada')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: _productos.length,
                        itemBuilder: (context, index) {
                          final p = _productos[index];
                          return ListTile(
                            title: Text(p.nombreProducto),
                            subtitle: Text('Costo: \$${(p.precioCompra ?? 0).toStringAsFixed(2)} | Stock actual: ${p.stock}'),
                            trailing: SizedBox(
                              width: 100,
                              child: TextField(
                                controller: _qtyControllers[p.idProducto],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Cant.'),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total: \$${_calcularTotal().toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ElevatedButton(
                                onPressed: _registrarEntrada,
                                child: const Text('Registrar Entrada'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

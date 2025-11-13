import 'package:flutter/material.dart';
import 'package:frontend_web/core/models/services/pos_service.dart';
import 'package:frontend_web/core/models/producto_model.dart';

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  final PosService _service = PosService();
  List<Producto> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final productos = await _service.getProductos();
      setState(() => _items = productos);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editarStock(Producto p) async {
    final controller = TextEditingController(text: p.stock.toString());
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Editar existencia: ${p.nombreProducto}'),
      content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Existencia')), 
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar'))
      ],
    ));

    if (ok != true) return;
    final nueva = int.tryParse(controller.text) ?? p.stock;
    try {
      final updated = await _service.updateInventario(idProducto: p.idProducto, existenciaActual: nueva);
      if (updated) {
        await _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inventario actualizado')));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo actualizar')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventario')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          itemCount: _items.length,
          itemBuilder: (context, index) {
            final p = _items[index];
            return ListTile(
              title: Text(p.nombreProducto),
              subtitle: Text('Existencia: ${p.stock}  • Precio: ${p.precioVenta.toStringAsFixed(2)}'),
              trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => _editarStock(p)),
            );
          },
        ),
      ),
    );
  }
}

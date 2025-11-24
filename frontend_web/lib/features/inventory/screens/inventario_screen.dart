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

  Future<void> _editarProducto(Producto p) async {
    // Cargar categorias y marcas para dropdowns
    List<dynamic> categorias = [];
    List<dynamic> marcas = [];
    try {
      categorias = await _service.getCategorias();
      marcas = await _service.getMarcas();
    } catch (_) {}

    final codigoCtl = TextEditingController(text: p.codigoProducto);
    final nombreCtl = TextEditingController(text: p.nombreProducto);
    final precioCtl = TextEditingController(text: p.precioVenta.toString());
    final compraCtl = TextEditingController(text: (p.precioCompra ?? 0.0).toString());
    final urlCtl = TextEditingController(text: p.urlImagen ?? '');
    final stockMinCtl = TextEditingController(text: p.stockMinimo.toString());
    int? selectedCategoria;
    int? selectedMarca;
    bool activo = p.activo;

    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text('Editar producto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: codigoCtl, decoration: const InputDecoration(labelText: 'Código')),
                TextField(controller: nombreCtl, decoration: const InputDecoration(labelText: 'Nombre')),
                TextField(controller: precioCtl, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Precio venta')),
                TextField(controller: compraCtl, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Precio compra')),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: selectedCategoria,
                  items: categorias.map((c) => DropdownMenuItem<int>(value: c['id_categoria'] as int, child: Text(c['nombre_categoria']))).toList(),
                  onChanged: (v) => setState(() => selectedCategoria = v),
                  decoration: const InputDecoration(labelText: 'Categoría'),
                ),
                DropdownButtonFormField<int>(
                  value: selectedMarca,
                  items: marcas.map((m) => DropdownMenuItem<int>(value: m['id_marca'] as int, child: Text(m['nombre_marca']))).toList(),
                  onChanged: (v) => setState(() => selectedMarca = v),
                  decoration: const InputDecoration(labelText: 'Marca'),
                ),
                TextField(controller: urlCtl, decoration: const InputDecoration(labelText: 'URL imagen')),
                TextField(controller: stockMinCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock mínimo')),
                Row(children: [
                  const Text('Activo'),
                  Checkbox(value: activo, onChanged: (v) => setState(() => activo = v ?? true)),
                ])
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        );
      }
    ));

    if (ok != true) return;

    // preparar datos
    final nombre = nombreCtl.text.trim();
    final codigo = codigoCtl.text.trim();
    final precio = double.tryParse(precioCtl.text) ?? p.precioVenta;
    final compra = double.tryParse(compraCtl.text) ?? p.precioCompra ?? 0.0;
    final url = urlCtl.text.trim().isEmpty ? null : urlCtl.text.trim();
    final stockMin = int.tryParse(stockMinCtl.text) ?? p.stockMinimo;

    try {
      final exito = await _service.actualizarProducto(
        idProducto: p.idProducto,
        codigoProducto: codigo,
        nombreProducto: nombre,
        precioVenta: precio,
        precioCompra: compra,
        idCategoria: selectedCategoria ?? null,
        idMarca: selectedMarca ?? null,
        urlImagen: url,
        stockMinimo: stockMin,
        activo: activo,
      );

      if (exito) {
        await _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto actualizado')));
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
              leading: p.urlImagen != null && p.urlImagen!.isNotEmpty
                  ? CircleAvatar(backgroundImage: NetworkImage(p.urlImagen!), radius: 20)
                  : null,
              title: Text(p.nombreProducto),
              subtitle: Text('Existencia: ${p.stock}  • Precio: ${p.precioVenta.toStringAsFixed(2)}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.edit), onPressed: () => _editarStock(p)),
                IconButton(icon: const Icon(Icons.edit_attributes), onPressed: () => _editarProducto(p)),
              ]),
            );
          },
        ),
      ),
    );
  }
}

// ignore_for_file: sort_child_properties_last

import 'package:flutter/material.dart';
import 'package:frontend_web/core/models/services/pos_service.dart';

class CategoriasScreen extends StatefulWidget {
  const CategoriasScreen({super.key});

  @override
  State<CategoriasScreen> createState() => _CategoriasScreenState();
}

class _CategoriasScreenState extends State<CategoriasScreen> {
  final PosService _service = PosService();
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _service.getCategorias();
      setState(() => _items = res);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createCategoria() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Crear Categoría'),
      content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Nombre')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crear'))
      ],
    ));

    if (ok != true) return;
    try {
      final created = await _service.crearCategoria(nombreCategoria: controller.text.trim());
      if (created) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Categoría creada')));
        await _load();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo crear categoría')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _editCategoria(Map<String, dynamic> it) async {
    final controller = TextEditingController(text: (it['nombre_categoria'] ?? '') as String);
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Editar Categoría'),
      content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Nombre')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar'))
      ],
    ));

    if (ok != true) return;
    try {
      final id = (it['id_categoria'] as int);
      final updated = await _service.actualizarCategoria(idCategoria: id, nombreCategoria: controller.text.trim());
      if (updated) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Categoría actualizada')));
        await _load();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo actualizar')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteCategoria(Map<String, dynamic> it) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Eliminar'),
      content: Text('¿Eliminar categoría "${it['nombre_categoria']}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar'))
      ],
    ));

    if (confirm != true) return;
    try {
      final id = (it['id_categoria'] as int);
      final deleted = await _service.eliminarCategoria(idCategoria: id);
      if (deleted) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Categoría eliminada')));
        await _load();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo eliminar')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categorías')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final it = _items[index] as Map<String, dynamic>;
          return ListTile(
            title: Text(it['nombre_categoria'] ?? ''),
            onTap: () => _editCategoria(it),
            trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => _deleteCategoria(it)),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createCategoria,
        child: const Icon(Icons.add),
        tooltip: 'Crear categoría',
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:frontend_web/core/models/services/pos_service.dart';
import 'package:frontend_web/features/shared/widgets/entity_card.dart';

class ProveedoresScreen extends StatefulWidget {
  const ProveedoresScreen({super.key});

  @override
  State<ProveedoresScreen> createState() => _ProveedoresScreenState();
}

class _ProveedoresScreenState extends State<ProveedoresScreen> {
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
      final res = await _service.getProveedores(page: 1, limit: 100);
      if (!mounted) return;
      setState(() => _items = res['items'] as List<dynamic>);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createProveedor() async {
    final nombreController = TextEditingController();
    final empresaController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Crear proveedor'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nombreController, decoration: const InputDecoration(labelText: 'Nombre')),
          TextField(controller: empresaController, decoration: const InputDecoration(labelText: 'Empresa')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crear'))
        ],
      ),
    );

    if (ok != true) return;
    try {
      final created = await _service.crearProveedor(nombreProveedor: nombreController.text, nombreEmpresa: empresaController.text);
      if (!mounted) return;
      if (created) {
        await _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo crear proveedor')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Proveedores')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index] as Map<String, dynamic>;
                  return EntityCard(
                    title: item['nombre_proveedor'] ?? '---',
                    subtitle: item['correo'] ?? '',
                    icon: Icons.local_shipping,
                    onEdit: () {},
                    onDelete: () {},
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createProveedor,
        icon: const Icon(Icons.add),
        label: const Text('Proveedor'),
        tooltip: 'Crear proveedor',
      ),
    );
  }
}

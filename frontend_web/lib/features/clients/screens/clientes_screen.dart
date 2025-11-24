import 'package:flutter/material.dart';
import 'package:frontend_web/core/models/services/pos_service.dart';
import 'package:frontend_web/features/shared/widgets/entity_card.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
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
      final res = await _service.getClientes(page: 1, limit: 100);
      if (!mounted) return;
      setState(() => _items = res['items'] as List<dynamic>);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createCliente() async {
    final nombreController = TextEditingController();
    final correoController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Crear cliente'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nombreController, decoration: const InputDecoration(labelText: 'Nombre')),
          TextField(controller: correoController, decoration: const InputDecoration(labelText: 'Email')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crear'))
        ],
      ),
    );

    if (ok != true) return;
    try {
      final created = await _service.crearCliente(nombreCliente: nombreController.text, correo: correoController.text);
      if (!mounted) return;
      if (created) {
        await _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo crear cliente')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
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
                    title: item['nombre_cliente'] ?? '---',
                    subtitle: item['correo'] ?? '',
                    icon: Icons.person,
                    onEdit: () async {
                      // mostrar dialogo de edición simple
                      final nombreCtrl = TextEditingController(text: item['nombre_cliente'] ?? '');
                      final correoCtrl = TextEditingController(text: item['correo'] ?? '');
                      final okEdit = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Editar cliente'),
                          content: Column(mainAxisSize: MainAxisSize.min, children: [
                            TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
                            TextField(controller: correoCtrl, decoration: const InputDecoration(labelText: 'Email')),
                          ]),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar'))
                          ],
                        ),
                      );
                      if (okEdit == true) {
                        final success = await _service.actualizarCliente(
                          idCliente: item['id_cliente'] as int,
                          nombreCliente: nombreCtrl.text,
                          correo: correoCtrl.text,
                        );
                        if (success) await _load();
                      }
                    },
                    onDelete: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Eliminar cliente'),
                          content: const Text('¿Confirma eliminar este cliente?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí'))
                          ],
                        ),
                      );
                      if (confirm == true) {
                        final deleted = await _service.eliminarCliente(idCliente: item['id_cliente'] as int);
                        if (deleted) await _load();
                      }
                    },
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCliente,
        icon: const Icon(Icons.add),
        label: const Text('Cliente'),
        tooltip: 'Crear cliente',
      ),
    );
  }
}



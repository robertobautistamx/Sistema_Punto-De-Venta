import 'package:flutter/material.dart';
import 'package:frontend_web/core/models/services/pos_service.dart';

class MovimientosScreen extends StatefulWidget {
  const MovimientosScreen({super.key});

  @override
  State<MovimientosScreen> createState() => _MovimientosScreenState();
}

class _MovimientosScreenState extends State<MovimientosScreen> {
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
      final res = await _service.getInventarioMovimientos(page: 1, limit: 200);
      setState(() => _items = res['items'] as List<dynamic>);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Movimientos de Inventario')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          itemCount: _items.length,
          itemBuilder: (context, index) {
            final it = _items[index] as Map<String, dynamic>;
            return ListTile(
              title: Text('${it['tipo'] ?? '-'} • ${it['cantidad'] ?? ''}'),
              subtitle: Text('Producto: ${it['nombre_producto'] ?? '-'} • Usuario: ${it['nombre_usuario'] ?? '-'}'),
              trailing: Text(it['fecha'] ?? ''),
            );
          },
        ),
      ),
    );
  }
}

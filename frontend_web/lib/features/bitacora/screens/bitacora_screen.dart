import 'package:flutter/material.dart';
import 'package:frontend_web/core/models/services/pos_service.dart';

class BitacoraScreen extends StatefulWidget {
  const BitacoraScreen({super.key});

  @override
  State<BitacoraScreen> createState() => _BitacoraScreenState();
}

class _BitacoraScreenState extends State<BitacoraScreen> {
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
      final res = await _service.getBitacora(page: 1, limit: 200);
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
      appBar: AppBar(title: const Text('Bitácora')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          itemCount: _items.length,
          itemBuilder: (context, index) {
            final it = _items[index] as Map<String, dynamic>;
            return ListTile(
              title: Text('${it['nombre_tabla'] ?? ''} • ${it['tipo_operacion'] ?? ''}'),
              subtitle: Text('Usuario app: ${it['usuario_app_nombre'] ?? ''} • DB: ${it['usuario_db'] ?? ''}'),
              trailing: Text(it['fecha_modificacion'] ?? ''),
            );
          },
        ),
      ),
    );
  }
}

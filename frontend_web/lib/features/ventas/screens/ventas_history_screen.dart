// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:frontend_web/core/models/services/pos_service.dart';

class VentasHistoryScreen extends StatefulWidget {
  const VentasHistoryScreen({super.key});

  @override
  State<VentasHistoryScreen> createState() => _VentasHistoryScreenState();
}

class _VentasHistoryScreenState extends State<VentasHistoryScreen> {
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
      final res = await _service.getVentasHistory(page: 1, limit: 100);
      setState(() => _items = res['items'] as List<dynamic>);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de Ventas')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          itemCount: _items.length,
          itemBuilder: (context, index) {
            final item = _items[index] as Map<String, dynamic>;
            return ListTile(
              title: Text('Venta #${item['id_venta'] ?? ''} - ${item['total'] ?? ''}'),
              subtitle: Text('Cliente: ${item['cliente_nombre'] ?? '-'} • Usuario: ${item['usuario_app_nombre'] ?? '-'}'),
              trailing: Text(item['fecha'] ?? ''),
            );
          },
        ),
      ),
    );
  }
}

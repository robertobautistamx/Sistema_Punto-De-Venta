// ignore_for_file: deprecated_member_use, use_super_parameters

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend_web/features/auth/screens/login_screen.dart';
import 'package:frontend_web/features/inventory/screens/entrada_screen.dart';
import 'package:frontend_web/features/pos/screens/pos_screen.dart';
import 'package:frontend_web/features/clients/screens/clientes_screen.dart';
import 'package:frontend_web/features/providers/screens/proveedores_screen.dart';
import 'package:frontend_web/features/ventas/screens/ventas_history_screen.dart';
import 'package:frontend_web/features/inventory/screens/inventario_screen.dart';
import 'package:frontend_web/features/inventory/screens/movimientos_screen.dart';
import 'package:frontend_web/features/bitacora/screens/bitacora_screen.dart';
import 'package:frontend_web/features/catalog/screens/categorias_screen.dart';
import 'package:frontend_web/features/catalog/screens/marcas_screen.dart';
import 'dart:async';
import 'package:frontend_web/core/models/services/pos_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _nombre = '';
  String _rol = '';
  String _search = '';
  int _cartCount = 0;
  double _ventasHoy = 0.0;
  int _stockCritico = 0;
  bool _heroHover = false;
  final PosService _posService = PosService();
  List<dynamic> _mailLog = [];
  int? _lastMailId;
  Timer? _mailTimer;

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
    _startMailPolling();
  }

  @override
  void dispose() {
    _mailTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargarDatosUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _nombre = prefs.getString('usuario_nombre') ?? 'Usuario';
      _rol = prefs.getString('usuario_rol') ?? 'Sin rol';
    });
    await _loadMetrics();
  }

  void _startMailPolling() {
    // Poll mail log immediately and then every 30s
    _checkMailLog();
    _mailTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkMailLog());
  }

  Future<void> _checkMailLog() async {
    try {
      final logs = await _posService.getMailLog();
      if (logs.isNotEmpty) {
        final top = logs.first as Map<String, dynamic>;
        final mailId = top['mailitem_id'] as int?;
        if (_lastMailId == null) {
          _lastMailId = mailId;
        } else if (mailId != null && mailId != _lastMailId) {
          // Nuevo correo enviado, notificar al usuario
          _lastMailId = mailId;
          if (mounted) {
            final subject = top['subject'] ?? 'Notificación enviada';
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Correo enviado: $subject')));
          }
        }
      }
      setState(() => _mailLog = logs);
    } catch (_) {
      // Ignoramos errores de polling para no molestar
    }
  }

  void _showMailLog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registros de correo (Database Mail)'),
        content: SizedBox(
          width: 600,
          child: _mailLog.isEmpty
              ? const Text('No hay registros recientes')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _mailLog.length,
                  separatorBuilder: (_, __) => const Divider(height: 8),
                  itemBuilder: (context, index) {
                    final item = _mailLog[index] as Map<String, dynamic>;
                    final subj = item['subject'] ?? '';
                    final to = item['recipients'] ?? '';
                    final date = item['send_request_date'] ?? '';
                    final status = item['sent_status'] ?? '';
                    return ListTile(
                      title: Text(subj.toString(), overflow: TextOverflow.ellipsis),
                      subtitle: Text('Para: $to\nFecha: $date'),
                      trailing: Text(status.toString()),
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
      ),
    );
  }

  Future<void> _loadMetrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _cartCount = prefs.getInt('cart_count') ?? 0;
        _ventasHoy = prefs.getDouble('ventas_hoy') ?? 0.0;
        _stockCritico = prefs.getInt('stock_critico') ?? 0;
      });
    } catch (_) {
    }
  }

  Future<void> _cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final surface = scheme.surface;

    final options = [
      {'icon': Icons.people, 'label': 'Clientes', 'tap': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ClientesScreen()))},
      {'icon': Icons.local_shipping, 'label': 'Proveedores', 'tap': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProveedoresScreen()))},
      {'icon': Icons.history, 'label': 'Historial Ventas', 'tap': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VentasHistoryScreen()))},
      {'icon': Icons.inventory, 'label': 'Inventario', 'tap': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InventarioScreen()))},
      {'icon': Icons.swap_vert, 'label': 'Movimientos', 'tap': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MovimientosScreen()))},
      {'icon': Icons.book, 'label': 'Bitácora', 'tap': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BitacoraScreen()))},
      {'icon': Icons.category, 'label': 'Categorías', 'tap': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CategoriasScreen()))},
      {'icon': Icons.branding_watermark, 'label': 'Marcas', 'tap': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MarcasScreen()))},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Bienvenido, $_nombre'),
        actions: [
          Tooltip(
            message: 'Logs de correo',
            child: IconButton(icon: const Icon(Icons.mail_outline), onPressed: _showMailLog),
          ),
          Tooltip(
            message: 'Cerrar Sesión',
            child: IconButton(icon: const Icon(Icons.logout), onPressed: _cerrarSesion),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: surface.withOpacity(0.86),
                    border: Border.all(color: surface.withAlpha(18)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 18, offset: const Offset(0, 8))],
                  ),
                  child: Padding(
                    // Reduced vertical padding to avoid overflow on smaller heights
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('¡Has iniciado sesión con éxito!', style: Theme.of(context).textTheme.headlineSmall?.copyWith(letterSpacing: 0.4)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(color: surface.withAlpha(20), borderRadius: BorderRadius.circular(20)),
                          child: Text('Tu rol es: $_rol', style: Theme.of(context).textTheme.bodyLarge),
                        ),
                        const SizedBox(height: 18),

                        // Search
                        SizedBox(
                          width: double.infinity,
                          child: TextField(
                            onChanged: (v) => setState(() => _search = v),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              hintText: 'Buscar acción, p. ej. "Clientes"',
                              filled: true,
                              fillColor: scheme.surface.withAlpha(18),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        //metricas
                        LayoutBuilder(builder: (ctx, constraints) {
                          final narrow = constraints.maxWidth < 680;
                          if (narrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _metricCard(title: 'Ventas hoy', value: '\$${_ventasHoy.toStringAsFixed(2)}', color: primary.withAlpha(220)),
                                const SizedBox(height: 10),
                                _metricCard(title: 'Stock crítico', value: '$_stockCritico', color: Colors.orangeAccent),
                                const SizedBox(height: 10),
                                _metricCard(title: 'Carrito', value: '$_cartCount items', compact: true, color: Colors.greenAccent.shade700, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PosScreen()))),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: _metricCard(title: 'Ventas hoy', value: '\$${_ventasHoy.toStringAsFixed(2)}', color: primary.withAlpha(220))),
                              const SizedBox(width: 12),
                              Expanded(child: _metricCard(title: 'Stock crítico', value: '$_stockCritico', color: Colors.orangeAccent)),
                              const SizedBox(width: 12),
                              SizedBox(width: 160, child: _metricCard(title: 'Carrito', value: '$_cartCount items', compact: true, color: Colors.greenAccent.shade700, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PosScreen())))),
                            ],
                          );
                        }),
                        const SizedBox(height: 20),

                        LayoutBuilder(builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 520;
                          if (isWide) {
                            return Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: MouseRegion(
                                    onEnter: (_) => setState(() => _heroHover = true),
                                    onExit: (_) => setState(() => _heroHover = false),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      transform: Matrix4.identity()..scale(_heroHover ? 1.01 : 1.0),
                                      height: 64,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: LinearGradient(colors: [primary.withOpacity(0.96), primary.withOpacity(0.76)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                        boxShadow: _heroHover ? [BoxShadow(color: primary.withOpacity(0.16), blurRadius: 18, offset: const Offset(0, 8))] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 6))],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(16),
                                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PosScreen())),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 20),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), shape: BoxShape.circle),
                                                  padding: const EdgeInsets.all(12),
                                                  child: Stack(
                                                    alignment: Alignment.center,
                                                    children: [
                                                      const Icon(Icons.point_of_sale, size: 26, color: Colors.white),
                                                      if (_cartCount > 0)
                                                        // Smaller badge contained within the icon circle to avoid overflow
                                                        Positioned(
                                                          right: 0,
                                                          top: 0,
                                                          child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10)), child: Text('$_cartCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Text('Punto de Venta', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                SizedBox(width: 180, height: 56, child: OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EntradaScreen())), icon: const Icon(Icons.inventory_2), label: const Text('Registrar Entrada'), style: OutlinedButton.styleFrom(side: BorderSide(color: primary.withAlpha(200)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),),),
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              MouseRegion(
                                onEnter: (_) => setState(() => _heroHover = true),
                                onExit: (_) => setState(() => _heroHover = false),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  transform: Matrix4.identity()..scale(_heroHover ? 1.01 : 1.0),
                                  height: 64,
                                  child: ElevatedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PosScreen())), icon: const Icon(Icons.point_of_sale, size: 26), label: const Text('Punto de Venta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), style: ElevatedButton.styleFrom(backgroundColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 10),),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(height: 56, child: OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EntradaScreen())), icon: const Icon(Icons.inventory_2), label: const Text('Registrar Entrada'), style: OutlinedButton.styleFrom(side: BorderSide(color: primary.withAlpha(200)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),),),
                            ],
                          );
                        }),

                        const SizedBox(height: 20),

                        // Tiles
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: MediaQuery.of(context).size.width > 920 ? 4 : (MediaQuery.of(context).size.width > 700 ? 3 : 2),
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: MediaQuery.of(context).size.width > 900 ? 4.2 : 3.6,
                          children: options.where((opt) => (_search.isEmpty) || (opt['label'] as String).toLowerCase().contains(_search.toLowerCase())).map((opt) {
                            final isInventory = (opt['label'] as String) == 'Inventario';
                            return _HoverTile(icon: opt['icon'] as IconData, label: opt['label'] as String, onTap: opt['tap'] as VoidCallback, badge: isInventory ? _stockCritico : null);
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricCard({required String title, required String value, Color? color, bool compact = false, VoidCallback? onTap}) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
          child: Container(
          // Allow flexible height but keep a reasonable minimum so content can scale
          constraints: BoxConstraints(minHeight: compact ? 48 : 56),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 4))],
            border: Border.all(color: scheme.surfaceVariant.withAlpha(40)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    // Make value adaptive to available space to avoid overflow
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: compact ? 14 : 16, color: color ?? scheme.primary), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Slightly smaller icon to avoid pushing content vertically
              Icon(Icons.show_chart, size: 20, color: (color ?? scheme.primary).withAlpha(220)),
            ],
          ),
        ),
      ),
    );
  }
}

// Hover tile con badge opcional
class _HoverTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badge;

  const _HoverTile({required this.icon, required this.label, required this.onTap, this.badge, Key? key}) : super(key: key);

  @override
  State<_HoverTile> createState() => _HoverTileState();
}

class _HoverTileState extends State<_HoverTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final bg = scheme.surface.withAlpha(12);
    final scale = _hover ? 1.02 : 1.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.identity()..scale(scale),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _hover ? [BoxShadow(color: primary.withAlpha(28), blurRadius: 12, offset: const Offset(0, 6))] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: widget.onTap,
            splashColor: primary.withAlpha(40),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.icon, size: 18, color: scheme.onSurface),
                    const SizedBox(width: 8),
                    Text(widget.label, style: const TextStyle(fontSize: 14)),
                  ],
                ),
                if (widget.badge != null && widget.badge! > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(12)),
                      child: Text('${widget.badge}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

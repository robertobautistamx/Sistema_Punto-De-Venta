// ignore_for_file: use_super_parameters, deprecated_member_use

import 'package:flutter/material.dart';

class EntityCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final int? badgeCount;

  const EntityCard({required this.title, required this.subtitle, required this.icon, required this.onEdit, required this.onDelete, this.badgeCount, Key? key}) : super(key: key);

  @override
  State<EntityCard> createState() => _EntityCardState();
}

class _EntityCardState extends State<EntityCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.surfaceVariant.withAlpha(30)),
          boxShadow: _hover
              ? [BoxShadow(color: scheme.primary.withAlpha(14), blurRadius: 10, offset: const Offset(0, 6))]
              : [BoxShadow(color: Colors.black.withAlpha(4), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: ListTile(
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(backgroundColor: scheme.primary, child: Icon(widget.icon, color: Colors.white)),
              if (widget.badgeCount != null && widget.badgeCount! > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 4)]),
                    child: Text('${widget.badgeCount}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
          title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(widget.subtitle, style: TextStyle(color: scheme.onSurface.withAlpha(160))),
          trailing: PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') widget.onEdit();
              if (v == 'delete') widget.onDelete();
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'edit', child: Text('Editar')),
              PopupMenuItem(value: 'delete', child: Text('Eliminar')),
            ],
          ),
        ),
      ),
    );
  }
}

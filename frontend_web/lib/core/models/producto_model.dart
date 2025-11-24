class Producto {
  final int idProducto;
  final String codigoProducto;
  final String nombreProducto;
  final double precioVenta;
  final double? precioCompra;
  final int stock;
  final String? categoria;
  final String? marca;
  final String? urlImagen;
  final bool activo;
  final int stockMinimo;

  Producto({
    required this.idProducto,
    required this.codigoProducto,
    required this.nombreProducto,
    required this.precioVenta,
    this.precioCompra,
    required this.stock,
    this.categoria,
    this.marca,
    this.urlImagen,
    this.activo = true,
    this.stockMinimo = 5,
  });

  // Factory para crear un Producto desde el JSON de la API
  factory Producto.fromJson(Map<String, dynamic> json) {
    return Producto(
      idProducto: json['id_producto'],
      codigoProducto: json['codigo_producto'] ?? '',
      nombreProducto: json['nombre_producto'] ?? '',
      precioVenta: (json['precio_venta'] as num?)?.toDouble() ?? 0.0,
      // Si el precio_compra es nulo en la BD, usamos 0.0
      precioCompra: (json['precio_compra'] as num?)?.toDouble() ?? 0.0,
      // Preferir existencia_actual cuando este disponible (proviene de la tabla inventario)
      stock: (json['existencia_actual'] ?? json['stock'] ?? 0) as int,
      categoria: json['nombre_categoria'],
      marca: json['nombre_marca'],
      urlImagen: json['url_imagen'] as String?,
      activo: (json['activo'] is int) ? (json['activo'] == 1) : (json['activo'] as bool? ?? true),
      stockMinimo: (json['stock_minimo'] as int?) ?? (json['stock_minimo'] is String ? int.tryParse(json['stock_minimo']) ?? 5 : 5),
    );
  }
}
import 'package:frontend_web/core/models/producto_model.dart';

class CartItem {
  final Producto producto;
  int cantidad;

  CartItem({
    required this.producto,
    this.cantidad=1,
  });

  //calcula el subtotal para este item
  double get subtotal=>producto.precioVenta * cantidad;

  //incrementa la cantidad, si hay stock
  void incrementar() {
    if (cantidad < producto.stock) {
      cantidad++;
    }
  }

  //decrementa la cantidad
  void decrementar() {
    if (cantidad > 1) {
      cantidad--;
    }
  }
}
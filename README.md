# Sistema_Punto-De-Venta
Sistema de Punto de Venta web desarrollado con Flutter (Dart), Node.js y SQL Server. Permite gestionar distintos módulos como productos, inventario y ventas. El backend maneja la lógica y la base de datos garantiza integridad. Interfaz responsiva y fácil de usar.

## Tecnologías Utilizadas

| Tecnología | Descripción |
|-----------|-------------|
| ![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white) | Framework para la interfaz web (Dart) |
| ![Dart](https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=white) | Lenguaje utilizado en la capa de presentación |
| ![Node.js](https://img.shields.io/badge/Node.js-339933?logo=node.js&logoColor=white) | Backend y lógica del negocio |
| ![SQL Server](https://img.shields.io/badge/SQL%20Server-CC2927?logo=microsoftsqlserver&logoColor=white) | Base de datos relacional del sistema |

## ✨ Características Principales

- 🧭 **Interfaz responsiva y accesible**  
  Diseñada para escritorio y adaptable a distintos tamaños mediante `LayoutBuilder` y `GridView`.

- 🔒 **Autenticación segura (JWT)**  
  El backend genera un token guardado en `SharedPreferences`, enviado en las peticiones protegidas.

- 🛒 **Módulo Punto de Venta (POS)**  
  Permite ventas rápidas con carrito, cálculo de totales y manejo de distintos tipos de pago.  
  Cada venta se registra mediante un **TVP (`TIPO_CarritoVenta`)** y el procedimiento almacenado `sp_CrearVenta`.

- 📦 **Inventario y Entradas**  
  Control de existencias y registro de compras mediante `sp_CrearEntrada`, actualizando automáticamente el inventario y los movimientos.

- 🧾 **Gestión de Catálogos (CRUD)**  
  Módulos para Productos, Categorías, Marcas, Clientes y Proveedores, con procedimientos almacenados y endpoints REST.

- 🕵️ **Auditoría y Bitácora**  
  Triggers en base de datos para registrar modificaciones importantes (clientes, productos).

- 📊 **Historial y Reportes**  
  Historial de ventas paginado (`sp_ObtenerVentasHistory`) y consultas de inventario o movimientos.

- 💡 **Experiencia de Usuario**  
  Microanimaciones, efectos *hover* y mensajes claros en acciones críticas.

---

## 🧭 Flujo de Navegación (UI)

### 1️⃣ **Pantalla de Login (`/` o `LoginScreen`)**
- Ingreso de credenciales y validación en backend.  
- Devuelve JWT y datos del usuario.  
- Navegación a `HomeScreen` con `Navigator.pushReplacement`.

---

### 2️⃣ **Home / Dashboard (`HomeScreen`)**
- Muestra métricas clave (ventas del día, stock crítico, items en carrito).  
- Accesos directos a los módulos principales.  
- CTA principal: **“Punto de Venta”**.

---

### 3️⃣ **Punto de Venta (`PosScreen`)**
- Selección de productos y cantidades.  
- Cálculo automático de totales.  
- Al confirmar, el frontend envía un TVP a `/api/ventas` que ejecuta `sp_CrearVenta`.

---

### 4️⃣ **Inventario y Entradas (`InventarioScreen`, `EntradaScreen`)**
- Listado paginado de productos y existencias.  
- Registro de entradas con actualización automática del inventario.

---

### 5️⃣ **Catálogos y Listas**
- Módulos CRUD: **Clientes**, **Proveedores**, **Categorías** y **Marcas**.  
- Listas con búsqueda, paginación y componentes reutilizables (`EntityCard`).

---

### 6️⃣ **Movimientos y Bitácora**
- Consulta de historiales y registros de auditoría.  
- Acceso limitado a roles con permisos administrativos.

---

### 7️⃣ **Perfil y Cierre de Sesión**
- Desde el AppBar se accede al perfil y la opción de cerrar sesión.  
- Borra datos locales (`SharedPreferences`) y redirige al `LoginScreen`.

---

**Cambios recientes en la Base de Datos (importante)**

- **Nuevos campos en `productos`**: se agregaron `url_imagen` (VARCHAR(500)), `activo` (BIT) y `stock_minimo` (INT). Estos campos permiten mostrar imágenes de producto en el frontend, ocultar productos deshabilitados y configurar un umbral individual para alertas de stock.

- **Procedimientos y funciones añadidos/actualizados**:
  - `sp_ObtenerProductos` ahora devuelve `url_imagen` y `stock_minimo` y filtra por `activo = 1`.
  - `sp_ActualizarProducto` acepta nuevos parámetros `@url_imagen`, `@stock_minimo` y `@activo`.
  - Nuevas funciones y procedimientos relacionados con reportes (`fn_CalcularMargen`, `sp_CorteDeCajaDia`, `sp_RegistrarPerdida`).

- **Triggers y notificaciones**: se incluyó `tr_AlertaStockBajo` (ahora compara contra `stock_minimo` del producto) y un script `ConfigurarCorreo.sql` para configurar Database Mail. Antes de ejecutar `ConfigurarCorreo.sql`, revisa y reemplaza las credenciales en el script por valores seguros.
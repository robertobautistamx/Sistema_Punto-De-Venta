const express = require('express');
const sql = require('mssql'); //conector de sql server
require('dotenv').config(); // cargar variables de .env
const bcrypt = require('bcryptjs'); // encriptar contraseñas
const jwt = require('jsonwebtoken'); //tokens de sesion
const cors=require ('cors');
const authMiddleware = require('./middleware/authMiddleware');

const app = express();
const port = process.env.PORT || 3000;

// configuracion de la base de datos desde variables de entorno
// --- Configuración de Conexión a BD ---
const dbConfig = {
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  server: process.env.DB_SERVER,
  database: process.env.DB_DATABASE,
  port: parseInt(process.env.DB_PORT),
  options: {
    trustServerCertificate: true, // Necesario para conexiones locales
    encrypt: false // Para desarrollo local con SQL Auth
  }
};

// Middleware para parsear JSON
app.use(cors());
app.use(express.json());

// Helper: middleware para checar roles
function requireRole(roleName) {
  return (req, res, next) => {
    try {
      const userRole = req.usuario && req.usuario.rol;
      if (!userRole) return res.status(403).json({ error: 'Rol no encontrado en token.' });
      if (userRole !== roleName) return res.status(403).json({ error: 'Permiso denegado. Requiere rol: ' + roleName });
      next();
    } catch (err) {
      return res.status(500).json({ error: 'Error verificando rol', detalle: err.message });
    }
  };
}

const pool = new sql.ConnectionPool(dbConfig);
let poolConnect = pool.connect(); // Inicia la conexión

poolConnect.then((connection) => {
    console.log('¡Pool de conexión a SQL Server exitoso!');
}).catch((err) => {
    console.error('Error al conectar el pool a la base de datos:', err);
});

// 1. refistro de usario - endpoint
app.post('/api/register', async (req, res) => {
    // 1. obtenemos los datos que envia Flutter
    const { nombre_usuario, nombre_acceso, contrasena, id_rol, correo, telefono } = req.body;

    // 2. Validamos que los datos basicos esten
    if (!nombre_acceso || !contrasena || !nombre_usuario || !id_rol) {
        return res.status(400).json({ error: 'Faltan campos obligatorios: nombre_usuario, nombre_acceso, contrasena, id_rol' });
    }

    try {
        // 3. encriptamos la contrasena
        const salt = await bcrypt.genSalt(10);
        const contrasena_hash = await bcrypt.hash(contrasena, salt);

        // 4. creamos la solicitud (request) al pool
        const request = pool.request();
        
        // 5. parametros al SP (stored procedure)
        request.input('nombre_usuario', sql.VarChar, nombre_usuario);
        request.input('nombre_acceso', sql.VarChar, nombre_acceso);
        request.input('contrasena_hash', sql.VarChar, contrasena_hash); // Enviamos el HASH
        request.input('id_rol', sql.Int, id_rol);
        request.input('correo', sql.VarChar, correo);
        request.input('telefono', sql.VarChar, telefono);

        // 6. ejecutamos el stored procedure
        const result = await request.execute('sp_RegistrarUsuario');
        
        // 7. enviamos la respuesta
        res.status(201).json({ 
            mensaje: 'Usuario registrado con éxito', 
            id_usuario: result.recordset[0].id_usuario_creado 
        });

    } catch (error) {
        console.error('Error en /api/register:', error.message);
        // El SP "RAISERROR" se captura aqui
        res.status(500).json({ error: 'Error al registrar el usuario', detalle: error.message });
    }
});

// 2. login de usuario - endpoint
app.post('/api/login', async (req, res) => {
    const { nombre_acceso, contrasena } = req.body;

    if (!nombre_acceso || !contrasena) {
        return res.status(400).json({ error: 'Faltan nombre_acceso y contrasena' });
    }

    try {
        // 1. preparamos la llamada al SP para buscar al usuario
        const request = pool.request();
        request.input('nombre_acceso', sql.VarChar, nombre_acceso);
        
        const result = await request.execute('sp_ValidarLogin');

        // 2. verificamos si el usuario existe
        if (result.recordset.length === 0) {
            return res.status(404).json({ error: 'Usuario no encontrado' });
        }

        const usuario = result.recordset[0];

        // 3. comparamos la contrasena enviada con el HASH de la BD
        const contrasenaValida = await bcrypt.compare(contrasena, usuario.contrasena);

        if (!contrasenaValida) {
            return res.status(401).json({ error: 'Contraseña incorrecta' });
        }

        // 4. si es contrasena valida creamos el gafete (JWT Token)
        const payload = {
            id_usuario: usuario.id_usuario,
            nombre: usuario.nombre_usuario,
            rol: usuario.nombre_rol
        };

        //token
        const token = jwt.sign(payload, process.env.JWT_SECRET || 'TU_CLAVE_SECRETA_TEMPORAL', {
            expiresIn: '8h' 
        });

        // 5. enviamos el token y los datos del usuario a Flutter
        res.status(200).json({
            mensaje: 'Login exitoso',
            token: token,
            usuario: payload
        });

    } catch (error) {
        console.error('Error en /api/login:', error.message);
        res.status(500).json({ error: 'Error en el servidor', detalle: error.message });
    }
});

//3. ENDPOINT PARA OBTENER PRODUCTOS
app.get('/api/productos', authMiddleware, async (req, res) => {
  // Gracias a authMiddleware, esta ruta solo funciona si el usuario está logueado
  try {
    const request = pool.request();
    const result = await request.execute('sp_ObtenerProductos');
    
    res.status(200).json(result.recordset); // Devuelve la lista de productos (incluye url_imagen y stock_minimo si el SP fue actualizado)
  
  } catch (error) {
    console.error('Error en /api/productos:', error.message);
    res.status(500).json({ error: 'Error al obtener productos', detalle: error.message });
  }
});

// ENDPOINT: Crear producto (Admin)
app.post('/api/productos', authMiddleware, requireRole('Administrador'), async (req, res) => {
  const {
    codigo_producto,
    nombre_producto,
    precio_venta,
    precio_compra,
    id_categoria,
    id_marca,
    url_imagen,
    stock_minimo,
    activo
  } = req.body;

  if (!nombre_producto || !codigo_producto) return res.status(400).json({ error: 'Faltan campos obligatorios: nombre_producto o codigo_producto' });

  try {
    const request = pool.request();
    request.input('codigo_producto', sql.VarChar, codigo_producto);
    request.input('nombre_producto', sql.VarChar, nombre_producto);
    request.input('precio_venta', sql.Decimal(10,2), precio_venta ?? 0);
    request.input('precio_compra', sql.Decimal(10,2), precio_compra ?? 0);
    request.input('id_categoria', sql.Int, id_categoria ?? null);
    request.input('id_marca', sql.Int, id_marca ?? null);
    request.input('url_imagen', sql.VarChar, url_imagen ?? null);
    request.input('stock_minimo', sql.Int, stock_minimo ?? 5);
    request.input('activo', sql.Bit, (typeof activo === 'boolean') ? activo : (activo === 1 ? true : true));

    // Intentamos usar un SP si existe `sp_CrearProducto`, si no, hacemos INSERT directo
    try {
      const spRes = await request.execute('sp_CrearProducto');
      return res.status(201).json({ mensaje: 'Producto creado (SP)', id_producto: spRes.recordset[0]?.id_producto_creado ?? null });
    } catch (spErr) {
      // SP no existe: fallback a INSERT manual
    }

    const insertQ = `INSERT INTO productos (codigo_producto, nombre_producto, precio_venta, precio_compra, id_categoria, id_marca, url_imagen, stock_minimo, activo)
                     OUTPUT INSERTED.id_producto
                     VALUES (@codigo_producto, @nombre_producto, @precio_venta, @precio_compra, @id_categoria, @id_marca, @url_imagen, @stock_minimo, @activo)`;

    const result = await request.query(insertQ);
    res.status(201).json({ mensaje: 'Producto creado', id_producto: result.recordset[0].id_producto });
  } catch (error) {
    console.error('Error en POST /api/productos:', error.message);
    res.status(500).json({ error: 'Error al crear producto', detalle: error.message });
  }
});

// ENDPOINT: Actualizar producto (Admin)
app.put('/api/productos/:id', authMiddleware, requireRole('Administrador'), async (req, res) => {
  const id = parseInt(req.params.id);
  const {
    nombre_producto,
    codigo_producto,
    precio_venta,
    precio_compra,
    id_categoria,
    id_marca,
    url_imagen,
    stock_minimo,
    activo,
    id_usuario_app
  } = req.body;

  if (!id) return res.status(400).json({ error: 'ID de producto inválido' });

  try {
    const request = pool.request();
    // Si el SP `sp_ActualizarProducto` fue actualizado a aceptar los nuevos parámetros, lo llamamos
    request.input('id_producto', sql.Int, id);
    request.input('nombre_producto', sql.VarChar, nombre_producto);
    request.input('codigo_producto', sql.VarChar, codigo_producto);
    request.input('precio_venta', sql.Decimal(10,2), precio_venta ?? 0);
    request.input('precio_compra', sql.Decimal(10,2), precio_compra ?? 0);
    request.input('id_categoria', sql.Int, id_categoria ?? null);
    request.input('id_marca', sql.Int, id_marca ?? null);
    request.input('url_imagen', sql.VarChar, url_imagen ?? null);
    request.input('stock_minimo', sql.Int, stock_minimo ?? 5);
    request.input('activo', sql.Bit, (typeof activo === 'boolean') ? activo : (activo === 1 ? true : true));
    request.input('id_usuario_app', sql.Int, id_usuario_app ?? req.usuario.id_usuario);

    try {
      const spRes = await request.execute('sp_ActualizarProducto');
      return res.status(200).json({ mensaje: 'Producto actualizado (SP)', id_producto_actualizado: spRes.recordset[0]?.id_producto_actualizado ?? id });
    } catch (spErr) {
      // SP no existe o falló: fallback a UPDATE manual
      const updateQ = `UPDATE productos SET codigo_producto = @codigo_producto, nombre_producto = @nombre_producto,
                        precio_venta = @precio_venta, precio_compra = @precio_compra, id_categoria = @id_categoria,
                        id_marca = @id_marca, url_imagen = @url_imagen, stock_minimo = @stock_minimo, activo = @activo
                        WHERE id_producto = @id_producto`;
      await request.query(updateQ);
      return res.status(200).json({ mensaje: 'Producto actualizado', id_producto_actualizado: id });
    }

  } catch (error) {
    console.error('Error en PUT /api/productos/:id', error.message);
    res.status(500).json({ error: 'Error al actualizar producto', detalle: error.message });
  }
});

//4. ENDPOINT PARA CREAR VENTA
app.post('/api/ventas', authMiddleware, async (req, res) => {
  // 1. Obtenemos los datos del carrito y el ID del usuario (del "guardián")
  const { id_cliente, total, metodo_pago, detalle } = req.body;
  const id_usuario_app = req.usuario.id_usuario; // ¡Gracias al middleware!

  if (!total || !metodo_pago || !detalle || detalle.length === 0) {
    return res.status(400).json({ error: 'Faltan datos en la venta (total, metodo_pago, detalle)' });
  }

  try {
    // 2. Convertir el "detalle" (carrito de Flutter) a una Tabla SQL
  // Crear una tabla en JS que se mapeará al tipo definido en SQL: TIPO_CarritoVenta
  // Es importante indicar el nombre para que el driver lo use como TVP (Table-Valued Parameter)
  const tablaDetalle = new sql.Table('TIPO_CarritoVenta');
    // Definimos las columnas EXACTAMENTE como el "TIPO_CarritoVenta" en SQL
    tablaDetalle.columns.add('id_producto', sql.Int);
    tablaDetalle.columns.add('cantidad', sql.Int);
    tablaDetalle.columns.add('precio_unitario', sql.Decimal(10, 2));
    tablaDetalle.columns.add('costo_unitario', sql.Decimal(10, 2)); // Tu TIPO_CarritoVenta sí lo incluye
    tablaDetalle.columns.add('subtotal', sql.Decimal(10, 2));

    // Llenamos la tabla con los productos del carrito
    for (const item of detalle) {
      tablaDetalle.rows.add(
        item.id_producto,
        item.cantidad,
        item.precio_unitario,
        item.costo_unitario, // Asumimos que Flutter enviará el costo (o 0)
        item.subtotal
      );
    }

    // 3. Preparamos la llamada al SP
    const request = pool.request();
    request.input('id_cliente', sql.Int, id_cliente);
    request.input('id_usuario_app', sql.Int, id_usuario_app); // ¡El ID del usuario logueado!
    request.input('total', sql.Decimal(10, 2), total);
    request.input('metodo_pago', sql.VarChar, metodo_pago);
    request.input('detalle', tablaDetalle); // Pasamos la tabla completa

    // 4. Ejecutamos el SP
    const result = await request.execute('sp_CrearVenta');

    res.status(201).json({
      mensaje: 'Venta creada con éxito',
      id_venta: result.recordset[0].id_venta_creada
    });

  } catch (error) {
    console.error('Error en /api/ventas:', error.message);
    res.status(500).json({ error: 'Error al crear la venta', detalle: error.message });
  }
});

// iniciar servidor
app.listen(port, () => {
    console.log(`🚀 Servidor corriendo en http://localhost:${port}`);
});

// ENDPOINT: obtener inventario (productos + existencia)
// Query params: page (1-based), limit, search (opcional: nombre o codigo)
app.get('/api/inventario', authMiddleware, async (req, res) => {
  const page = Math.max(parseInt(req.query.page || '1'), 1);
  const limit = Math.max(parseInt(req.query.limit || '50'), 1);
  const offset = (page - 1) * limit;
  const search = req.query.search ? req.query.search.trim() : null;

  try {
    const request = pool.request();

    let whereClause = '';
    if (search) {
      whereClause = "WHERE p.nombre_producto LIKE @s OR p.codigo_producto LIKE @s";
      request.input('s', sql.VarChar, `%${search}%`);
    }

    // Total count
    const countQuery = `SELECT COUNT(1) as total FROM productos p ${whereClause}`;
    const countResult = await request.query(countQuery);
    const total = countResult.recordset[0].total || 0;

        // Query paginada que une inventario y producto
        const dataQuery = `
          SELECT p.id_producto, p.codigo_producto, p.nombre_producto, p.precio_venta, p.precio_compra, p.stock,
            p.url_imagen, p.stock_minimo, p.activo,
            inv.existencia_actual, inv.ultima_actualizacion, c.nombre_categoria, m.nombre_marca
          FROM productos p
          LEFT JOIN inventario inv ON inv.id_producto = p.id_producto
          LEFT JOIN categorias c ON p.id_categoria = c.id_categoria
          LEFT JOIN marcas m ON p.id_marca = m.id_marca
          ${whereClause}
          ORDER BY p.nombre_producto
          OFFSET ${offset} ROWS FETCH NEXT ${limit} ROWS ONLY`;

    const dataResult = await request.query(dataQuery);

    res.status(200).json({ page, limit, total, items: dataResult.recordset });
  } catch (error) {
    console.error('Error en /api/inventario:', error.message);
    res.status(500).json({ error: 'Error al obtener inventario', detalle: error.message });
  }
});

// ENDPOINT: actualizar inventario (ajuste manual de existencia) - Admin only
app.patch('/api/inventario/:id', authMiddleware, requireRole('Administrador'), async (req, res) => {
  const idProducto = parseInt(req.params.id);
  const { existencia_actual, observaciones } = req.body;

  if (typeof existencia_actual !== 'number') return res.status(400).json({ error: 'Campo existencia_actual es requerido y debe ser numérico' });

  const transaction = new sql.Transaction(pool);
  try {
    await transaction.begin();
    const tReq = transaction.request();
    tReq.input('id_producto', sql.Int, idProducto);

    // obtener existencia anterior
    const prevRes = await tReq.query('SELECT existencia_actual FROM inventario WHERE id_producto = @id_producto');
    let prev = 0;
    if (prevRes.recordset.length > 0) prev = prevRes.recordset[0].existencia_actual || 0;

    // actualizar o insertar inventario
    if (prevRes.recordset.length > 0) {
      tReq.input('nueva', sql.Int, existencia_actual);
      await tReq.query('UPDATE inventario SET existencia_actual = @nueva, ultima_actualizacion = GETDATE() WHERE id_producto = @id_producto');
    } else {
      tReq.input('nueva', sql.Int, existencia_actual);
      await tReq.query('INSERT INTO inventario (id_producto, existencia_actual, ultima_actualizacion) VALUES (@id_producto, @nueva, GETDATE())');
    }

    // registrar movimiento de tipo 'ajuste'
    const diff = existencia_actual - prev;
    tReq.input('cantidad', sql.Int, diff);
    tReq.input('observaciones', sql.VarChar, observaciones || `Ajuste manual por ${req.usuario.nombre || req.usuario.nombre_usuario || 'usuario'}`);
    await tReq.query(`INSERT INTO inventario_movimientos (id_producto, id_usuario, tipo, cantidad, observaciones, fecha)
                      VALUES (@id_producto, @id_usuario_app, 'ajuste', @cantidad, @observaciones, GETDATE())`);

    await transaction.commit();
    res.status(200).json({ mensaje: 'Inventario actualizado', anterior: prev, actual: existencia_actual, diferencia: diff });
  } catch (err) {
    await transaction.rollback();
    console.error('Error en PATCH /api/inventario/:id', err.message);
    res.status(500).json({ error: 'Error al actualizar inventario', detalle: err.message });
  }
});

// ENDPOINT: movimientos de inventario (Admin only)
// Query params: id_producto, tipo, fecha_from (ISO), fecha_to (ISO), page, limit
app.get('/api/inventario/movimientos', authMiddleware, requireRole('Administrador'), async (req, res) => {
  const page = Math.max(parseInt(req.query.page || '1'), 1);
  const limit = Math.max(parseInt(req.query.limit || '50'), 1);
  const offset = (page - 1) * limit;
  const { id_producto, tipo, fecha_from, fecha_to } = req.query;

  try {
    const request = pool.request();
    let filters = [];

    if (id_producto) { request.input('id_producto', sql.Int, parseInt(id_producto)); filters.push('im.id_producto = @id_producto'); }
    if (tipo) { request.input('tipo', sql.VarChar, tipo); filters.push('im.tipo = @tipo'); }
    if (fecha_from) { request.input('fecha_from', sql.DateTime, new Date(fecha_from)); filters.push('im.fecha >= @fecha_from'); }
    if (fecha_to) { request.input('fecha_to', sql.DateTime, new Date(fecha_to)); filters.push('im.fecha <= @fecha_to'); }

    const whereClause = filters.length ? 'WHERE ' + filters.join(' AND ') : '';

    const countQ = `SELECT COUNT(1) as total FROM inventario_movimientos im ${whereClause}`;
    const countRes = await request.query(countQ);
    const total = countRes.recordset[0].total || 0;

    const dataQ = `
      SELECT im.*, p.nombre_producto, u.nombre_usuario
      FROM inventario_movimientos im
      LEFT JOIN productos p ON p.id_producto = im.id_producto
      LEFT JOIN usuarios u ON u.id_usuario = im.id_usuario
      ${whereClause}
      ORDER BY im.fecha DESC
      OFFSET ${offset} ROWS FETCH NEXT ${limit} ROWS ONLY`;

    const dataRes = await request.query(dataQ);
    res.status(200).json({ page, limit, total, items: dataRes.recordset });
  } catch (error) {
    console.error('Error en /api/inventario/movimientos:', error.message);
    res.status(500).json({ error: 'Error al obtener movimientos', detalle: error.message });
  }
});

// ENDPOINT: bitacora (Admin only)
// Query params: nombre_tabla, tipo_operacion, fecha_from, fecha_to, page, limit
app.get('/api/bitacora', authMiddleware, requireRole('Administrador'), async (req, res) => {
  const page = Math.max(parseInt(req.query.page || '1'), 1);
  const limit = Math.max(parseInt(req.query.limit || '50'), 1);
  const offset = (page - 1) * limit;
  const { nombre_tabla, tipo_operacion, fecha_from, fecha_to } = req.query;

  try {
    const request = pool.request();
    let filters = [];
    if (nombre_tabla) { request.input('nombre_tabla', sql.VarChar, nombre_tabla); filters.push('b.nombre_tabla = @nombre_tabla'); }
    if (tipo_operacion) { request.input('tipo_operacion', sql.VarChar, tipo_operacion); filters.push('b.tipo_operacion = @tipo_operacion'); }
    if (fecha_from) { request.input('fecha_from', sql.DateTime, new Date(fecha_from)); filters.push('b.fecha_modificacion >= @fecha_from'); }
    if (fecha_to) { request.input('fecha_to', sql.DateTime, new Date(fecha_to)); filters.push('b.fecha_modificacion <= @fecha_to'); }

    const whereClause = filters.length ? 'WHERE ' + filters.join(' AND ') : '';

    const countQ = `SELECT COUNT(1) as total FROM bitacora_cliente b ${whereClause}`;
    const countRes = await request.query(countQ);
    const total = countRes.recordset[0].total || 0;

    const dataQ = `
      SELECT b.*, u.nombre_usuario as usuario_app_nombre
      FROM bitacora_cliente b
      LEFT JOIN usuarios u ON u.id_usuario = b.usuario_app
      ${whereClause}
      ORDER BY b.fecha_modificacion DESC
      OFFSET ${offset} ROWS FETCH NEXT ${limit} ROWS ONLY`;

    const dataRes = await request.query(dataQ);
    res.status(200).json({ page, limit, total, items: dataRes.recordset });

  } catch (error) {
    console.error('Error en /api/bitacora:', error.message);
    res.status(500).json({ error: 'Error al obtener bitacora', detalle: error.message });
  }
});

// ENDPOINT: Crear entrada (compra) - Admin o Vendedor (permitir ambos)
app.post('/api/entradas', authMiddleware, async (req, res) => {
  const { id_proveedor, total_entrada, detalle } = req.body;
  const id_usuario_app = req.usuario.id_usuario;

  if (!total_entrada || !detalle || detalle.length === 0) {
    return res.status(400).json({ error: 'Faltan datos en la entrada (total_entrada, detalle)' });
  }

  try {
    // Crear TVP con el mismo esquema que TIPO_CarritoEntrada
    const tablaDetalle = new sql.Table('TIPO_CarritoEntrada');
    tablaDetalle.columns.add('id_producto', sql.Int);
    tablaDetalle.columns.add('cantidad', sql.Int);
    tablaDetalle.columns.add('costo_unitario', sql.Decimal(10, 2));
    tablaDetalle.columns.add('precio_unitario', sql.Decimal(10, 2));

    for (const item of detalle) {
      tablaDetalle.rows.add(
        item.id_producto,
        item.cantidad,
        item.costo_unitario ?? 0,
        item.precio_unitario ?? null
      );
    }

    const request = pool.request();
    request.input('id_proveedor', sql.Int, id_proveedor);
    request.input('id_usuario_app', sql.Int, id_usuario_app);
    request.input('total_entrada', sql.Decimal(10, 2), total_entrada);
    request.input('detalle', tablaDetalle);

    const result = await request.execute('sp_CrearEntrada');

    res.status(201).json({ mensaje: 'Entrada creada con éxito', id_entrada: result.recordset[0].id_entrada_creada });

  } catch (error) {
    console.error('Error en /api/entradas:', error.message);
    res.status(500).json({ error: 'Error al crear la entrada', detalle: error.message });
  }
});

// ENDPOINT: Clientes (GET paginado + POST crear)
app.get('/api/clientes', authMiddleware, async (req, res) => {
  const page = Math.max(parseInt(req.query.page || '1'), 1);
  const limit = Math.max(parseInt(req.query.limit || '50'), 1);
  const offset = (page - 1) * limit;
  const search = req.query.search ? req.query.search.trim() : null;

  try {
    const request = pool.request();
    let whereClause = '';
    if (search) {
      whereClause = "WHERE nombre_cliente LIKE @s OR rfc LIKE @s";
      request.input('s', sql.VarChar, `%${search}%`);
    }

    const countQ = `SELECT COUNT(1) as total FROM clientes ${whereClause}`;
    const countRes = await request.query(countQ);
    const total = countRes.recordset[0].total || 0;

    const dataQ = `
      SELECT id_cliente, nombre_cliente, rfc, email AS correo, telefono, direccion
      FROM clientes
      ${whereClause}
      ORDER BY nombre_cliente
      OFFSET ${offset} ROWS FETCH NEXT ${limit} ROWS ONLY`;

    const dataRes = await request.query(dataQ);
    res.status(200).json({ page, limit, total, items: dataRes.recordset });
  } catch (error) {
    console.error('Error en /api/clientes:', error.message);
    res.status(500).json({ error: 'Error al obtener clientes', detalle: error.message });
  }
});

app.post('/api/clientes', authMiddleware, requireRole('Administrador'), async (req, res) => {
  const { nombre_cliente, rfc, correo, telefono, direccion } = req.body;
  if (!nombre_cliente) return res.status(400).json({ error: 'Falta nombre_cliente' });

  try {
    const request = pool.request();
    request.input('nombre_cliente', sql.VarChar, nombre_cliente);
    request.input('rfc', sql.VarChar, rfc);
    request.input('correo', sql.VarChar, correo);
    request.input('telefono', sql.VarChar, telefono);
    request.input('direccion', sql.VarChar, direccion);
    // pasar id del usuario de la sesión para auditoria si existe el SP
    const idUsuarioApp = req.usuario && req.usuario.id_usuario ? req.usuario.id_usuario : null;
    request.input('id_usuario_app', sql.Int, idUsuarioApp);

    // Intentar ejecutar el stored procedure sp_CrearCliente si existe
    try {
      const spRes = await request.execute('sp_CrearCliente');
      // si el SP devuelve un id en recordset, usarlo
      if (spRes && spRes.recordset && spRes.recordset[0]) {
        const id_created = spRes.recordset[0].id_cliente_creado || spRes.recordset[0].id_cliente || null;
        return res.status(201).json({ mensaje: 'Cliente creado (SP)', id_cliente: id_created });
      }
      // si no hay recordset, devolver éxito genérico
      return res.status(201).json({ mensaje: 'Cliente creado (SP)' });
    } catch (spError) {
      // Si el SP no existe, caer al INSERT directo. Si es otro error, loguearlo pero intentar fallback.
      if (!spError.message || spError.message.toLowerCase().includes('could not find stored procedure')) {
        // continuar a fallback
      } else {
        console.warn('sp_CrearCliente falló, intentando fallback INSERT:', spError.message);
      }
    }

    // Fallback: INSERT directo si el SP no está disponible
    const insertQ = `INSERT INTO clientes (nombre_cliente, rfc, email, telefono, direccion)
             OUTPUT INSERTED.id_cliente
             VALUES (@nombre_cliente, @rfc, @correo, @telefono, @direccion)`;

    const result = await request.query(insertQ);
    res.status(201).json({ mensaje: 'Cliente creado', id_cliente: result.recordset[0].id_cliente });
  } catch (error) {
    console.error('Error en POST /api/clientes:', error.message);
    res.status(500).json({ error: 'Error al crear cliente', detalle: error.message });
  }
});

// ENDPOINT: Actualizar cliente (intenta SP sp_ActualizarCliente con id_usuario_app, fallback a UPDATE)
app.put('/api/clientes/:id', authMiddleware, requireRole('Administrador'), async (req, res) => {
  const id = parseInt(req.params.id);
  const { nombre_cliente, rfc, correo, telefono, direccion } = req.body;
  if (!nombre_cliente) return res.status(400).json({ error: 'Falta nombre_cliente' });

  try {
    const request = pool.request();
    request.input('id_cliente', sql.Int, id);
    request.input('nombre_cliente', sql.VarChar, nombre_cliente);
    request.input('rfc', sql.VarChar, rfc);
    request.input('correo', sql.VarChar, correo);
    request.input('telefono', sql.VarChar, telefono);
    request.input('direccion', sql.VarChar, direccion);
    const idUsuarioApp = req.usuario && req.usuario.id_usuario ? req.usuario.id_usuario : null;
    request.input('id_usuario_app', sql.Int, idUsuarioApp);

    try {
      const spRes = await request.execute('sp_ActualizarCliente');
      return res.status(200).json({ mensaje: 'Cliente actualizado (SP)' });
    } catch (spErr) {
      if (!spErr.message || spErr.message.toLowerCase().includes('could not find stored procedure')) {
        // fallback a UPDATE
      } else {
        console.warn('sp_ActualizarCliente falló, intentando fallback UPDATE:', spErr.message);
      }
    }

    const updateQ = `UPDATE clientes SET nombre_cliente = @nombre_cliente, rfc = @rfc, email = @correo, telefono = @telefono, direccion = @direccion WHERE id_cliente = @id_cliente`;
    await request.query(updateQ);
    res.status(200).json({ mensaje: 'Cliente actualizado', id_cliente: id });
  } catch (error) {
    console.error('Error en PUT /api/clientes/:id', error.message);
    res.status(500).json({ error: 'Error al actualizar cliente', detalle: error.message });
  }
});

// ENDPOINT: Eliminar cliente (intenta SP sp_EliminarCliente con id_usuario_app, fallback a DELETE)
app.delete('/api/clientes/:id', authMiddleware, requireRole('Administrador'), async (req, res) => {
  const id = parseInt(req.params.id);
  try {
    const request = pool.request();
    request.input('id_cliente', sql.Int, id);
    const idUsuarioApp = req.usuario && req.usuario.id_usuario ? req.usuario.id_usuario : null;
    request.input('id_usuario_app', sql.Int, idUsuarioApp);

    try {
      const spRes = await request.execute('sp_EliminarCliente');
      return res.status(200).json({ mensaje: 'Cliente eliminado (SP)', id_cliente: id });
    } catch (spErr) {
      if (!spErr.message || spErr.message.toLowerCase().includes('could not find stored procedure')) {
        // fallback a DELETE
      } else {
        console.warn('sp_EliminarCliente falló, intentando fallback DELETE:', spErr.message);
      }
    }

    const delQ = `DELETE FROM clientes WHERE id_cliente = @id_cliente`;
    await request.query(delQ);
    res.status(200).json({ mensaje: 'Cliente eliminado', id_cliente: id });
  } catch (error) {
    console.error('Error en DELETE /api/clientes/:id', error.message);
    res.status(500).json({ error: 'Error al eliminar cliente', detalle: error.message });
  }
});

// ENDPOINT: Proveedores (GET paginado + POST crear)
app.get('/api/proveedores', authMiddleware, async (req, res) => {
  const page = Math.max(parseInt(req.query.page || '1'), 1);
  const limit = Math.max(parseInt(req.query.limit || '50'), 1);
  const offset = (page - 1) * limit;
  const search = req.query.search ? req.query.search.trim() : null;

  try {
    const request = pool.request();
    let whereClause = '';
    if (search) {
      whereClause = "WHERE nombre_proveedor LIKE @s OR rfc LIKE @s";
      request.input('s', sql.VarChar, `%${search}%`);
    }

    const countQ = `SELECT COUNT(1) as total FROM proveedores ${whereClause}`;
    const countRes = await request.query(countQ);
    const total = countRes.recordset[0].total || 0;

    const dataQ = `
      SELECT id_proveedor, nombre_proveedor, rfc, correo, telefono, direccion
      FROM proveedores
      ${whereClause}
      ORDER BY nombre_proveedor
      OFFSET ${offset} ROWS FETCH NEXT ${limit} ROWS ONLY`;

    const dataRes = await request.query(dataQ);
    res.status(200).json({ page, limit, total, items: dataRes.recordset });
  } catch (error) {
    console.error('Error en /api/proveedores:', error.message);
    res.status(500).json({ error: 'Error al obtener proveedores', detalle: error.message });
  }
});

app.post('/api/proveedores', authMiddleware, requireRole('Administrador'), async (req, res) => {
  const { nombre_proveedor, rfc, correo, telefono, direccion } = req.body;
  if (!nombre_proveedor) return res.status(400).json({ error: 'Falta nombre_proveedor' });

  try {
    const request = pool.request();
    request.input('nombre_proveedor', sql.VarChar, nombre_proveedor);
    request.input('rfc', sql.VarChar, rfc);
    request.input('correo', sql.VarChar, correo);
    request.input('telefono', sql.VarChar, telefono);
    request.input('direccion', sql.VarChar, direccion);

    const insertQ = `INSERT INTO proveedores (nombre_proveedor, rfc, correo, telefono, direccion)
                     OUTPUT INSERTED.id_proveedor
                     VALUES (@nombre_proveedor, @rfc, @correo, @telefono, @direccion)`;

    const result = await request.query(insertQ);
    res.status(201).json({ mensaje: 'Proveedor creado', id_proveedor: result.recordset[0].id_proveedor });
  } catch (error) {
    console.error('Error en POST /api/proveedores:', error.message);
    res.status(500).json({ error: 'Error al crear proveedor', detalle: error.message });
  }
});

// ENDPOINT: Historial de ventas (filtros y paginacion)
app.get('/api/ventas/history', authMiddleware, async (req, res) => {
  const page = Math.max(parseInt(req.query.page || '1'), 1);
  const limit = Math.max(parseInt(req.query.limit || '50'), 1);
  const offset = (page - 1) * limit;
  const { id_cliente, fecha_from, fecha_to } = req.query;

  try {
    const request = pool.request();
    let filters = [];

    if (id_cliente) { request.input('id_cliente', sql.Int, parseInt(id_cliente)); filters.push('v.id_cliente = @id_cliente'); }
    if (fecha_from) { request.input('fecha_from', sql.DateTime, new Date(fecha_from)); filters.push('v.fecha >= @fecha_from'); }
    if (fecha_to) { request.input('fecha_to', sql.DateTime, new Date(fecha_to)); filters.push('v.fecha <= @fecha_to'); }

    // Si el usuario es Vendedor, limitar solo a sus ventas (columna real: id_usuario)
    if (req.usuario && req.usuario.rol && req.usuario.rol === 'Vendedor') {
      request.input('id_usuario', sql.Int, req.usuario.id_usuario);
      filters.push('v.id_usuario = @id_usuario');
    }

    const whereClause = filters.length ? 'WHERE ' + filters.join(' AND ') : '';

    const countQ = `SELECT COUNT(1) as total FROM ventas v ${whereClause}`;
    const countRes = await request.query(countQ);
    const total = countRes.recordset[0].total || 0;

    const dataQ = `
      SELECT v.*, u.nombre_usuario as usuario_app_nombre, c.nombre_cliente as cliente_nombre
      FROM ventas v
      LEFT JOIN usuarios u ON u.id_usuario = v.id_usuario
      LEFT JOIN clientes c ON c.id_cliente = v.id_cliente
      ${whereClause}
      ORDER BY v.fecha DESC
      OFFSET ${offset} ROWS FETCH NEXT ${limit} ROWS ONLY`;

    const dataRes = await request.query(dataQ);
    res.status(200).json({ page, limit, total, items: dataRes.recordset });

  } catch (error) {
    console.error('Error en /api/ventas/history:', error.message);
    res.status(500).json({ error: 'Error al obtener historial de ventas', detalle: error.message });
  }
});

// ENDPOINT: Categorias y Marcas (GET simples)
app.get('/api/categorias', authMiddleware, async (req, res) => {
  try {
    const request = pool.request();
    const result = await request.query('SELECT id_categoria, nombre_categoria FROM categorias ORDER BY nombre_categoria');
    res.status(200).json(result.recordset);
  } catch (error) {
    console.error('Error en /api/categorias:', error.message);
    res.status(500).json({ error: 'Error al obtener categorias', detalle: error.message });
  }
});

// CRUD Categorias (Admin)
app.post('/api/categorias', authMiddleware, requireRole('Administrador'), async (req, res) => {
  const { nombre_categoria } = req.body;
  if (!nombre_categoria) return res.status(400).json({ error: 'Falta nombre_categoria' });

  try {
    const request = pool.request();
    request.input('nombre_categoria', sql.VarChar, nombre_categoria);
    const insertQ = `INSERT INTO categorias (nombre_categoria) OUTPUT INSERTED.id_categoria VALUES (@nombre_categoria)`;
    const result = await request.query(insertQ);
    res.status(201).json({ mensaje: 'Categoría creada', id_categoria: result.recordset[0].id_categoria });
  } catch (error) {
    console.error('Error en POST /api/categorias:', error.message);
    res.status(500).json({ error: 'Error al crear categoría', detalle: error.message });
  }
});

app.put('/api/categorias/:id', authMiddleware, requireRole('Administrador'), async (req, res) => {
  const id = parseInt(req.params.id);
  const { nombre_categoria } = req.body;
  if (!nombre_categoria) return res.status(400).json({ error: 'Falta nombre_categoria' });

  try {
    const request = pool.request();
    request.input('id', sql.Int, id);
    request.input('nombre_categoria', sql.VarChar, nombre_categoria);
    const updateQ = `UPDATE categorias SET nombre_categoria = @nombre_categoria WHERE id_categoria = @id`;
    const result = await request.query(updateQ);
    res.status(200).json({ mensaje: 'Categoría actualizada', id_categoria: id });
  } catch (error) {
    console.error('Error en PUT /api/categorias/:id', error.message);
    res.status(500).json({ error: 'Error al actualizar categoría', detalle: error.message });
  }
});

app.delete('/api/categorias/:id', authMiddleware, requireRole('Administrador'), async (req, res) => {
  const id = parseInt(req.params.id);
  try {
    const request = pool.request();
    request.input('id', sql.Int, id);
    const delQ = `DELETE FROM categorias WHERE id_categoria = @id`;
    await request.query(delQ);
    res.status(200).json({ mensaje: 'Categoría eliminada', id_categoria: id });
  } catch (error) {
    console.error('Error en DELETE /api/categorias/:id', error.message);
    res.status(500).json({ error: 'Error al eliminar categoría', detalle: error.message });
  }
});

app.get('/api/marcas', authMiddleware, async (req, res) => {
  try {
    const request = pool.request();
    const result = await request.query('SELECT id_marca, nombre_marca FROM marcas ORDER BY nombre_marca');
    res.status(200).json(result.recordset);
  } catch (error) {
    console.error('Error en /api/marcas:', error.message);
    res.status(500).json({ error: 'Error al obtener marcas', detalle: error.message });
  }
});

// ENDPOINT: Obtener logs de Database Mail (Admin)
app.get('/api/mail/log', authMiddleware, requireRole('Administrador'), async (req, res) => {
  try {
    const request = pool.request();
    // Devolver los últimos 20 items de la cola/historial
    const q = `SELECT TOP 20 mailitem_id, subject, recipients, send_request_date, sent_status, last_mod_date, last_mod_user
               FROM msdb.dbo.sysmail_allitems
               ORDER BY send_request_date DESC`;
    const result = await request.query(q);
    res.status(200).json(result.recordset);
  } catch (error) {
    console.error('Error en /api/mail/log:', error.message);
    res.status(500).json({ error: 'Error al obtener logs de mail', detalle: error.message });
  }
});
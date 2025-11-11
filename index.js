const express = require('express');
const sql = require('mssql'); //conector de sql server
require('dotenv').config(); // cargar variables de .env
const bcrypt = require('bcryptjs'); // encriptar contraseñas
const jwt = require('jsonwebtoken'); //tokens de sesion

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
app.use(express.json());

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


// iniciar servidor
app.listen(port, () => {
    console.log(`🚀 Servidor corriendo en http://localhost:${port}`);
});
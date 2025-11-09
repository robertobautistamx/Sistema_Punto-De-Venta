const express=require('express');
const sql=require('mssql'); // Importar el conector de SQL Server
require('dotenv').config(); // Importar y cargar las variables de .env

const app = express();
const port = 3000;

// 1. Configuracion de la conexion a la BD
// Lee las variables del archivo .env
const dbConfig={
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  server: process.env.DB_SERVER,
  database: process.env.DB_DATABASE,
  port: parseInt(process.env.DB_PORT),
  options: {
    encrypt: false, // Usar false para desarrollo local
    trustServerCertificate: true // Necesario para conexiones locales
  }
};

// 2. Funcion para probar la conexion
async function probarConexion() {
  try {
    //intenta conectar a la base de datos
    await sql.connect(dbConfig);
    console.log("¡Conexión a SQL Server exitosa!");
  } catch (err) {
    console.error("Error al conectar a la base de datos:", err);
  }
}

// 3. Definir una ruta de prueba
app.get('/', (req, res) => {
  res.json({ mensaje: '¡Mi API de POS está en línea!' });
});

// 4. Poner el servidor a escuchar
app.listen(port, () => {
  console.log(`Servidor corriendo en http://localhost:${port}`);

  // 5. Llamar a la funcion de prueba de conexion
  probarConexion();
});
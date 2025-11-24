// middleware/authMiddleware.js
const jwt = require('jsonwebtoken');

const authMiddleware = (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Acceso denegado. No se proporcionó token.' });
  }

  const token = authHeader.split(' ')[1]; // Quita "Bearer "

  try {
    const payloadVerificado = jwt.verify(token, process.env.JWT_SECRET);
    // ¡IMPORTANTE! Adjuntamos el usuario a la petición
    req.usuario = payloadVerificado; 
    next(); // El token es válido, continuar
  } catch (error) {
    res.status(400).json({ error: 'Token inválido.' });
  }
};

module.exports = authMiddleware;
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
require('dotenv').config();
const axios = require('axios'); 

const app = express();
const PORT = process.env.PORT || 3000;

// --- Middlewares ---
app.use(cors());
app.use(express.json());

const mongoBD = process.env.MONGO;

mongoose.connect(mongoBD)
  .then(() => console.log('✅ Conexión a MongoDB exitosa'))
  .catch(err => console.error('Error al conectar a MongoDB:', err));


const scoreSchema = new mongoose.Schema({
  nombreJugador: { 
    type: String,
    required: true,
    trim: true
  },
  puntaje: {
    type: Number,
    required: true
  },
  fecha: {
    type: Date,
    default: Date.now
  }
});

const Score = mongoose.model('Puntajes', scoreSchema);


app.get('/', (req, res) => {
  res.send('¡El servidor de puntajes está funcionando!');
});

// Obtener puntajes
app.get('/api/scores', async (req, res) => {
  try {
    const scores = await Score.find().sort({ puntaje: -1 });
    res.status(200).json(scores);
  } catch (error) {
    res.status(500).json({ message: 'Error al obtener los puntajes', error: error.message });
  }
});

// Guardar puntaje
app.post('/api/puntajes', async (req, res) => {
  console.log('✅ ¡Datos recibidos desde Flutter!:', req.body);
  const { nombreJugador, puntaje } = req.body;

  if (!nombreJugador || puntaje === undefined) {
    return res.status(400).json({ message: 'Se requieren los campos "nombreJugador" y "puntaje".' });
  }

  const newScore = new Score({
    nombreJugador: nombreJugador,
    puntaje: puntaje
  });

  try {
    const savedScore = await newScore.save();
    res.status(201).json(savedScore);
  } catch (error) {
    res.status(500).json({ message: 'Error al guardar el puntaje', error: error.message });
  }
});


app.post('/api/generar-quiz', async (req, res) => {
  const { tema } = req.body;

  if (!tema) {
    return res.status(400).json({ message: 'El tema es requerido' });
  }

  const prompt = `
      Genera 5 preguntas de opción múltiple sobre el tema: "${tema}". 
      Cada pregunta debe ser corta y entendible.
      Cada pregunta debe tener un enunciado, cuatro opciones de respuesta (A, B, C, D) y la respuesta correcta.

      Sigue este FORMATO ESTRICTO y NO INCLUYAS NINGÚN TEXTO ADICIONAL, preámbulo o despedida:

      [Q1] PREGUNTA
      [A] OPCION_A
      [B] OPCION_B
      [C] OPCION_C
      [D] OPCION_D
      [ANSWER] RESPUESTA_CORRECTA (Solo la letra A, B, C o D)
      ---
      [Q2] PREGUNTA
      [A] OPCION_A
      [B] OPCION_B
      [C] OPCION_C
      [D] OPCION_D
      [ANSWER] RESPUESTA_CORRECTA (Solo la letra A, B, C o D)
      ---
      [Q3] PREGUNTA
      [A] OPCION_A
      [B] OPCION_B
      [C] OPCION_C
      [D] OPCION_D
      [ANSWER] RESPUESTA_CORRECTA (Solo la letra A, B, C o D)
      ---
      [Q4] PREGUNTA
      [A] OPCION_A
      [B] OPCION_B
      [C] OPCION_C
      [D] OPCION_D
      [ANSWER] RESPUESTA_CORRECTA (Solo la letra A, B, C o D)
      ---
      [Q5] PREGUNTA
      [A] OPCION_A
      [B] OPCION_B
      [C] OPCION_C
      [D] OPCION_D
      [ANSWER] RESPUESTA_CORRECTA (Solo la letra A, B, C o D)
  `;

  try {
  
    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${process.env.API_G}`;
    
    const response = await axios.post(url, {
      contents: [{ parts: [{ text: prompt }] }]
    });

    // Validar que la respuesta sea correcta
    if (response.data && response.data.candidates && response.data.candidates.length > 0) {
        const text = response.data.candidates[0].content.parts[0].text;
        res.json({ generatedText: text });
    } else {
        throw new Error("Estructura de respuesta incorrectas");
    }

  } catch (error) {
    console.error('Error llamando a Gemini:', error.response?.data || error.message);
    res.status(500).json({ message: 'Error generando el quiz', error: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`🚀 Servidor corriendo en http://localhost:${PORT}`);
});

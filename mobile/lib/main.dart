import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

// 1. MODELO DE DATOS: Estructura para almacenar la pregunta

class Question {
  final String enunciado;
  final Map<String, String> opciones;
  final String respuestaCorrecta;

  String? respuestaSeleccionada;
  bool evaluada;

  Question({
    required this.enunciado,
    required this.opciones,
    required this.respuestaCorrecta,
    this.respuestaSeleccionada,
    this.evaluada = false,
  });

  void resetState() {
    respuestaSeleccionada = null;
    evaluada = false;
  }
}

// 2. WIDGET DE INICIO (App Base)

void main() {
  runApp(const Quiziz());
}

class Quiziz extends StatelessWidget {
  const Quiziz({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Generador Ético de Quizzes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        useMaterial3: true,
      ),
      home: const GeneradorPreguntas(),
    );
  }
}

// 3. WIDGET DE PANTALLA PRINCIPAL (Estado y Lógica)

class GeneradorPreguntas extends StatefulWidget {
  const GeneradorPreguntas({super.key});

  @override
  State<GeneradorPreguntas> createState() => _GeneradorPreguntasState();
}

class _GeneradorPreguntasState extends State<GeneradorPreguntas> {
  final TextEditingController _temaBus = TextEditingController();
  final TextEditingController _nombreU =
      TextEditingController(); // Controlador para el nombre
  String _nomJugador = "";
  List<Question> _preguntas = [];
  bool _isLoading = false;
  int _score = 0;
/*
@override
Widget build(BuildContext context) {
  // Aquí va el cuerpo visual de tu pantalla
  return Scaffold(
    appBar: AppBar(title: const Text('Generador de Preguntas')),
    body: const Center(child: Text('Contenido del quiz')),
  );
}*/
  void _LimpiarCampos() {
    setState(() {
      _preguntas = [];
      _temaBus.clear();
      _score = 0;
      _isLoading = false;
      _nombreU.clear();
    });
  }

  // URL de Servidor
  final String apiUrl = "http://10.0.2.2:3000/api";

  @override
  void dispose() {
    _temaBus.dispose();
    _nombreU.dispose();
    super.dispose();
  }

  // Guardar respuesta selección, no evalúa.
  void _seleccionarRespuesta(int index, String selectedKey) {
    // Solo se permite seleccionar si la pregunta aún no ha sido evaluada
    if (_preguntas[index].evaluada) return;

    setState(() {
      // Solo actualiza la selección del usuario
      _preguntas[index].respuestaSeleccionada = selectedKey;
    });
  }

  // Evalúar las preguntas
  void _evaluarQuiz() {
    bool allSelected = _preguntas.every((q) => q.respuestaSeleccionada != null);
    if (!allSelected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Responde todas las preguntas antes de enviar.')));
      return;
    }

    setState(() {
      _score = 0;
      for (var question in _preguntas) {
        question.evaluada = true;
        if (question.respuestaSeleccionada == question.respuestaCorrecta) {
          _score++;
        }
      }
    });

    if (_nomJugador.isNotEmpty) {
      _guardarPuntajeEnServidor(_nomJugador, _score);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Error: No se encontró el nombre del jugador para guardar.')),
      );
    }
  }

  // Función que llamada a la API y Parsing (Sin Cambios Esenciales)
  Future<void> _guardarPuntajeEnServidor(
      String nombreJugador, int puntaje) async {
    try {
      final respuesta = await http.post(
        Uri.parse("$apiUrl/puntajes"),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          'nombreJugador': nombreJugador,
          'puntaje': puntaje,
        }),
      );

      if (!mounted) return;

      if (respuesta.statusCode == 201) {
        // 201 = Creado exitosamente
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Puntaje guardado con éxito! 🏆'),
              backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error del servidor: ${respuesta.body}'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error de conexión con el servidor: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _generarPreguntas() async {
    final String tema = _temaBus.text.trim();
    final String nombre = _nombreU.text.trim();

    if (tema.isEmpty || nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Por favor, ingresa tu nombre y un tema para el quiz.'),
      ));
      return;
    }

    setState(() {
      _nomJugador = nombre;
      _isLoading = true;
      _preguntas = [];
      _score = 0;
    });


    try {
      final respuestas = await http.post(
        Uri.parse("$apiUrl/generar-quiz"), 
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "tema": tema 
        }),
      );

      if (respuestas.statusCode == 200) {
        final data = json.decode(respuestas.body);
        final String generatedText = data['generatedText'];

        // Lógica de Parsing (sin cambios)
        List<Question> parsedQuestions = [];
        final List<String> questionBlocks = generatedText.split('---');

        for (String block in questionBlocks) {
          if (block.trim().isEmpty) continue;
          final Map<String, String> components = {};
          final List<String> lines = block.split('\n');

          for (String line in lines) {
            line = line.trim();
            if (line.startsWith(RegExp(r'\[Q\d+\]'))) {
              components['enunciado'] =
                  line.substring(line.indexOf(']') + 1).trim();
            } else if (line.startsWith('[A]')) {
              components['A'] = line.substring(3).trim();
            } else if (line.startsWith('[B]')) {
              components['B'] = line.substring(3).trim();
            } else if (line.startsWith('[C]')) {
              components['C'] = line.substring(3).trim();
            } else if (line.startsWith('[D]')) {
              components['D'] = line.substring(3).trim();
            } else if (line.startsWith('[ANSWER]')) {
              components['respuesta'] =
                  line.substring(line.indexOf(']') + 1).trim();
            }
          }

          if (components.containsKey('enunciado') &&
              components.containsKey('respuesta') &&
              components.containsKey('A') &&
              components.containsKey('B') &&
              components.containsKey('C') &&
              components.containsKey('D')) {
            parsedQuestions.add(Question(
                enunciado: components['enunciado']!,
                respuestaCorrecta: components['respuesta']!,
                opciones: {
                  'A': components['A']!,
                  'B': components['B']!,
                  'C': components['C']!,
                  'D': components['D']!,
                }));
          }
        }

        setState(() {
          _preguntas = parsedQuestions;
        });
      } else {
        setState(() {
          _preguntas = [];
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Error API (${respuestas.statusCode}): ${respuestas.body}')));
        });
      }
    } catch (e) {
      setState(() {
        _preguntas = [];
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error de red o parsing: $e')));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 4. CONSTRUCCIÓN DE LA INTERFAZ

  @override
  Widget build(BuildContext context) {
    int evaluatedCount = _preguntas.where((q) => q.evaluada).length;
    int contestadas = _preguntas.where((q) => q.respuestaSeleccionada != null).length;
    bool preguntasDisponibles = _preguntas.isNotEmpty;
    bool respuestasCompletas = evaluatedCount == _preguntas.length && preguntasDisponibles;
    bool entradasHabilitas = _preguntas.isEmpty && !_isLoading;
    bool hayPreguntas = _preguntas.isNotEmpty;
    bool activarBtnGenerar = !hayPreguntas && !_isLoading;
    bool activarBtnLimpiar = respuestasCompletas;
    bool activarBtnEnviar = _preguntas.any((q) => q.respuestaSeleccionada != null);
    

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 141, 165, 239),
        elevation: 0, // Quita la sombra para que se vea plano y limpio
        centerTitle: true,
        title: const Text(
          'GENERADOR DE QUIZZES',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18, // Un poco más pequeño
            fontWeight: FontWeight.w600,
            letterSpacing: 2.5, // El secreto: espaciado entre letras
            fontFamily: 'MyFont', // O la fuente que prefieras
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: _nombreU,
              enabled: entradasHabilitas,
              decoration: const InputDecoration(
                labelText: 'Tu Nombre',
                hintText: 'Escribe tu nombre aquí',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: _temaBus,
              enabled: entradasHabilitas,
              decoration: const InputDecoration(
                labelText: 'Tema',
                hintText:  'Tema (Ej: "Metematicas")',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            // Btn de Generación
            ElevatedButton.icon(
              onPressed: activarBtnGenerar ? _generarPreguntas : null,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.quiz),
              label: Text(
                  _isLoading ? 'Generando 5 Preguntas...' : 'Generar Quiz'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 20),
              ),
            ),

            const SizedBox(height: 5),

            // Btn de limpiar
            ElevatedButton.icon(
              onPressed: activarBtnLimpiar ? _LimpiarCampos : null,
              icon: const Icon(Icons.cleaning_services),
              label: const Text("Limpiar"),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 20),
                  backgroundColor: const Color.fromARGB(255, 105, 154, 238)),
            ),

            const SizedBox(height: 30),

            // Marcador de Puntuación
            if (preguntasDisponibles)
              Container(
                padding: const EdgeInsets.only(bottom: 15),
                alignment: Alignment.centerLeft,
                child: Text(
                  respuestasCompletas
                      ? 'Quiz Terminado: ¡Obtuviste $_score de ${_preguntas.length} aciertos! 🏆'
                      : 'Preguntas respondidas: $contestadas de ${_preguntas.length}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: respuestasCompletas ? Colors.deepPurple : Colors.black87,
                  ),
                ),
              ),

            const Divider(),

            // Resultados
            Expanded(
              child: _preguntas.isEmpty && !_isLoading
                  ? const Center(
                      child:
                          Text('Ingresa un tema y haz clic en "Generar Quiz".'))
                  : ListView.builder(
                      itemCount: _preguntas.length + (respuestasCompletas ? 0 : 1),
                      itemBuilder: (context, index) {
                        if (index == _preguntas.length && !respuestasCompletas) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20.0),
                            child: ElevatedButton.icon(
                              onPressed: activarBtnEnviar
                                  ? _evaluarQuiz
                                  : null, // Habilitar solo si hay selecciones
                              icon: const Icon(Icons.send),
                              label: const Text('Enviar Respuestas y Evaluar'),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                textStyle: const TextStyle(fontSize: 18),
                              ),
                            ),
                          );
                        }

                        // Mostrar la Pregunta
                        final question = _preguntas[index];
                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.only(bottom: 20),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Enunciado de la Pregunta
                                Text(
                                  '${index + 1}. ${question.enunciado}',
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 12),

                                // Mostrar Opciones INTERACTIVAS
                                ...question.opciones.entries.map((entry) {
                                  final key = entry.key;
                                  final value = entry.value;

                                  Color? tileColor;
                                  Color textColor = Colors.black87;
                                  bool isCorrect =
                                      key == question.respuestaCorrecta;
                                  bool isUserSelection =
                                      key == question.respuestaSeleccionada;

                                  if (question.evaluada) {
                                    // Marcar la respuesta CORRECTA en verde
                                    if (isCorrect) {
                                      tileColor =
                                          Colors.green.withOpacity(0.15);
                                      textColor = Colors.green.shade800;
                                    }
                                    // Marcar la selección INCORRECTA en rojo
                                    else if (isUserSelection) {
                                      tileColor = Colors.red.withOpacity(0.15);
                                      textColor = Colors.red.shade800;
                                    }
                                  } else if (isUserSelection) {
                                    // Marcar la selección actual del usuario antes de la evaluación
                                    tileColor =
                                        Colors.blueGrey.withOpacity(0.1);
                                    textColor = Colors.blueGrey;
                                  }

                                  return GestureDetector(
                                    onTap: question.evaluada
                                        ? null // Deshabilitar si ya se evaluó
                                        : () =>
                                            _seleccionarRespuesta(index, key),
                                    child: Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 4.0),
                                      padding: const EdgeInsets.all(12.0),
                                      decoration: BoxDecoration(
                                        color: tileColor ?? Colors.grey.shade50,
                                        border: Border.all(
                                            color: tileColor != null
                                                ? tileColor!
                                                : Colors.grey.shade300),
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                      child: Text(
                                        '($key) $value',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight:
                                                isCorrect && question.evaluada
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                            color: textColor),
                                      ),
                                    ),
                                  );
                                }).toList(),

                                // Mostrar retroalimentación general
                                if (question.evaluada)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10.0),
                                    child: Text(
                                      question.respuestaSeleccionada ==
                                              question.respuestaCorrecta
                                          ? '¡Respuesta Correcta! 🎉'
                                          : 'Incorrecto. La respuesta correcta es (${question.respuestaCorrecta}).',
                                      style: TextStyle(
                                        color: question.respuestaSeleccionada ==
                                                question.respuestaCorrecta
                                            ? Colors.green.shade700
                                            : Colors.red.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

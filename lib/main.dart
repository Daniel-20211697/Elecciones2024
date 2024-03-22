//Daniel Baez 2021-1697
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(MiApp());
}

class MiApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App de Elecciones',
      theme: ThemeData(
        visualDensity: VisualDensity.adaptivePlatformDensity,
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.lightBlue).copyWith(secondary: Colors.amber), // Color de acento
        fontFamily: 'Roboto', // Fuente predeterminada
      ),
      home: PaginaInicio(),
      //icon: AssetImage('assets/icon.png'),
    );
  }
}

class PaginaInicio extends StatefulWidget {
  @override
  _PaginaInicioState createState() => _PaginaInicioState();
}

class _PaginaInicioState extends State<PaginaInicio> {
  late Database _baseDatos;
  List<Map<String, dynamic>>? _eventos;

  @override
  void initState() {
    super.initState();
    _inicializarBaseDatos();
  }

  Future<void> _inicializarBaseDatos() async {
    Directory directorioDocumentos = await getApplicationDocumentsDirectory();
    String ruta = join(directorioDocumentos.path, 'elecciones.db');
    _baseDatos = await openDatabase(ruta, version: 1,
        onCreate: (Database db, int version) async {
      await db.execute('''
          CREATE TABLE Eventos(
            id INTEGER PRIMARY KEY,
            titulo TEXT,
            descripcion TEXT,
            fecha TEXT,
            foto TEXT,
            audio TEXT
          )
        ''');
    });
    _refrescarEventos();
  }

  Future<void> _refrescarEventos() async {
    final List<Map<String, dynamic>> eventos = await _baseDatos.query('Eventos');
    setState(() {
      _eventos = eventos;
    });
  }

  Future<void> _agregarEvento(String titulo, String descripcion, String fecha, String fotoRuta, String audioRuta) async {
    await _baseDatos.insert('Eventos', {
      'titulo': titulo,
      'descripcion': descripcion,
      'fecha': fecha,
      'foto': fotoRuta,
      'audio': audioRuta
    });
    _refrescarEventos();
  }

  Future<void> _borrarEventos() async {
    await _baseDatos.delete('Eventos');
    _refrescarEventos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('App de Elecciones'),
      ),
      body: _eventos == null ? _indicadorCarga() : _listaEventos(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaginaAgregarEvento(onEventoAgregado: _agregarEvento),
            ),
          );
        },
        child: Icon(Icons.add),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.indigo, // Color azul de la Liga Pokémon
              ),
              child: Text(
                'Acerca de mi',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              title: Text('Borrar todos los eventos'),
              onTap: () {
                _borrarEventos();
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('Acerca de'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PaginaAcercaDe()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _indicadorCarga() {
    return Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _listaEventos() {
    return ListView.builder(
      itemCount: _eventos!.length,
      itemBuilder: (BuildContext context, int index) {
        return ListTile(
          title: Text(_eventos![index]['titulo'] ?? ''),
          subtitle: Text(_eventos![index]['fecha'] ?? ''),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PaginaDetallesEvento(evento: _eventos![index]),
              ),
            );
          },
        );
      },
    );
  }
}

class PaginaAgregarEvento extends StatefulWidget {
  final Function(String, String, String, String, String) onEventoAgregado;

  const PaginaAgregarEvento({Key? key, required this.onEventoAgregado}) : super(key: key);

  @override
  _PaginaAgregarEventoState createState() => _PaginaAgregarEventoState();
}

class _PaginaAgregarEventoState extends State<PaginaAgregarEvento> {
  late TextEditingController _controladorTitulo;
  late TextEditingController _controladorDescripcion;
  late TextEditingController _controladorFecha;
  String _rutaFoto = '';
  String _rutaAudio = '';

  late bool _grabandoAudio;
  late IconData _iconoBotonGrabacion;

  @override
  void initState() {
    super.initState();
    _controladorTitulo = TextEditingController();
    _controladorDescripcion = TextEditingController();
    _controladorFecha = TextEditingController(text: DateTime.now().toString());
    _grabandoAudio = false;
    _iconoBotonGrabacion = Icons.mic;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Agregar Evento'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controladorTitulo,
                decoration: InputDecoration(labelText: 'Título'),
              ),
              TextField(
                controller: _controladorDescripcion,
                decoration: InputDecoration(labelText: 'Descripción'),
              ),
              TextField(
                controller: _controladorFecha,
                decoration: InputDecoration(labelText: 'Fecha'),
                readOnly: true,
                onTap: () async {
                  DateTime? fechaSeleccionada = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (fechaSeleccionada != null) {
                    TimeOfDay? horaSeleccionada = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (horaSeleccionada != null) {
                      setState(() {
                        _controladorFecha.text = DateTime(
                          fechaSeleccionada.year,
                          fechaSeleccionada.month,
                          fechaSeleccionada.day,
                          horaSeleccionada.hour,
                          horaSeleccionada.minute,
                        ).toString();
                      });
                    }
                  }
                },
              ),
              ElevatedButton(
                onPressed: _tomarFoto,
                child: Text('Tomar Foto'),
              ),
              ElevatedButton(
                onPressed: _seleccionarFoto,
                child: Text('Seleccionar desde Galería'),
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _grabarAudio,
                icon: Icon(_iconoBotonGrabacion),
                label: Text(_grabandoAudio ? 'Detener Grabación' : 'Iniciar Grabación'),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  widget.onEventoAgregado(
                    _controladorTitulo.text,
                    _controladorDescripcion.text,
                    _controladorFecha.text,
                    _rutaFoto,
                    _rutaAudio,
                  );
                  Navigator.pop(context);
                },
                child: Text('Guardar Evento'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _tomarFoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _rutaFoto = pickedFile.path!;
      });
    }
  }

  Future<void> _seleccionarFoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _rutaFoto = pickedFile.path!;
      });
    }
  }

  Future<void> _grabarAudio() async {
    if (!_grabandoAudio) {
      _iconoBotonGrabacion = Icons.stop;
      _grabandoAudio = true;
      setState(() {});
      final recorder = AudioRecorder();
      await recorder.startRecording();
      final path = await recorder.stopRecording();
      setState(() {
        _rutaAudio = path;
      });
    } else {
      _iconoBotonGrabacion = Icons.mic;
      _grabandoAudio = false;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controladorTitulo.dispose();
    _controladorDescripcion.dispose();
    _controladorFecha.dispose();
    super.dispose();
  }
}

class AudioRecorder {
  late String _tempPath;
  late String _finalPath;

  Future<void> startRecording() async {
    final Directory tempDir = await getTemporaryDirectory();
    _tempPath = '${tempDir.path}/temp.aac';
    _finalPath = '';
    await Process.run('rm', ['-f', _tempPath]);
    await Process.run('arecord', ['-f', 'cd', '-t', 'raw', '-D', 'hw:0,0', '-d', '180', _tempPath]);
  }

  Future<String> stopRecording() async {
    await Future.delayed(Duration(seconds: 3));
    final Directory documentsDir = await getApplicationDocumentsDirectory();
    _finalPath = '${documentsDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
    await Process.run('mv', [_tempPath, _finalPath]);
    return _finalPath;
  }
}

class PaginaAcercaDe extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Acerca de mi'),
      ),
      body: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: DecorationImage(
                  image: AssetImage('assets/daniel.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Daniel Baez',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text('Matrícula: 2021-1697'),
            SizedBox(height: 20),
            Text(
              '“Si no puedo ver por mí mismo la liberación de este pueblo, la veré a través de mis ideas”.',
              textAlign: TextAlign.center,
            ),
            Text(
              '-Juan Bosch-',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class PaginaDetallesEvento extends StatelessWidget {
  final Map<String, dynamic> evento;

  const PaginaDetallesEvento({Key? key, required this.evento}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalles del Evento'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              evento['titulo'] ?? '',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Fecha: ${evento['fecha'] ?? ''}',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 10),
            Text(
              'Descripción: ${evento['descripcion'] ?? ''}',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 10),
            if (evento['foto'] != null)
              Image.file(
                File(evento['foto']),
                height: 200,
              ),
            if (evento['audio'] != null)
              ElevatedButton(
                onPressed: () {
                  AudioPlayer().play(evento['audio']);
                },
                child: Text('Reproducir Audio'),
              ),
          ],
        ),
      ),
    );
  }
}

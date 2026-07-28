import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'audio_processor.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio + Fundo',
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription? _intentSub;
  String? _voicePath;
  String? _outputPath;
  bool _processing = false;

  final Map<String, String> _backgrounds = const {
    'Lo-fi calmo': 'assets/backgrounds/fundo_lofi.mp3',
    'Trilha emocionante': 'assets/backgrounds/fundo_emocionante.mp3',
    'Ambiente suave': 'assets/backgrounds/fundo_suave.mp3',
  };
  String? _selectedBgLabel;

  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _selectedBgLabel = _backgrounds.keys.first;
    _requestPermissions();

    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isNotEmpty) {
        setState(() => _voicePath = files.first.path);
      }
    });

    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((files) {
      if (files.isNotEmpty) {
        setState(() => _voicePath = files.first.path);
      }
    });
  }

  Future<void> _requestPermissions() async {
    await Permission.audio.request();
    await Permission.storage.request();
  }

  Future<void> _pickFileManually() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _voicePath = result.files.single.path;
        _outputPath = null;
      });
    }
  }

  Future<void> _process() async {
    if (_voicePath == null || _selectedBgLabel == null) return;
    setState(() {
      _processing = true;
      _outputPath = null;
    });

    final bgAsset = _backgrounds[_selectedBgLabel]!;
    final result = await AudioProcessor.mixAudio(
      voicePath: _voicePath!,
      backgroundAssetPath: bgAsset,
    );

    if (!mounted) return;
    setState(() {
      _processing = false;
      _outputPath = result;
    });

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deu erro ao processar o audio. Confere os logs no console.'),
        ),
      );
    }
  }

  Future<void> _playResult() async {
    if (_outputPath != null) {
      await _player.play(DeviceFileSource(_outputPath!));
    }
  }

  Future<void> _shareResult() async {
    if (_outputPath != null) {
      await Share.shareXFiles([XFile(_outputPath!)]);
    }
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio + Fundo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _voicePath == null
                      ? 'Nenhum audio recebido ainda.\n\nCompartilhe um audio do WhatsApp com este app (segure o audio > Encaminhar > escolha "Audio Fundo"), ou escolha manualmente abaixo.'
                      : 'Audio recebido:\n${_voicePath!.split('/').last}',
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickFileManually,
              icon: const Icon(Icons.folder_open),
              label: const Text('Escolher audio manualmente'),
            ),
            const SizedBox(height: 24),
            const Text('Musica de fundo:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _selectedBgLabel,
              isExpanded: true,
              items: _backgrounds.keys
                  .map((label) => DropdownMenuItem(value: label, child: Text(label)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedBgLabel = value),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: (_voicePath == null || _processing) ? null : _process,
              icon: _processing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_fix_high),
              label: Text(_processing ? 'Processando...' : 'Gerar audio com fundo'),
            ),
            if (_outputPath != null) ...[
              const SizedBox(height: 24),
              const Divider(),
              const Text('Pronto!', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _playResult,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Ouvir'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _shareResult,
                      icon: const Icon(Icons.share),
                      label: const Text('Enviar'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

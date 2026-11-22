
import 'package:audio2text_mobile/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import '../../theme/app_theme.dart';

class ProcessingScreens {
  static const upload = '/upload-audio';
  static const processing = '/processing';
  static const result = '/transcription-result';
}

class ProcessingBackground extends StatelessWidget {
  final Widget child;

  const ProcessingBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.background,
            Color(0xFF11152B),
            AppTheme.background,
          ],
        ),
      ),
      child: child,
    );
  }
}

// UPLOAD SCREEN

class UploadAudioScreen extends StatefulWidget {
  const UploadAudioScreen({super.key});

  @override
  State<UploadAudioScreen> createState() => _UploadAudioScreenState();
}

class _UploadAudioScreenState extends State<UploadAudioScreen> {
  PlatformFile? selectedFile;
  bool picking = false;

  Future<void> _pickAudio() async {
    setState(() => picking = true);

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'ogg', 'aac', 'flac'],
        withData: true,
      );

      if (!mounted) return;

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        if (file.bytes == null || file.bytes!.isEmpty) {
          throw Exception('Could not read the selected audio file.');
        }

        if (file.size > 50 * 1024 * 1024) {
          throw Exception('Maximum file size is 50 MB.');
        }

        setState(() => selectedFile = file);
      }
    } catch (e) {
      if (!mounted) return;
      _showError(e);
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  void _startProcessing() {
    final file = selectedFile;

    if (file == null || file.bytes == null) {
      _showError('Choose an audio file first.');
      return;
    }

    Navigator.pushNamed(
      context,
      ProcessingScreens.processing,
      arguments: {
        'fileName': file.name,
        'bytes': file.bytes!,
      },
    );
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Audio')),
      body: ProcessingBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.graphic_eq_rounded,
                    color: AppTheme.primary,
                    size: 65,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Turn audio into text',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Upload your recording and get your transcription.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: picking ? null : _pickAudio,
                    child: Container(
                      padding: const EdgeInsets.all(35),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.65),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            selectedFile == null
                                ? Icons.cloud_upload_rounded
                                : Icons.audio_file_rounded,
                            size: 54,
                            color: AppTheme.secondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            selectedFile?.name ?? 'Choose an audio file',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            selectedFile == null
                                ? 'MP3, WAV, M4A, OGG, AAC, FLAC'
                                : '${(selectedFile!.size / (1024 * 1024)).toStringAsFixed(2)} MB',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (picking)
                            const CircularProgressIndicator()
                          else
                            const Text(
                              'Tap to browse files',
                              style: TextStyle(color: AppTheme.secondary),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _InfoCard(
                    icon: Icons.lock_outline,
                    title: 'Private workspace',
                    subtitle: 'Your recordings are linked to your account.',
                  ),
                  const SizedBox(height: 12),
                  const _InfoCard(
                    icon: Icons.payments_outlined,
                    title: 'Service price',
                    subtitle: '10 MAD per service.',
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: selectedFile == null || picking
                        ? null
                        : _startProcessing,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Start Transcription'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// PROCESSING SCREEN

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  bool started = false;
  String status = 'Preparing your audio...';
  String? error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!started) {
      started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processAudio();
      });
    }
  }

  Future<void> _processAudio() async {
    try {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (args == null || args['fileName'] == null || args['bytes'] == null) {
        throw Exception('Audio file information is missing.');
      }

      final fileName = args['fileName'] as String;
      final bytes = args['bytes'] as List<int>;

      if (!mounted) return;
      setState(() => status = 'Uploading audio...');

      final upload = await ApiService.uploadAudio(
        fileName: fileName,
        bytes: bytes,
      );

      final fileId = upload['file_id']?.toString();

      if (fileId == null || fileId.isEmpty) {
        throw Exception('The server did not return a file ID.');
      }

      if (!mounted) return;
      setState(() => status = 'AI is transcribing your audio...');

      final result = await ApiService.transcribeAudio(fileId);

      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        ProcessingScreens.result,
        arguments: {
          'fileName': fileName,
          'fileId': fileId,
          'result': result,
        },
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Processing')),
      body: ProcessingBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (error == null) ...[
                  const SizedBox(
                    width: 110,
                    height: 110,
                    child: CircularProgressIndicator(strokeWidth: 5),
                  ),
                  const SizedBox(height: 35),
                  const Text(
                    'AI is working on your audio',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 25),
                  const LinearProgressIndicator(
                    minHeight: 6,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Large recordings may take several minutes.',
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.redAccent,
                    size: 65,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Processing failed',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(error!, textAlign: TextAlign.center),
                  const SizedBox(height: 25),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to Upload'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// RESULT SCREEN

class TranscriptionResultScreen extends StatelessWidget {
  const TranscriptionResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final result = args?['result'] is Map
        ? Map<String, dynamic>.from(args!['result'] as Map)
        : <String, dynamic>{};

    final fileName = args?['fileName']?.toString() ?? 'Audio recording';
    final transcription =
        result['transcription']?.toString() ??
        result['text']?.toString() ??
        '';

    final language = result['language']?.toString() ?? 'Unknown';
    final completed = result['status']?.toString() == 'completed';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transcription Result'),
        actions: [
          IconButton(
            tooltip: 'Copy transcription',
            onPressed: transcription.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(
                      ClipboardData(text: transcription),
                    );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Transcription copied.'),
                        ),
                      );
                    }
                  },
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
      body: ProcessingBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5744B8), Color(0xFF252B55)],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    completed
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    color: AppTheme.secondary,
                    size: 35,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    completed ? 'Transcription ready' : 'Processing finished',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fileName,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _ResultStat(
                    title: 'Language',
                    value: language,
                    icon: Icons.language_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ResultStat(
                    title: 'Status',
                    value: result['status']?.toString() ?? 'Unknown',
                    icon: Icons.check_circle_outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            const Text(
              'Transcribed Text',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF272D48)),
              ),
              child: SelectableText(
                transcription.isEmpty
                    ? 'No transcription text was returned by the server.'
                    : transcription,
                textDirection: _textDirection(transcription),
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.9,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (transcription.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: transcription),
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Text copied successfully.'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy Text'),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  ProcessingScreens.upload,
                  (route) => route.settings.name == '/app',
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Transcribe Another Audio'),
            ),
          ],
        ),
      ),
    );
  }

  static TextDirection _textDirection(String value) {
    final arabic = RegExp(r'[\u0600-\u06FF]');
    return arabic.hasMatch(value)
        ? TextDirection.rtl
        : TextDirection.ltr;
  }
}

// REUSABLE WIDGETS

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFF272D48)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.secondary, size: 25),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(subtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _ResultStat({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.secondary),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(title),
        ],
      ),
    );
  }
}

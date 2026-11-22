import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import 'api_service.dart';

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
          colors: [AppTheme.background, Color(0xFF11152B), AppTheme.background],
        ),
      ),
      child: child,
    );
  }
}

// ------------------------------------------------------------
// Upload audio
// ------------------------------------------------------------

class UploadAudioScreen extends StatefulWidget {
  const UploadAudioScreen({super.key});

  @override
  State<UploadAudioScreen> createState() => _UploadAudioScreenState();
}

class _UploadAudioScreenState extends State<UploadAudioScreen> {
  PlatformFile? selectedFile;
  bool isPicking = false;

  static const allowedExtensions = [
    'mp3',
    'wav',
    'm4a',
    'aac',
    'ogg',
    'opus',
    'flac',
    'mp4',
  ];

  Future<void> _pickFile() async {
    setState(() => isPicking = true);

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
        withData: true,
      );

      if (!mounted) return;

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;

      if (file.size == 0) {
        _showMessage('The selected file is empty.');
        return;
      }

      if (file.size > 50 * 1024 * 1024) {
        _showMessage('Maximum file size is 50 MB.');
        return;
      }

      if (file.bytes == null || file.bytes!.isEmpty) {
        _showMessage('Could not read the selected file.');
        return;
      }

      setState(() => selectedFile = file);
    } catch (error) {
      _showMessage('File selection failed: $error');
    } finally {
      if (mounted) {
        setState(() => isPicking = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _startProcessing() {
    final file = selectedFile;

    if (file == null || file.bytes == null) {
      _showMessage('Please choose an audio file first.');
      return;
    }

    Navigator.pushNamed(
      context,
      ProcessingScreens.processing,
      arguments: {'fileName': file.name, 'bytes': file.bytes!},
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
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
                    size: 64,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Turn audio into text',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Upload your audio and let our AI transcribe it.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 32),

                  InkWell(
                    onTap: isPicking ? null : _pickFile,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.7),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            isPicking
                                ? Icons.hourglass_top_rounded
                                : Icons.cloud_upload_rounded,
                            size: 54,
                            color: AppTheme.secondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isPicking
                                ? 'Opening files...'
                                : 'Choose an audio file',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'MP3, WAV, M4A, OGG, AAC, FLAC',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                          if (selectedFile != null) ...[
                            const SizedBox(height: 18),
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppTheme.secondary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              selectedFile!.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppTheme.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _formatSize(selectedFile!.size),
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

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

                  const SizedBox(height: 25),

                  ElevatedButton.icon(
                    onPressed: selectedFile == null || isPicking
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

// ------------------------------------------------------------
// Real backend processing
// ------------------------------------------------------------

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  bool _started = false;
  bool _isLoading = true;
  String? _error;
  String _status = 'Uploading your audio...';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_started) return;
    _started = true;

    final arguments = ModalRoute.of(context)?.settings.arguments;

    if (arguments is! Map ||
        arguments['fileName'] is! String ||
        arguments['bytes'] is! List<int>) {
      setState(() {
        _isLoading = false;
        _error = 'Missing audio file information. Please try again.';
      });
      return;
    }

    _processAudio(
      fileName: arguments['fileName'] as String,
      bytes: arguments['bytes'] as List<int>,
    );
  }

  Future<void> _processAudio({
    required String fileName,
    required List<int> bytes,
  }) async {
    try {
      if (mounted) {
        setState(() => _status = 'Uploading your audio...');
      }

      final upload = await ApiService.uploadAudio(
        fileName: fileName,
        bytes: bytes,
      );

      final fileId = upload['file_id']?.toString();

      if (fileId == null || fileId.isEmpty) {
        throw Exception('The server did not return a file ID.');
      }

      if (!mounted) return;

      setState(() => _status = 'AI is transcribing your audio...');

      final result = await ApiService.transcribeAudio(fileId);

      if (!mounted) return;

      if (result['status'] != 'completed') {
        throw Exception('Transcription was not completed.');
      }

      Navigator.pushReplacementNamed(
        context,
        ProcessingScreens.result,
        arguments: {'fileName': fileName, 'fileId': fileId, 'result': result},
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
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
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _error == null
                        ? Icons.graphic_eq_rounded
                        : Icons.error_outline_rounded,
                    color: _error == null
                        ? AppTheme.secondary
                        : Colors.redAccent,
                    size: 90,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    _error == null
                        ? 'AI is working on your audio'
                        : 'Processing failed',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _error ?? _status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 30),
                  if (_isLoading)
                    const CircularProgressIndicator(color: AppTheme.secondary),
                  if (_error != null) ...[
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back to upload'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Actual transcription result
// ------------------------------------------------------------

class TranscriptionResultScreen extends StatelessWidget {
  const TranscriptionResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;

    final data = arguments is Map ? arguments : <String, dynamic>{};
    final result = data['result'] is Map
        ? Map<String, dynamic>.from(data['result'] as Map)
        : <String, dynamic>{};

    final fileName = data['fileName']?.toString() ?? 'Audio recording';
    final transcription = result['transcription']?.toString() ?? '';
    final language = result['language']?.toString() ?? 'Unknown';
    final segments = result['segments_count']?.toString() ?? '—';

    final isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(transcription);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transcription Result'),
        actions: [
          IconButton(
            tooltip: 'Copy transcription',
            onPressed: transcription.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: transcription));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transcription copied.')),
                    );
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
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.secondary,
                    size: 35,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Transcription ready',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(fileName, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: _ResultStat(
                    title: 'Language',
                    value: language.toUpperCase(),
                    icon: Icons.language_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ResultStat(
                    title: 'Segments',
                    value: segments,
                    icon: Icons.graphic_eq_rounded,
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF272D48)),
              ),
              child: transcription.isEmpty
                  ? const Text(
                      'No transcription text was returned.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    )
                  : SelectableText(
                      transcription,
                      textDirection: isArabic
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.9,
                        color: AppTheme.textPrimary,
                      ),
                    ),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: transcription.isEmpty
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(text: transcription));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Transcription copied.')),
                      );
                    },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy transcription'),
            ),

            const SizedBox(height: 10),

            OutlinedButton.icon(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  ProcessingScreens.upload,
                  (route) => route.settings.name == '/app',
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Transcribe another audio'),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Reusable widgets
// ------------------------------------------------------------

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
                Text(
                  subtitle,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(title, style: const TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

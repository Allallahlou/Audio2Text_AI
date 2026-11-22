import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/stat_card.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  PlatformFile? selectedAudio;

  bool isPicking = false;
  bool isUploading = false;
  bool isLoadingHistory = false;

  final Set<String> transcribingIds = {};

  List<Map<String, dynamic>> recordings = [];

  String? expandedFileId;

  int get totalRecordings => recordings.length;

  int get transcribedCount {
    return recordings.where((item) {
      return item['status'] == 'completed';
    }).length;
  }

  double get totalCost {
    return recordings.fold<double>(0, (total, item) {
      final value = item['estimated_cost_mad'];
      return total + (value is num ? value.toDouble() : 0);
    });
  }

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> pickAudio() async {
    setState(() => isPicking = true);

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'mp3',
          'wav',
          'm4a',
          'aac',
          'ogg',
          'opus',
          'flac',
          'mp4',
        ],
        withData: true,
      );

      if (!mounted) return;

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          selectedAudio = result.files.first;
        });

        showMessage('Audio file selected successfully!');
      }
    } catch (e) {
      showMessage('File selection failed: $e');
    } finally {
      if (mounted) {
        setState(() => isPicking = false);
      }
    }
  }

  void removeAudio() {
    setState(() => selectedAudio = null);
  }

  Future<void> uploadAudio() async {
    if (selectedAudio == null) {
      showMessage('Please select an audio file first.');
      return;
    }

    setState(() => isUploading = true);

    try {
      final audio = selectedAudio!;

      if (audio.bytes == null) {
        throw Exception('Could not read the selected audio file.');
      }

      final data = await ApiService.uploadAudio(
        fileName: audio.name,
        bytes: audio.bytes!,
      );

      final fileId = data['file_id'] as String?;

      if (fileId == null || fileId.isEmpty) {
        throw Exception('The server did not return a file ID.');
      }

      if (!mounted) return;

      setState(() => selectedAudio = null);

      showMessage('Audio uploaded! Starting transcription...');

      await loadHistory();
      await transcribeAudio(fileId);
    } catch (e) {
      showMessage('Processing error: $e');
    } finally {
      if (mounted) {
        setState(() => isUploading = false);
      }
    }
  }

  Future<void> transcribeAudio(String fileId) async {
    if (transcribingIds.contains(fileId)) return;

    setState(() {
      transcribingIds.add(fileId);
      expandedFileId = fileId;
    });

    try {
      await ApiService.transcribeAudio(fileId);

      if (!mounted) return;

      await loadHistory();

      if (!mounted) return;
      showMessage('Transcription completed successfully!');
    } catch (e) {
      if (mounted) {
        showMessage('Transcription error: $e');
        await loadHistory();
      }
    } finally {
      if (mounted) {
        setState(() {
          transcribingIds.remove(fileId);
        });
      }
    }
  }

  Future<void> loadHistory() async {
    if (mounted) {
      setState(() => isLoadingHistory = true);
    }

    try {
      final items = await ApiService.loadHistory();

      if (mounted) {
        setState(() {
          recordings = items;
        });
      }
    } catch (e) {
      debugPrint('History error: $e');
    } finally {
      if (mounted) {
        setState(() => isLoadingHistory = false);
      }
    }
  }

  void toggleTranscription(String fileId) {
    setState(() {
      expandedFileId = expandedFileId == fileId ? null : fileId;
    });
  }

  Future<void> copyTranscription(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    showMessage('Transcription copied to clipboard!');
  }

  String formatSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }

    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  Color statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'processing':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.graphic_eq, color: Color(0xFF635BFF)),
            SizedBox(width: 10),
            Text(
              'Audio2Text AI',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: isLoadingHistory ? null : loadHistory,
            tooltip: 'Refresh history',
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome back!',
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Turn your voice messages into useful information.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 25),

              // Upload section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF635BFF), Color(0xFF837BFF)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.cloud_upload_outlined,
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Convert audio to text',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select a WhatsApp voice message or an audio file.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: isPicking || isUploading ? null : pickAudio,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF635BFF),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      icon: isPicking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      label: Text(isPicking ? 'Selecting...' : 'Import Audio'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Selected audio
              if (selectedAudio != null) ...[
                const Text(
                  'Selected Audio',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE7E7F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.audio_file,
                        color: Color(0xFF635BFF),
                        size: 35,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedAudio!.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              formatSize(selectedAudio!.size),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: isUploading ? null : removeAudio,
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isUploading ? null : uploadAudio,
                    icon: isUploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(
                      isUploading ? 'Processing...' : 'Convert Audio to Text',
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // Overview
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Overview',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  if (isLoadingHistory)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Audio Files',
                      value: '$totalRecordings',
                      icon: Icons.audiotrack,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'Transcribed',
                      value: '$transcribedCount',
                      icon: Icons.description_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  const Expanded(
                    child: StatCard(
                      title: 'Minutes',
                      value: '0',
                      icon: Icons.timer_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'Cost (MAD)',
                      value: totalCost.toStringAsFixed(2),
                      icon: Icons.payments_outlined,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Recent recordings
              const Text(
                'Recent Recordings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              if (recordings.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.library_music_outlined,
                        size: 35,
                        color: Color(0xFF635BFF),
                      ),
                      SizedBox(height: 10),
                      Text('No recordings yet'),
                      SizedBox(height: 5),
                      Text(
                        'Upload your first audio file.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                ...recordings.take(10).map((recording) {
                  final fileId = recording['file_id']?.toString() ?? '';
                  final filename = recording['filename']?.toString() ?? 'Audio';
                  final format = recording['format']?.toString() ?? '';
                  final status = recording['status']?.toString() ?? 'pending';
                  final transcription =
                      recording['transcription']?.toString() ?? '';

                  final isTranscribing = transcribingIds.contains(fileId);
                  final isExpanded = expandedFileId == fileId;
                  final isCompleted = status == 'completed';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEEEEF4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.audio_file,
                              color: Color(0xFF635BFF),
                              size: 30,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    filename,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$format â€¢ ${formatSize((recording['size_bytes'] as num?)?.toInt() ?? 0)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              status,
                              style: TextStyle(
                                color: statusColor(status),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Transcribe / view button
                        SizedBox(
                          width: double.infinity,
                          child: isCompleted
                              ? OutlinedButton.icon(
                                  onPressed: () => toggleTranscription(fileId),
                                  icon: Icon(
                                    isExpanded
                                        ? Icons.visibility_off
                                        : Icons.description_outlined,
                                  ),
                                  label: Text(
                                    isExpanded ? 'Hide Text' : 'View Text',
                                  ),
                                )
                              : FilledButton.icon(
                                  onPressed: isTranscribing || fileId.isEmpty
                                      ? null
                                      : () => transcribeAudio(fileId),
                                  icon: isTranscribing
                                      ? const SizedBox(
                                          width: 17,
                                          height: 17,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.auto_awesome),
                                  label: Text(
                                    isTranscribing
                                        ? 'Transcribing... Please wait'
                                        : 'Transcribe Audio',
                                  ),
                                ),
                        ),

                        if (isExpanded && isCompleted) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F8FC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Transcription',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Copy text',
                                      onPressed: transcription.isEmpty
                                          ? null
                                          : () => copyTranscription(
                                              transcription,
                                            ),
                                      icon: const Icon(Icons.copy),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                SelectableText(
                                  transcription.isEmpty
                                      ? 'No transcription text available.'
                                      : transcription,
                                  textDirection: TextDirection.rtl,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.7,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 25),

              const Center(
                child: Text(
                  'Audio2Text AI â€¢ Version 1.2',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

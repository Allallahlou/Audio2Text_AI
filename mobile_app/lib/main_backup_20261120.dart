import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const Audio2TextApp());
}

class Audio2TextApp extends StatelessWidget {
  const Audio2TextApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Audio2Text AI',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF635BFF)),
        scaffoldBackgroundColor: const Color(0xFFF7F8FC),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const String baseUrl = kIsWeb
      ? 'http://127.0.0.1:8000'
      : 'http://10.0.2.2:8000';

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
      final uri = Uri.parse('$baseUrl/upload');
      final request = http.MultipartRequest('POST', uri);

      final audio = selectedAudio!;

      if (audio.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            audio.bytes!,
            filename: audio.name,
          ),
        );
      } else if (audio.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            audio.path!,
            filename: audio.name,
          ),
        );
      } else {
        throw Exception('Could not read the selected audio file.');
      }

      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 3),
      );

      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        if (!mounted) return;

        setState(() {
          selectedAudio = null;
        });

        showMessage('Audio uploaded successfully!');

        await loadHistory();
      } else {
        throw Exception(
          data['detail'] ?? 'Upload failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      showMessage('Upload error: $e');
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
      final uri = Uri.parse('$baseUrl/transcribe/$fileId');

      final response = await http
          .post(uri)
          .timeout(const Duration(minutes: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        if (!mounted) return;

        await loadHistory();

        showMessage('Transcription completed successfully!');
      } else {
        throw Exception(
          data['detail'] ?? 'Transcription failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      showMessage('Transcription error: $e');
      await loadHistory();
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
      final response = await http
          .get(Uri.parse('$baseUrl/history'))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        final items = (data['recordings'] as List? ?? [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

        if (mounted) {
          setState(() {
            recordings = items;
          });
        }
      } else {
        throw Exception('History request failed: ${response.statusCode}');
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
                'Welcome back 👋',
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
                        : const Icon(Icons.cloud_upload),
                    label: Text(isUploading ? 'Uploading...' : 'Upload Audio'),
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
                                    '$format • ${formatSize((recording['size_bytes'] as num?)?.toInt() ?? 0)}',
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
                  'Audio2Text AI • Version 1.2',
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

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEEEF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF635BFF), size: 27),
          const SizedBox(height: 15),
          Text(
            value,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

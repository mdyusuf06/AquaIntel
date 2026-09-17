import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../../providers/upload_provider.dart';
import 'package:file_picker/file_picker.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});
  @override State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  String? _fileName;
  String? _filePath;
  int _step = -1; // -1 = idle, 0-5 = steps, 6 = done
  double _stepProgress = 0;
  bool _isUploading = false;

  static const _steps = ['Ingest', 'Denoise', 'Segment', 'Embed & Match', 'Risk Score', 'Done'];

  Future<void> _pickFile() async {
    if (_isUploading) return;
    final result = await FilePicker.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() {
        _filePath = result.files.single.path;
        _fileName = result.files.single.name;
      });
    }
  }

  void _simulateUpload(String? path) async {
    if (_isUploading || path == null) return;
    setState(() { _isUploading = true; });
    
    // Call the backend provider in the background
    context.read<UploadProvider>().startBackendUpload(path);

    for (int i = 0; i < _steps.length; i++) {
      setState(() { _step = i; _stepProgress = 0; });
      for (int p = 0; p <= 100; p += 10) {
        await Future.delayed(const Duration(milliseconds: 80));
        if (mounted) setState(() => _stepProgress = p / 100);
      }
    }
    setState(() { _step = 6; _isUploading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text('Upload Sonar Log'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Drop zone ──
            GestureDetector(
              onTap: _isUploading ? null : _pickFile,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 180,
                decoration: BoxDecoration(
                  color: _fileName != null ? AppColors.primaryBlue.withValues(alpha: 0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _fileName != null ? AppColors.primaryBlue : const Color(0xFFCFDFEF), width: 2, style: _fileName == null ? BorderStyle.solid : BorderStyle.solid),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_fileName != null ? Icons.insert_drive_file : Icons.cloud_upload_outlined,
                        color: _fileName != null ? AppColors.primaryBlue : const Color(0xFFB0BEC5), size: 52),
                    const SizedBox(height: 12),
                    Text(_fileName ?? 'Tap or drag to upload', style: _fileName != null ? tt.titleMedium?.copyWith(color: AppColors.primaryBlue) : tt.bodyMedium),
                    const SizedBox(height: 4),
                    Text('XTF · GeoTIFF · PNG+JSON', style: tt.labelSmall),
                    if (_fileName == null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _pickFile, child: const Text('Browse file')),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // ── Upload button ──
            if (_step < 0 || _step == 6)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _fileName == null ? null : (_step == 6 ? () => context.go('/map') : () => _simulateUpload(_filePath)),
                  icon: Icon(_step == 6 ? Icons.map : Icons.upload),
                  label: Text(_step == 6 ? 'View on Map' : 'Process File'),
                ),
              ),
            // ── Pipeline steps ──
            if (_step >= 0) ...[
              const SizedBox(height: 28),
              Text('Processing Pipeline', style: tt.titleMedium),
              const SizedBox(height: 16),
              ..._steps.asMap().entries.map((e) {
                final i = e.key; final label = e.value;
                final isDone   = _step > i || _step == 6;
                final isActive = _step == i && _step < 6;
                return _PipelineStep(label: label, isDone: isDone, isActive: isActive, progress: isActive ? _stepProgress : (isDone ? 1.0 : 0.0));
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _PipelineStep extends StatelessWidget {
  final String label;
  final bool isDone, isActive;
  final double progress;
  const _PipelineStep({required this.label, required this.isDone, required this.isActive, required this.progress});

  @override
  Widget build(BuildContext context) {
    final color = isDone ? AppColors.success : isActive ? AppColors.primaryBlue : const Color(0xFFCFD8DC);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(isDone ? Icons.check : isActive ? Icons.sync : Icons.circle_outlined, color: color, size: 16),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 14)),
                if (isActive) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: progress, minHeight: 4, backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.12), valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

